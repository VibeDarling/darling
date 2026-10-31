/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIImage.h>
#import <UIKit/UIGraphics.h>
#import "UIKitPrivate.h"
#import <AppKit/NSImage.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSGraphics.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSCache.h>
#import <AppKit/NSBitmapImageRep.h>
#import <ImageIO/CGImageSource.h>

@implementation UIImage {
	NSImage *_image;
	CGImageRef _cgImage;
	CGFloat _scale;
	UIImageRenderingMode _renderingMode;
}

static NSCache *sNamedImages;

/* name, name@2x, name@3x and the ~iphone variants, in the main bundle. */
+ (UIImage *)imageNamed:(NSString *)name
{
	if ([name length] == 0)
		return nil;
	if (sNamedImages == nil)
		sNamedImages = [[NSCache alloc] init];
	UIImage *cached = [sNamedImages objectForKey:name];
	if (cached != nil)
		return cached;

	NSBundle *bundle = [NSBundle mainBundle];
	NSString *extension = [name pathExtension];
	NSString *base = [extension length] > 0 ? [name stringByDeletingPathExtension] : name;
	if ([extension length] == 0)
		extension = @"png";
	UIImage *image = nil;
	for (NSString *suffix in @[ @"@2x", @"", @"@3x", @"@2x~iphone", @"~iphone" ]) {
		NSString *path = [bundle pathForResource:[base stringByAppendingString:suffix] ofType:extension];
		if (path == nil && [name hasPrefix:@"/"])
			path = [[base stringByAppendingString:suffix] stringByAppendingPathExtension:extension];
		if (path != nil && (image = [self imageWithContentsOfFile:path]) != nil)
			break;
	}
	if (image != nil)
		[sNamedImages setObject:image forKey:name];
	return image;
}

+ (UIImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle compatibleWithTraitCollection:(id)traitCollection
{
	if (bundle == nil || bundle == [NSBundle mainBundle])
		return [self imageNamed:name];
	for (NSString *suffix in @[ @"@2x", @"", @"@3x", @"@2x~iphone", @"~iphone" ]) {
		NSString *path = [bundle pathForResource:[[name stringByDeletingPathExtension] stringByAppendingString:suffix]
		                                  ofType:[[name pathExtension] length] > 0 ? [name pathExtension] : @"png"];
		UIImage *image = path != nil ? [self imageWithContentsOfFile:path] : nil;
		if (image != nil)
			return image;
	}
	return nil;
}

/* iOS's: the lock screen's wallpaper. The user has not set one here;
   SpringBoard draws its own, unless a theme answers this. */
+ (UIImage *)defaultDesktopImage
{
	return nil;
}

+ (UIImage *)imageAtPath:(NSString *)path
{
	return [self imageWithContentsOfFile:path];
}

+ (UIImage *)imageWithContentsOfFile:(NSString *)path
{
	return [[self alloc] initWithContentsOfFile:path];
}

+ (UIImage *)imageWithData:(NSData *)data
{
	return [[self alloc] initWithData:data];
}

+ (UIImage *)imageWithData:(NSData *)data scale:(CGFloat)scale
{
	return [[self alloc] initWithData:data scale:scale];
}

+ (UIImage *)imageWithCGImage:(CGImageRef)image
{
	return [[self alloc] initWithCGImage:image];
}

+ (UIImage *)imageWithCGImage:(CGImageRef)image scale:(CGFloat)scale orientation:(NSInteger)orientation
{
	return [[self alloc] initWithCGImage:image scale:scale orientation:orientation];
}

/* The scale a file's name declares (@2x, @3x). */
static CGFloat UIImageScaleForPath(NSString *path)
{
	NSString *name = [[path lastPathComponent] stringByDeletingPathExtension];
	if ([name hasSuffix:@"@3x"] || [name rangeOfString:@"@3x~"].location != NSNotFound)
		return 3;
	if ([name hasSuffix:@"@2x"] || [name rangeOfString:@"@2x~"].location != NSNotFound)
		return 2;
	return 1;
}

- (instancetype)initWithNSImage:(NSImage *)image scale:(CGFloat)scale
{
	if (image == nil || [image size].width <= 0)
		return nil;
	if ((self = [super init])) {
		_image = image;
		_scale = scale > 0 ? scale : 1;
		/* Point size: the pixels over the scale. */
		NSImageRep *rep = [[image representations] firstObject];
		if (rep != nil && [rep pixelsWide] > 0)
			[_image setSize:NSMakeSize([rep pixelsWide] / _scale, [rep pixelsHigh] / _scale)];
	}
	return self;
}

/* Read through ImageIO, as iOS's UIKit reads image files, so that what
   hooks it there (WinterBoard swaps in its themes' files) sees every file
   an app's images come from. */
- (instancetype)initWithContentsOfFile:(NSString *)path
{
	if (path == nil)
		return nil;
	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
	CGImageRef image = source != NULL && CGImageSourceGetCount(source) > 0 ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
	if (source != NULL)
		CFRelease(source);
	if (image == NULL)
		return [self initWithNSImage:[[NSImage alloc] initWithContentsOfFile:path] scale:UIImageScaleForPath(path)];
	self = [self initWithCGImage:image scale:UIImageScaleForPath(path) orientation:0];
	CGImageRelease(image);
	return self;
}

- (instancetype)initWithData:(NSData *)data
{
	return [self initWithData:data scale:1];
}

- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale
{
	if ([data length] == 0)
		return nil;
	return [self initWithNSImage:[[NSImage alloc] initWithData:data] scale:scale];
}

- (instancetype)initWithCGImage:(CGImageRef)image
{
	return [self initWithCGImage:image scale:1 orientation:0];
}

- (instancetype)initWithCGImage:(CGImageRef)image scale:(CGFloat)scale orientation:(NSInteger)orientation
{
	if (image == NULL)
		return nil;
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
	NSImage *nsImage = [[NSImage alloc] initWithSize:NSMakeSize(CGImageGetWidth(image), CGImageGetHeight(image))];
	[nsImage addRepresentation:rep];
	if ((self = [self initWithNSImage:nsImage scale:scale]) != nil)
		_cgImage = CGImageRetain(image);
	return self;
}

- (void)dealloc
{
	if (_cgImage != NULL)
		CGImageRelease(_cgImage);
}

- (NSImage *)nsImage
{
	return _image;
}

- (CGSize)size
{
	NSSize size = [_image size];
	return CGSizeMake(size.width, size.height);
}

- (CGFloat)scale
{
	return _scale;
}

- (NSInteger)imageOrientation
{
	return 0;
}

/* The pixels themselves, as on iOS, not the image drawn at its point size. */
- (CGImageRef)CGImage
{
	if (_cgImage != NULL)
		return _cgImage;
	for (NSImageRep *rep in [_image representations])
		if ([rep isKindOfClass:[NSBitmapImageRep class]] && [(NSBitmapImageRep *)rep CGImage] != NULL)
			return [(NSBitmapImageRep *)rep CGImage];
	return [_image CGImageForProposedRect:NULL context:nil hints:nil];
}

/* Cap insets are not honored: the image stretches as a whole. */
- (UIImage *)stretchableImageWithLeftCapWidth:(NSInteger)leftCapWidth topCapHeight:(NSInteger)topCapHeight
{
	return self;
}

- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)capInsets
{
	return self;
}

- (UIImageRenderingMode)renderingMode
{
	return _renderingMode;
}

- (UIImage *)imageWithRenderingMode:(UIImageRenderingMode)renderingMode
{
	if (renderingMode == _renderingMode)
		return self;
	UIImage *image = [[UIImage alloc] initWithNSImage:_image scale:_scale];
	image->_renderingMode = renderingMode;
	return image;
}

- (NSImage *)uikitImageTintedWith:(NSColor *)color
{
	CGSize size = [self size];
	if (size.width <= 0 || size.height <= 0)
		return nil;
	NSImage *tinted = [[NSImage alloc] initWithSize:NSMakeSize(size.width, size.height)];
	[tinted lockFocus];
	[self drawInRect:CGRectMake(0, 0, size.width, size.height)];
	[color set];
	NSRectFillUsingOperation(NSMakeRect(0, 0, size.width, size.height), NSCompositeSourceAtop);
	[tinted unlockFocus];
	return tinted;
}

- (UIImage *)imageWithTintColor:(UIColor *)color
{
	return [self imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (UIImage *)imageWithTintColor:(UIColor *)color renderingMode:(UIImageRenderingMode)renderingMode
{
	NSImage *tinted = [self uikitImageTintedWith:[color nsColor]];
	if (tinted == nil)
		return [self imageWithRenderingMode:renderingMode];
	/* tinted is already sized in points. */
	UIImage *image = [[UIImage alloc] initWithNSImage:tinted scale:1];
	image->_scale = _scale;
	image->_renderingMode = renderingMode;
	return image;
}

- (NSInteger)leftCapWidth
{
	return 0;
}

- (NSInteger)topCapHeight
{
	return 0;
}

- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
	/* UIKit views are flipped; draw the image upright in them. */
	[_image drawInRect:NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
	          fromRect:NSZeroRect
	         operation:NSCompositeSourceOver
	          fraction:alpha
	    respectFlipped:YES
	             hints:nil];
}

- (void)drawInRect:(CGRect)rect
{
	[self drawInRect:rect blendMode:kCGBlendModeNormal alpha:1];
}

- (void)drawAtPoint:(CGPoint)point blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
	CGSize size = [self size];
	[self drawInRect:CGRectMake(point.x, point.y, size.width, size.height) blendMode:blendMode alpha:alpha];
}

- (void)drawAtPoint:(CGPoint)point
{
	[self drawAtPoint:point blendMode:kCGBlendModeNormal alpha:1];
}

@end

static NSData *UIImageRepresentation(UIImage *image, NSBitmapImageFileType type, NSDictionary *properties)
{
	NSImage *nsImage = [image nsImage];
	NSBitmapImageRep *rep = nil;
	for (NSImageRep *candidate in [nsImage representations])
		if ([candidate isKindOfClass:[NSBitmapImageRep class]])
			rep = (NSBitmapImageRep *)candidate;
	if (rep == nil) {
		CGImageRef cgImage = [image CGImage];
		if (cgImage == NULL)
			return nil;
		rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
	}
	return [rep representationUsingType:type properties:properties ?: @{}];
}

NSData *UIImagePNGRepresentation(UIImage *image)
{
	return UIImageRepresentation(image, NSPNGFileType, nil);
}

NSData *UIImageJPEGRepresentation(UIImage *image, CGFloat compressionQuality)
{
	return UIImageRepresentation(image, NSJPEGFileType, @{ NSImageCompressionFactor: @(compressionQuality) });
}

CGContextRef UIGraphicsGetCurrentContext(void)
{
	return (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
}

/* A nib's image: named, in the nib's bundle. */
@interface UIImageNibPlaceholder : NSObject <NSCoding>
@end

@implementation UIImageNibPlaceholder

- (instancetype)initWithCoder:(NSCoder *)coder
{
	NSString *name = [coder decodeObjectForKey:@"UIResourceName"];
	UIImage *image = [name length] > 0 ? [UIImage imageNamed:name inBundle:UIKitNibBundle(coder) compatibleWithTraitCollection:nil] : nil;
	if (image == nil && [name length] > 0)
		NSLog(@"Could not load the \"%@\" image referenced from a nib in the bundle with identifier \"%@\"", name, [UIKitNibBundle(coder) bundleIdentifier]);
	return (id)image;
}

- (void)encodeWithCoder:(NSCoder *)coder { }

@end
