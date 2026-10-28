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
#import <AppKit/NSImage.h>
#import <AppKit/NSGraphicsContext.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSCache.h>
#import <AppKit/NSBitmapImageRep.h>

@implementation UIImage {
	NSImage *_image;
	CGFloat _scale;
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

- (instancetype)initWithContentsOfFile:(NSString *)path
{
	return [self initWithNSImage:[[NSImage alloc] initWithContentsOfFile:path] scale:UIImageScaleForPath(path)];
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
	return [self initWithNSImage:nsImage scale:scale];
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

- (CGImageRef)CGImage
{
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

- (UIImage *)imageWithRenderingMode:(NSInteger)renderingMode
{
	return self;
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
