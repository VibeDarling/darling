/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIView.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSWindow.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIScreen.h>
#import <AppKit/NSGraphics.h>

#import "UIKitPrivate.h"

@implementation UIView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil)
		_uiNeedsLayout = YES;
	return self;
}

/* UIKit's origin is top-left; AppKit's is bottom-left. */
- (BOOL)isFlipped
{
	return YES;
}

- (void)setBackgroundColor:(UIColor *)color
{
	_uiBackgroundColor = color;
	[self setNeedsDisplay:YES];
}

- (UIColor *)backgroundColor
{
	return _uiBackgroundColor;
}

- (UIWindow *)uiWindow
{
	return _uiWindow;
}

/* A new size goes to the layer too. */
- (void)setFrame:(NSRect)frame
{
	[super setFrame:frame];
	[_uiLayer setBounds:NSRectToCGRect([self bounds])];
}

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];
	[_uiLayer setBounds:NSRectToCGRect([self bounds])];
}

/* The screen's, until the app sets its own (as GL views do, to draw at it). */
- (CGFloat)contentScaleFactor
{
	if (_uiContentScaleFactor > 0)
		return _uiContentScaleFactor;
	return [[UIScreen mainScreen] scale];
}

- (void)setContentScaleFactor:(CGFloat)factor
{
	_uiContentScaleFactor = factor;
	[_uiLayer setContentsScale:[self contentScaleFactor]];
}

/*
 * Every iOS view has a layer, of its class's +layerClass. Here views draw themselves as AppKit's
 * do, so a layer holds only what the app puts in it: UIKit draws its contents (an image, such as a
 * video frame AVSampleBufferDisplayLayer was given) under the view's own drawing.
 */
+ (Class)layerClass
{
	return [CALayer class];
}

- (CALayer *)layer
{
	if (_uiLayer == nil) {
		_uiLayer = [[[self class] layerClass] new];
		[_uiLayer setDelegate:(id)self];
		[_uiLayer setBounds:NSRectToCGRect([self bounds])];
		[_uiLayer setContentsScale:[self contentScaleFactor]];
	}
	return _uiLayer;
}

/* Whether the layer is an OpenGL ES one (CAEAGLLayer); with opaque, whether it also shows an opaque
   frame, which covers the whole view. */
- (BOOL)uikitShowsGLFrame:(BOOL)opaque
{
	if (![_uiLayer isKindOfClass:NSClassFromString(@"CAEAGLLayer")])
		return NO;
	return !opaque || ([_uiLayer isOpaque] && [_uiLayer contents] != nil);
}

/* A presented GL frame covers the view: then presenting one draws only the view (and what is in
   front of it), not everything behind it. */
- (BOOL)isOpaque
{
	return [self uikitShowsGLFrame:YES];
}

/* The layer's contents, a CGImage, placed by its contentsGravity: filling the view, or scaled to fit
   or fill it keeping its aspect, centred. */
- (void)uikitDrawLayerContents
{
	id contents = [_uiLayer contents];
	/* Cocotron's CGImages are O2Images. */
	if (contents == nil || ![contents isKindOfClass:NSClassFromString(@"O2Image")])
		return;
	CGImageRef image = (__bridge CGImageRef)contents;
	CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGRect bounds = NSRectToCGRect([self bounds]);
	NSString *gravity = [_uiLayer contentsGravity];
	CGFloat width = CGImageGetWidth(image), height = CGImageGetHeight(image);
	BOOL fit = [gravity isEqualToString:kCAGravityResizeAspect], fill = [gravity isEqualToString:kCAGravityResizeAspectFill];
	if ((fit || fill) && width > 0 && height > 0) {
		CGFloat sx = bounds.size.width / width, sy = bounds.size.height / height;
		CGFloat scale = fit ? MIN(sx, sy) : MAX(sx, sy);
		CGRect placed = CGRectMake(0, 0, width * scale, height * scale);
		placed.origin.x = CGRectGetMidX(bounds) - placed.size.width / 2;
		placed.origin.y = CGRectGetMidY(bounds) - placed.size.height / 2;
		bounds = placed;
	}
	CGContextSaveGState(context);
	if (fill)
		CGContextClipToRect(context, NSRectToCGRect([self bounds]));
	/* Drawn in the flipped view, an image comes out upside down: as a GL frame's bottom-up rows
	   want it, the rest get turned back about their rect. */
	if (![self uikitShowsGLFrame:NO]) {
		CGContextTranslateCTM(context, 0, bounds.origin.y * 2 + bounds.size.height);
		CGContextScaleCTM(context, 1, -1);
	}
	CGContextDrawImage(context, bounds, image);
	CGContextRestoreGState(context);
}

/* iOS's: the UIWindow the view is in. The AppKit window that hosts it is -_appKitWindow. */
- (UIWindow *)window
{
	return _uiWindow;
}

- (void)setWindow:(UIWindow *)window
{
	_uiWindow = window;
}

- (void)attachToWindow:(UIWindow *)window
{
	[self setWindow:window];
	for (NSView *subview in [self subviews]) {
		if ([subview isKindOfClass:[UIView class]])
			[(UIView *)subview attachToWindow:window];
	}
}

- (void)addSubview:(NSView *)view
{
	[super addSubview:view];
	if ([view isKindOfClass:[UIView class]]) {
		if (_uiWindow != nil)
			[(UIView *)view attachToWindow:_uiWindow];
		[self setNeedsLayout];
	}
}

- (void)layoutSubviews
{
}

- (void)setNeedsLayout
{
	_uiNeedsLayout = YES;
}

- (void)layoutIfNeeded
{
	if (_uiNeedsLayout) {
		_uiNeedsLayout = NO;
		[self layoutSubviews];
	}
}

/*
 * On iOS a view draws into a layer of its own, composited over what is behind it, so its
 * drawRect: may clear what it draws on (VLC's subtitle view does, over the whole video). Here views
 * share the window's backing store: a non-opaque view whose class has its own drawRect: draws into a
 * transparent bitmap first, which then goes over what is behind it. UIKit's own views are written
 * for the shared store and draw into it directly.
 */
static BOOL drawsInOwnBuffer(UIView *view)
{
	static NSMapTable *decisions;
	static NSBundle *uikit;
	if (decisions == nil) {
		decisions = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
			valueOptions:NSPointerFunctionsStrongMemory capacity:16];
		uikit = [NSBundle bundleForClass:[UIView class]];
	}
	Class cls = [view class];
	NSNumber *decision = [decisions objectForKey:cls];
	if (decision == nil) {
		IMP draw = [cls instanceMethodForSelector:@selector(drawRect:)];
		Class owner = cls;
		while ([owner superclass] != Nil && [[owner superclass] instanceMethodForSelector:@selector(drawRect:)] == draw)
			owner = [owner superclass];
		decision = @(draw != [UIView instanceMethodForSelector:@selector(drawRect:)] && [NSBundle bundleForClass:owner] != uikit);
		[decisions setObject:decision forKey:cls];
	}
	return [decision boolValue] && ![view isOpaque];
}

- (void)_drawRectForDisplay:(NSRect)rect
{
	if (!drawsInOwnBuffer(self)) {
		[self drawRect:rect];
		return;
	}
	CGFloat scale = [self contentScaleFactor] > 0 ? [self contentScaleFactor] : 1;
	size_t width = (size_t)ceil(rect.size.width * scale), height = (size_t)ceil(rect.size.height * scale);
	if (width == 0 || height == 0)
		return;
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
		kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
	CGColorSpaceRelease(space);
	if (bitmap == NULL) {
		[self drawRect:rect];
		return;
	}
	/* The view's coordinates, flipped as the view is, rect's origin at the bitmap's top left. */
	CGContextTranslateCTM(bitmap, 0, height);
	CGContextScaleCTM(bitmap, scale, -scale);
	CGContextTranslateCTM(bitmap, -rect.origin.x, -rect.origin.y);
	NSGraphicsContext *outer = [NSGraphicsContext currentContext];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmap flipped:YES]];
	@try {
		[self drawRect:rect];
	} @finally {
		[NSGraphicsContext restoreGraphicsState];
		[NSGraphicsContext setCurrentContext:outer];
	}
	CGImageRef image = CGBitmapContextCreateImage(bitmap);
	CGContextRelease(bitmap);
	CGContextRef port = (CGContextRef)[outer graphicsPort];
	CGContextSaveGState(port);
	/* In the flipped view an image comes out upside down: turned back about rect. */
	CGContextTranslateCTM(port, 0, rect.origin.y * 2 + rect.size.height);
	CGContextScaleCTM(port, 1, -1);
	CGContextDrawImage(port, NSRectToCGRect(rect), image);
	CGContextRestoreGState(port);
	CGImageRelease(image);
}

- (void)drawRect:(NSRect)rect
{
	/* Filling under an opaque GL frame would cost as much again as drawing it. */
	if (_uiBackgroundColor != nil && ![self uikitShowsGLFrame:YES]) {
		[_uiBackgroundColor setFill];
		NSRectFill(rect);
	}
	if (_uiLayer != nil)
		[self uikitDrawLayerContents];
}

@end
