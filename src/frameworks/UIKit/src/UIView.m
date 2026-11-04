/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIView.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIWindow.h>
#import <AppKit/NSGraphics.h>

#import "UIKitPrivate.h"

@implementation UIView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil) {
		_uiNeedsLayout = YES;
		_uiTransform = CGAffineTransformIdentity;
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self != nil) {
		_uiNeedsLayout = YES;
		_uiTransform = CGAffineTransformIdentity;
	}
	return self;
}

- (CGPoint)center
{
	CGRect frame = [self frame];
	return CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
}

- (void)setCenter:(CGPoint)center
{
	CGSize size = [self frame].size;
	[self setFrameOrigin:CGPointMake(center.x - size.width / 2, center.y - size.height / 2)];
}

- (CGAffineTransform)transform
{
	return _uiTransform;
}

- (void)setTransform:(CGAffineTransform)transform
{
	_uiTransform = transform;
}

- (CGFloat)alpha
{
	return [self alphaValue];
}

- (void)setAlpha:(CGFloat)alpha
{
	[self setAlphaValue:alpha];
}

- (NSInteger)tag
{
	return _uiTag;
}

- (void)setTag:(NSInteger)tag
{
	_uiTag = tag;
}

- (BOOL)clipsToBounds
{
	return _uiClipsToBounds;
}

- (void)setClipsToBounds:(BOOL)clipsToBounds
{
	_uiClipsToBounds = clipsToBounds;
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

- (void)drawRect:(NSRect)rect
{
	if (_uiBackgroundColor != nil) {
		[_uiBackgroundColor setFill];
		NSRectFill(rect);
	}
}

@end
