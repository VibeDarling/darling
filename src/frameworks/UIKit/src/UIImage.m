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

@implementation UIImage {
	NSImage *_image;
}

+ (UIImage *)imageNamed:(NSString *)name
{
	NSBundle *bundle = [NSBundle mainBundle];
	NSString *path = [bundle pathForResource:name ofType:[[name pathExtension] length] > 0 ? nil : @"png"];
	if (path == nil)
		path = [bundle pathForResource:[name stringByAppendingString:@"@2x"] ofType:@"png"];
	return path != nil ? [self imageWithContentsOfFile:path] : nil;
}

+ (UIImage *)imageWithContentsOfFile:(NSString *)path
{
	return [[self alloc] initWithContentsOfFile:path];
}

- (instancetype)initWithContentsOfFile:(NSString *)path
{
	NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
	if (image == nil || [image size].width <= 0)
		return nil;
	if ((self = [super init]))
		_image = image;
	return self;
}

- (CGSize)size
{
	NSSize size = [_image size];
	return CGSizeMake(size.width, size.height);
}

- (CGImageRef)CGImage
{
	return [_image CGImageForProposedRect:NULL context:nil hints:nil];
}

- (void)drawInRect:(CGRect)rect
{
	/* UIKit views are flipped; draw the image upright in them. */
	[_image drawInRect:NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
	          fromRect:NSZeroRect
	         operation:NSCompositeSourceOver
	          fraction:1.0
	    respectFlipped:YES
	             hints:nil];
}

@end

CGContextRef UIGraphicsGetCurrentContext(void)
{
	return (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
}
