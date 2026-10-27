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
#import <UIKit/UITouch.h>
#import <UIKit/UIEvent.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSEvent.h>

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

#pragma mark - Touches

/* The pointer is the only finger, so one touch is live at a time. */
static UITouch *sActiveTouch;

- (BOOL)isUserInteractionEnabled
{
	return !_uiUserInteractionDisabled;
}

- (void)setUserInteractionEnabled:(BOOL)enabled
{
	_uiUserInteractionDisabled = !enabled;
}

- (NSView *)hitTest:(NSPoint)point
{
	if (_uiUserInteractionDisabled || [self isHidden])
		return nil;
	return [super hitTest:point];
}

/* A tap on a window that is not key is still a tap. */
- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
	return YES;
}

- (void)mouseDown:(NSEvent *)event
{
	UITouch *touch = [[UITouch alloc] init];
	touch.view = self;
	touch.window = _uiWindow;
	[touch updateWithEvent:event phase:UITouchPhaseBegan];
	sActiveTouch = touch;
	[self touchesBegan:[NSSet setWithObject:touch] withEvent:[[UIEvent alloc] initWithTouch:touch]];
}

- (void)mouseDragged:(NSEvent *)event
{
	UITouch *touch = sActiveTouch;
	if (touch == nil)
		return;
	[touch updateWithEvent:event phase:UITouchPhaseMoved];
	[touch.view touchesMoved:[NSSet setWithObject:touch] withEvent:[[UIEvent alloc] initWithTouch:touch]];
}

- (void)mouseUp:(NSEvent *)event
{
	UITouch *touch = sActiveTouch;
	if (touch == nil)
		return;
	sActiveTouch = nil;
	[touch updateWithEvent:event phase:UITouchPhaseEnded];
	[touch.view touchesEnded:[NSSet setWithObject:touch] withEvent:[[UIEvent alloc] initWithTouch:touch]];
}

- (UIView *)touchParent
{
	NSView *superview = [self superview];
	return [superview isKindOfClass:[UIView class]] ? (UIView *)superview : nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	[[self touchParent] touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	[[self touchParent] touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	[[self touchParent] touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	[[self touchParent] touchesCancelled:touches withEvent:event];
}

- (void)drawRect:(NSRect)rect
{
	if (_uiBackgroundColor != nil) {
		[_uiBackgroundColor setFill];
		NSRectFill(rect);
	}
}

@end
