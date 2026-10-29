/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIGraphics.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIScreen.h>
#import <AppKit/NSGraphicsContext.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>

/*
 * UIKit draws through AppKit's current graphics context, so pushing a
 * context makes an NSGraphicsContext for it current, and popping puts back
 * the one before. An image context is a bitmap flipped to UIKit's top-left
 * origin, at the screen's scale unless told otherwise.
 */

@interface UIKitGraphicsEntry : NSObject {
@public
	NSGraphicsContext *previous;
	CGContextRef bitmap;
	CGFloat scale;
	BOOL image;
}
@end

@implementation UIKitGraphicsEntry

- (void)dealloc
{
	if (bitmap != NULL)
		CGContextRelease(bitmap);
}

@end

/* Per thread, as on iOS. */
static NSMutableArray<UIKitGraphicsEntry *> *UIKitGraphicsStack(void)
{
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
	NSMutableArray *stack = [threadDictionary objectForKey:@"UIKitGraphicsStack"];
	if (stack == nil) {
		stack = [NSMutableArray array];
		[threadDictionary setObject:stack forKey:@"UIKitGraphicsStack"];
	}
	return stack;
}

static void UIKitPush(UIKitGraphicsEntry *entry, CGContextRef context)
{
	entry->previous = [NSGraphicsContext currentContext];
	[UIKitGraphicsStack() addObject:entry];
	[NSGraphicsContext setCurrentContext:context != NULL ? [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES] : nil];
}

static UIKitGraphicsEntry *UIKitPop(void)
{
	NSMutableArray *stack = UIKitGraphicsStack();
	UIKitGraphicsEntry *entry = [stack lastObject];
	if (entry == nil)
		return nil;
	[stack removeLastObject];
	[NSGraphicsContext setCurrentContext:entry->previous];
	return entry;
}

void UIGraphicsPushContext(CGContextRef context)
{
	UIKitPush([[UIKitGraphicsEntry alloc] init], context);
}

void UIGraphicsPopContext(void)
{
	UIKitGraphicsEntry *top = [UIKitGraphicsStack() lastObject];
	if (top != nil && !top->image)
		UIKitPop();
}

void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale)
{
	if (scale <= 0)
		scale = [[UIScreen mainScreen] scale];
	if (scale <= 0)
		scale = 1;
	size_t width = (size_t)ceil(size.width * scale), height = (size_t)ceil(size.height * scale);
	UIKitGraphicsEntry *entry = [[UIKitGraphicsEntry alloc] init];
	entry->image = YES;
	entry->scale = scale;
	if (width == 0 || height == 0) {
		NSLog(@"UIGraphicsBeginImageContext: invalid size %gx%g", size.width, size.height);
		UIKitPush(entry, NULL);
		return;
	}
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGBitmapInfo info = kCGBitmapByteOrder32Little | (opaque ? kCGImageAlphaNoneSkipFirst : kCGImageAlphaPremultipliedFirst);
	CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace, info);
	CGColorSpaceRelease(colorSpace);
	if (bitmap == NULL) {
		UIKitPush(entry, NULL);
		return;
	}
	CGContextClearRect(bitmap, CGRectMake(0, 0, width, height));
	CGContextTranslateCTM(bitmap, 0, height);
	CGContextScaleCTM(bitmap, scale, -scale);
	entry->bitmap = bitmap;
	UIKitPush(entry, bitmap);
}

void UIGraphicsBeginImageContext(CGSize size)
{
	UIGraphicsBeginImageContextWithOptions(size, NO, 1);
}

UIImage *UIGraphicsGetImageFromCurrentImageContext(void)
{
	UIKitGraphicsEntry *top = [UIKitGraphicsStack() lastObject];
	if (top == nil || !top->image || top->bitmap == NULL)
		return nil;
	CGImageRef cgImage = CGBitmapContextCreateImage(top->bitmap);
	if (cgImage == NULL)
		return nil;
	UIImage *image = [UIImage imageWithCGImage:cgImage scale:top->scale orientation:0];
	CGImageRelease(cgImage);
	return image;
}

void UIGraphicsEndImageContext(void)
{
	UIKitGraphicsEntry *top = [UIKitGraphicsStack() lastObject];
	if (top != nil && top->image)
		UIKitPop();
}

void UIRectFillUsingBlendMode(CGRect rect, CGBlendMode blendMode)
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (context == NULL)
		return;
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, blendMode);
	CGContextFillRect(context, rect);
	CGContextRestoreGState(context);
}

void UIRectFrameUsingBlendMode(CGRect rect, CGBlendMode blendMode)
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (context == NULL)
		return;
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, blendMode);
	CGContextStrokeRectWithWidth(context, CGRectInset(rect, 0.5, 0.5), 1);
	CGContextRestoreGState(context);
}

void UIRectClip(CGRect rect)
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (context != NULL)
		CGContextClipToRect(context, rect);
}
