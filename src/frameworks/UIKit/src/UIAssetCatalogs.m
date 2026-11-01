/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* The images and colors of a bundle's compiled asset catalog (Assets.car),
   as UIImage and UIColor. */

#import <UIKit/UIImage.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIScreen.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSFileManager.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/CGImageSource.h>
#import "UIKitPrivate.h"
#import "UIAssetCatalog.h"

/* Bundle path to its catalog, or to NSNull when it has none. Catalogs stay
   mapped for the life of the process, as CoreUI's do. */
static NSMutableDictionary *sCatalogs;

static uiac_catalog *UIKitCatalogForBundle(NSBundle *bundle)
{
	if (bundle == nil)
		bundle = [NSBundle mainBundle];
	NSString *key = [bundle bundlePath];
	if (key == nil)
		return NULL;
	@synchronized ([UIImage class]) {
		if (sCatalogs == nil)
			sCatalogs = [[NSMutableDictionary alloc] init];
		id entry = [sCatalogs objectForKey:key];
		if (entry == nil) {
			NSString *path = [key stringByAppendingPathComponent:@"Assets.car"];
			uiac_catalog *catalog = [[NSFileManager defaultManager] fileExistsAtPath:path] ? uiac_open([path fileSystemRepresentation]) : NULL;
			entry = catalog != NULL ? [NSValue valueWithPointer:catalog] : (id) [NSNull null];
			[sCatalogs setObject:entry forKey:key];
		}
		return entry == [NSNull null] ? NULL : [entry pointerValue];
	}
}

static void UIKitFreePixels(void *info, const void *data, size_t size)
{
	free((void *) data);
}

/* Takes PIXELS: premultiplied 8-bit BGRA. */
static CGImageRef UIKitImageFromBGRA(uint8_t *pixels, uint32_t width, uint32_t height, size_t rowBytes)
{
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, rowBytes * height, UIKitFreePixels);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGImageRef image = CGImageCreate(width, height, 8, 32, rowBytes, space,
		kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, provider, NULL, true, kCGRenderingIntentDefault);
	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);
	return image;
}

/* A PDF's first page, rasterized at SCALE pixels a point. */
static CGImageRef UIKitRasterizePDF(NSData *data, CGFloat scale)
{
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef) data);
	CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
	CGDataProviderRelease(provider);
	CGPDFPageRef page = document != NULL && CGPDFDocumentGetNumberOfPages(document) > 0 ? CGPDFDocumentGetPage(document, 1) : NULL;
	CGImageRef image = NULL;
	if (page != NULL) {
		CGRect box = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
		if (CGRectIsEmpty(box))
			box = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
		size_t width = (size_t) ceil(box.size.width * scale), height = (size_t) ceil(box.size.height * scale);
		if (width > 0 && height > 0 && width <= 8192 && height <= 8192) {
			CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
			CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
				kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
			CGColorSpaceRelease(space);
			if (context != NULL) {
				CGContextScaleCTM(context, scale, scale);
				CGContextTranslateCTM(context, -box.origin.x, -box.origin.y);
				CGContextDrawPDFPage(context, page);
				image = CGBitmapContextCreateImage(context);
				CGContextRelease(context);
			}
		}
	}
	if (document != NULL)
		CGPDFDocumentRelease(document);
	return image;
}

static UIImage *UIKitDecodeAssetImage(uiac_catalog *catalog, NSString *name);

/* Decoded images, by bundle and name: rasterizing a PDF is not cheap. */
static NSCache *sAssetImages;

UIImage *UIKitAssetImage(NSString *name, NSBundle *bundle)
{
	uiac_catalog *catalog = UIKitCatalogForBundle(bundle);
	if (catalog == NULL || [name length] == 0)
		return nil;
	NSString *key = [[(bundle ?: [NSBundle mainBundle]) bundlePath] stringByAppendingFormat:@"\n%@", name];
	@synchronized ([UIImage class]) {
		if (sAssetImages == nil)
			sAssetImages = [[NSCache alloc] init];
	}
	UIImage *image = [sAssetImages objectForKey:key];
	if (image == nil && (image = UIKitDecodeAssetImage(catalog, name)) != nil)
		[sAssetImages setObject:image forKey:key];
	return image;
}

static UIImage *UIKitDecodeAssetImage(uiac_catalog *catalog, NSString *name)
{
	CGFloat screenScale = [[UIScreen mainScreen] scale];
	if (screenScale <= 0)
		screenScale = 2;
	uiac_image asset;
	if (!uiac_image_named(catalog, [name UTF8String], screenScale, 0, &asset))
		return nil;

	CGImageRef image = NULL;
	CGFloat scale = asset.scale;
	switch (asset.kind) {
	case UIAC_BITMAP_BGRA:
		image = UIKitImageFromBGRA(asset.bytes, asset.width, asset.height, asset.row_bytes);
		asset.bytes = NULL;
		break;
	case UIAC_BITMAP_GRAY: {
		size_t count = (size_t) asset.width * asset.height;
		uint8_t *bgra = malloc(count * 4);
		for (size_t i = 0; i < count; i++) {
			uint8_t gray = asset.bytes[2 * i], alpha = asset.bytes[2 * i + 1];
			bgra[4 * i] = bgra[4 * i + 1] = bgra[4 * i + 2] = gray;
			bgra[4 * i + 3] = alpha;
		}
		image = UIKitImageFromBGRA(bgra, asset.width, asset.height, (size_t) asset.width * 4);
		break;
	}
	case UIAC_ENCODED: {
		NSData *data = [NSData dataWithBytes:asset.bytes length:asset.length];
		if (asset.length >= 5 && memcmp(asset.bytes, "%PDF-", 5) == 0) {
			image = UIKitRasterizePDF(data, screenScale);
			scale = screenScale;
		} else {
			CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) data, NULL);
			if (source != NULL && CGImageSourceGetCount(source) > 0)
				image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
			if (source != NULL)
				CFRelease(source);
		}
		if (image == NULL)
			NSLog(@"UIKit: cannot decode the asset catalog image %@ (%zu bytes)", name, asset.length);
		break;
	}
	}
	uiac_image_free(&asset);
	if (image == NULL)
		return nil;
	UIImage *result = [UIImage imageWithCGImage:image scale:scale > 0 ? scale : 1 orientation:0];
	CGImageRelease(image);
	return result;
}

UIColor *UIKitAssetColor(NSString *name, NSBundle *bundle)
{
	uiac_catalog *catalog = UIKitCatalogForBundle(bundle);
	double rgba[4];
	/* The light appearance: there is no dark mode here (see UIColor.m). */
	if (catalog == NULL || [name length] == 0 || !uiac_color(catalog, [name UTF8String], 0, rgba))
		return nil;
	return [UIColor colorWithRed:rgba[0] green:rgba[1] blue:rgba[2] alpha:rgba[3]];
}
