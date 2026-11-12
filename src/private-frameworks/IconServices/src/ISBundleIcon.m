/*
 This file is part of Darling.

 Copyright (C) 2023 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <IconServices/ISBundleIcon.h>
#import <IconServices/ISImageDescriptor.h>
#import <IconServices/IFImage.h>
#include <ImageIO/ImageIO.h>
#include <math.h>

@implementation ISBundleIcon

@synthesize url = _url;
@synthesize type = _type;
@synthesize tag = _tag;
@synthesize tagClass = _tagClass;

- (instancetype)initWithBundleURL:(NSURL *)url type:(NSString *)type tag:(NSString *)tag tagClass:(NSString *)tagClass
{
	self = [super init];
	if (self != nil) {
		_url = [url retain];
		_type = [type copy];
		_tag = [tag copy];
		_tagClass = [tagClass copy];
	}
	return self;
}

- (instancetype)initWithBundleURL:(NSURL *)url
{
	return [self initWithBundleURL:url type:nil tag:nil tagClass:nil];
}

- (instancetype)initWithBundleURL:(NSURL *)url type:(NSString *)type
{
	return [self initWithBundleURL:url type:type tag:nil tagClass:nil];
}

- (instancetype)initWithBundleURL:(NSURL *)url fileExtension:(NSString *)extension
{
	return [self initWithBundleURL:url type:nil tag:extension tagClass:@"public.filename-extension"];
}

- (void)dealloc
{
	[_url release];
	[_type release];
	[_tag release];
	[_tagClass release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p %@>", [self class], self, [_url path]];
}

/* The icon file names the Info.plist gives, iPhone's first. */
static NSArray *iconNames(NSDictionary *info)
{
	NSMutableArray *names = [NSMutableArray array];
	for (NSString *key in @[@"CFBundleIcons", @"CFBundleIcons~ipad"]) {
		NSDictionary *icons = [info objectForKey:key];
		if (![icons isKindOfClass:[NSDictionary class]])
			continue;
		NSDictionary *primary = [icons objectForKey:@"CFBundlePrimaryIcon"];
		if (![primary isKindOfClass:[NSDictionary class]])
			continue;
		NSArray *files = [primary objectForKey:@"CFBundleIconFiles"];
		if ([files isKindOfClass:[NSArray class]])
			[names addObjectsFromArray:files];
	}
	NSArray *files = [info objectForKey:@"CFBundleIconFiles"];
	if ([files isKindOfClass:[NSArray class]])
		[names addObjectsFromArray:files];
	NSString *file = [info objectForKey:@"CFBundleIconFile"];
	if ([file isKindOfClass:[NSString class]])
		[names addObject:file];
	return names;
}

/* The bundle's files a name stands for: "AppIcon60x60" is AppIcon60x60@2x.png,
   AppIcon60x60@3x.png, AppIcon60x60~ipad.png and so on. */
static BOOL fileMatches(NSString *file, NSString *base)
{
	if (![[[file pathExtension] lowercaseString] isEqualToString:@"png"] || ![file hasPrefix:base])
		return NO;
	NSString *rest = [[file stringByDeletingPathExtension] substringFromIndex:[base length]];
	return [rest length] == 0 || [rest hasPrefix:@"@"] || [rest hasPrefix:@"~"];
}

static CGImageRef copyImage(NSString *path)
{
	CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:path], NULL);
	if (source == NULL)
		return NULL;
	CGImageRef image = CGImageSourceGetCount(source) > 0 ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
	CFRelease(source);
	return image;
}

/* The largest of the bundle's icon images. Icons only in an asset catalog are not read. */
- (CGImageRef)copyLargestIconImage
{
	NSString *root = [_url path];
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:NULL];
	NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[root stringByAppendingPathComponent:@"Info.plist"]];
	NSMutableArray *candidates = [NSMutableArray array];
	for (NSString *name in iconNames(info)) {
		NSString *base = [name stringByDeletingPathExtension];
		for (NSString *file in files)
			if (fileMatches(file, base) && ![candidates containsObject:file])
				[candidates addObject:file];
	}
	if ([candidates count] == 0)
		for (NSString *file in files)
			if (fileMatches(file, @"AppIcon") || fileMatches(file, @"Icon") || fileMatches(file, @"icon"))
				[candidates addObject:file];

	CGImageRef best = NULL;
	for (NSString *file in candidates) {
		CGImageRef image = copyImage([root stringByAppendingPathComponent:file]);
		if (image == NULL)
			continue;
		if (best == NULL || CGImageGetWidth(image) > CGImageGetWidth(best)) {
			CGImageRelease(best);
			best = image;
		} else
			CGImageRelease(image);
	}
	return best;
}

/* The home screen's rounded square, the corners about 22% of the side: what lies
   outside them goes, the edge antialiased (premultiplied RGBA, so all four bytes scale). */
static void maskIconShape(unsigned char *pixels, size_t side, size_t bytesPerRow)
{
	double r = side * 0.225;
	for (size_t y = 0; y < side; y++) {
		double cy = y + 0.5 < r ? r : (y + 0.5 > side - r ? side - r : y + 0.5);
		for (size_t x = 0; x < side; x++) {
			double cx = x + 0.5 < r ? r : (x + 0.5 > side - r ? side - r : x + 0.5);
			double d = hypot(x + 0.5 - cx, y + 0.5 - cy);
			double coverage = r + 0.5 - d;
			if (coverage >= 1)
				continue;
			unsigned char *p = pixels + y * bytesPerRow + x * 4;
			for (int c = 0; c < 4; c++)
				p[c] = coverage <= 0 ? 0 : (unsigned char) lround(p[c] * coverage);
		}
	}
}

- (IFImage *)imageForImageDescriptor:(ISImageDescriptor *)descriptor
{
	CGImageRef icon = [self copyLargestIconImage];
	if (icon == NULL)
		return nil;
	CGFloat scale = descriptor != nil && [descriptor scale] > 0 ? [descriptor scale] : 1;
	CGSize size = descriptor != nil ? [descriptor size] : CGSizeMake(60, 60);
	size_t side = (size_t) ceil(MAX(size.width, size.height) * scale);
	if (side == 0)
		side = CGImageGetWidth(icon);

	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, side, side, 8, side * 4, space, kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(space);
	if (context == NULL) {
		CGImageRelease(icon);
		return nil;
	}
	CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
	CGContextDrawImage(context, CGRectMake(0, 0, side, side), icon);
	CGImageRelease(icon);
	maskIconShape(CGBitmapContextGetData(context), side, CGBitmapContextGetBytesPerRow(context));
	CGImageRef drawn = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	IFImage *image = [[[IFImage alloc] initWithCGImage:drawn scale:scale] autorelease];
	CGImageRelease(drawn);
	return image;
}

- (CGImageRef)CGImageForImageDescriptor:(ISImageDescriptor *)descriptor
{
	return [[self imageForImageDescriptor:descriptor] CGImage];
}

@end
