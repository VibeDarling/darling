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
#import <objc/message.h>
#include <dispatch/dispatch.h>

@implementation UIView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil) {
		_uiNeedsLayout = YES;
		_uiOpaque = YES;
		_uiTransform = CGAffineTransformIdentity;
	}
	return self;
}

- (instancetype)init
{
	return [self initWithFrame:CGRectZero];
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

/* iOS lays views out before the next display; do it at the end of this
 * turn of the main run loop. */
- (void)setNeedsLayout
{
	_uiNeedsLayout = YES;
	if (_uiLayoutScheduled)
		return;
	_uiLayoutScheduled = YES;
	UIView *view = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		view->_uiLayoutScheduled = NO;
		[view layoutIfNeeded];
	});
}

- (void)setFrameSize:(NSSize)size
{
	NSSize old = [self frame].size;
	[super setFrameSize:size];
	if (old.width != size.width || old.height != size.height) {
		if (_uiNeedsDisplayOnBoundsChange)
			[self setNeedsDisplay:YES];
		_uiNeedsLayout = YES;
		[self layoutIfNeeded];
	}
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

#pragma mark - Geometry and hierarchy

- (CGFloat)alpha
{
	return [self alphaValue];
}

- (void)setAlpha:(CGFloat)alpha
{
	[self setAlphaValue:alpha];
	[self setNeedsDisplay:YES];
}

- (NSInteger)tag
{
	return _uiTag;
}

- (void)setTag:(NSInteger)tag
{
	_uiTag = tag;
}

- (CGPoint)center
{
	NSRect frame = [self frame];
	return CGPointMake(NSMidX(frame), NSMidY(frame));
}

- (void)setCenter:(CGPoint)center
{
	NSSize size = [self frame].size;
	[self setFrameOrigin:NSMakePoint(center.x - size.width / 2, center.y - size.height / 2)];
	[[self superview] setNeedsDisplay:YES];
}

- (BOOL)clipsToBounds { return _uiClipsToBounds; }
- (void)setClipsToBounds:(BOOL)clips { _uiClipsToBounds = clips; }
- (BOOL)isOpaque { return _uiOpaque && _uiBackgroundColor != nil && [_uiBackgroundColor alphaComponent] >= 1; }
- (void)setOpaque:(BOOL)opaque { _uiOpaque = opaque; }
- (UIViewContentMode)contentMode { return _uiContentMode; }
- (void)setContentMode:(UIViewContentMode)mode { _uiContentMode = mode; }
- (CGAffineTransform)transform { return _uiTransform; }
- (void)setTransform:(CGAffineTransform)transform { _uiTransform = transform; }
- (BOOL)isExclusiveTouch { return _uiExclusiveTouch; }
- (void)setExclusiveTouch:(BOOL)exclusive { _uiExclusiveTouch = exclusive; }
- (BOOL)isMultipleTouchEnabled { return _uiMultipleTouchEnabled; }
- (void)setMultipleTouchEnabled:(BOOL)enabled { _uiMultipleTouchEnabled = enabled; }
- (BOOL)needsDisplayOnBoundsChange { return _uiNeedsDisplayOnBoundsChange; }
- (void)setNeedsDisplayOnBoundsChange:(BOOL)needs { _uiNeedsDisplayOnBoundsChange = needs; }
- (CGFloat)contentScaleFactor { return 1; }
- (void)setContentScaleFactor:(CGFloat)factor { }

- (void)setNeedsDisplay
{
	[self setNeedsDisplay:YES];
}

- (CGSize)sizeThatFits:(CGSize)size
{
	NSSize current = [self bounds].size;
	return CGSizeMake(current.width, current.height);
}

- (void)sizeToFit
{
	CGSize size = [self sizeThatFits:[self bounds].size];
	[self setFrameSize:NSMakeSize(size.width, size.height)];
}

- (UIView *)viewWithTag:(NSInteger)tag
{
	if (_uiTag == tag)
		return self;
	for (NSView *subview in [self subviews]) {
		if (![subview isKindOfClass:[UIView class]])
			continue;
		UIView *found = [(UIView *)subview viewWithTag:tag];
		if (found != nil)
			return found;
	}
	return nil;
}

- (void)bringSubviewToFront:(UIView *)view
{
	if ([view superview] != self)
		return;
	[view removeFromSuperview];
	[self addSubview:view];
}

- (void)sendSubviewToBack:(UIView *)view
{
	if ([view superview] != self)
		return;
	[self insertSubview:view atIndex:0];
}

- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index
{
	NSArray *subviews = [self subviews];
	if ([view superview] == self)
		subviews = [subviews filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != %@", view]];
	if (index < 0 || (NSUInteger)index >= [subviews count]) {
		[view removeFromSuperview];
		[self addSubview:view];
		return;
	}
	[self insertSubview:view belowSubview:[subviews objectAtIndex:index]];
}

- (void)insertSubview:(UIView *)view belowSubview:(UIView *)sibling
{
	if (sibling == nil || [sibling superview] != self) {
		[self addSubview:view];
		return;
	}
	[view removeFromSuperview];
	[self addSubview:view positioned:NSWindowBelow relativeTo:sibling];
	if ([view isKindOfClass:[UIView class]] && _uiWindow != nil)
		[view attachToWindow:_uiWindow];
	[self setNeedsLayout];
}

- (void)insertSubview:(UIView *)view aboveSubview:(UIView *)sibling
{
	if (sibling == nil || [sibling superview] != self) {
		[self addSubview:view];
		return;
	}
	[view removeFromSuperview];
	[self addSubview:view positioned:NSWindowAbove relativeTo:sibling];
	if ([view isKindOfClass:[UIView class]] && _uiWindow != nil)
		[view attachToWindow:_uiWindow];
	[self setNeedsLayout];
}

- (BOOL)endEditing:(BOOL)force
{
	NSWindow *window = [self window];
	NSResponder *responder = [window firstResponder];
	if ([responder isKindOfClass:[NSView class]] && [(NSView *)responder isDescendantOf:self])
		return [window makeFirstResponder:window];
	return YES;
}

- (BOOL)isDescendantOfView:(UIView *)view
{
	return [self isDescendantOf:view];
}

- (void)willMoveToSuperview:(UIView *)superview { }
- (void)didMoveToSuperview { }
- (void)willMoveToWindow:(UIWindow *)window { }
- (void)didMoveToWindow { }
- (void)didAddSubview:(UIView *)subview { }
- (void)willRemoveSubview:(UIView *)subview { }

- (void)viewWillMoveToSuperview:(NSView *)superview
{
	[super viewWillMoveToSuperview:superview];
	[self willMoveToSuperview:[superview isKindOfClass:[UIView class]] ? (UIView *)superview : nil];
}

- (void)viewDidMoveToSuperview
{
	[super viewDidMoveToSuperview];
	[self didMoveToSuperview];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	[self didMoveToWindow];
}

#pragma mark - Animations

/* Nothing animates; a block's changes take effect when it runs. */
static id sAnimationDelegate;
static SEL sAnimationDidStop;
static SEL sAnimationWillStart;
static NSString *sAnimationID;
static void *sAnimationContext;
static NSInteger sAnimationDepth;
static BOOL sAnimationsDisabled;

+ (void)beginAnimations:(NSString *)animationID context:(void *)context
{
	if (sAnimationDepth++ == 0) {
		sAnimationDelegate = nil;
		sAnimationDidStop = NULL;
		sAnimationWillStart = NULL;
		sAnimationID = [animationID copy];
		sAnimationContext = context;
	}
}

+ (void)commitAnimations
{
	if (sAnimationDepth == 0 || --sAnimationDepth > 0)
		return;
	id delegate = sAnimationDelegate;
	SEL willStart = sAnimationWillStart, didStop = sAnimationDidStop;
	NSString *animationID = sAnimationID;
	void *context = sAnimationContext;
	sAnimationDelegate = nil;
	if (delegate == nil)
		return;
	/* As UIKit does, report after the current event is handled. */
	dispatch_async(dispatch_get_main_queue(), ^{
		if (willStart != NULL && [delegate respondsToSelector:willStart])
			((void (*)(id, SEL, NSString *, void *))objc_msgSend)(delegate, willStart, animationID, context);
		if (didStop != NULL && [delegate respondsToSelector:didStop])
			((void (*)(id, SEL, NSString *, NSNumber *, void *))objc_msgSend)(delegate, didStop, animationID, @YES, context);
	});
}

+ (void)setAnimationDelegate:(id)delegate { sAnimationDelegate = delegate; }
+ (void)setAnimationDidStopSelector:(SEL)selector { sAnimationDidStop = selector; }
+ (void)setAnimationWillStartSelector:(SEL)selector { sAnimationWillStart = selector; }
+ (void)setAnimationDuration:(NSTimeInterval)duration { }
+ (void)setAnimationDelay:(NSTimeInterval)delay { }
+ (void)setAnimationCurve:(UIViewAnimationCurve)curve { }
+ (void)setAnimationBeginsFromCurrentState:(BOOL)fromCurrentState { }
+ (void)setAnimationRepeatCount:(float)repeatCount { }
+ (void)setAnimationTransition:(NSInteger)transition forView:(UIView *)view cache:(BOOL)cache { }
+ (void)setAnimationsEnabled:(BOOL)enabled { sAnimationsDisabled = !enabled; }
+ (BOOL)areAnimationsEnabled { return !sAnimationsDisabled; }

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
	if (animations != nil)
		animations();
	if (completion != nil)
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(YES);
		});
}

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
	[self animateWithDuration:duration delay:0 options:0 animations:animations completion:completion];
}

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
	[self animateWithDuration:duration delay:0 options:0 animations:animations completion:nil];
}

+ (void)performWithoutAnimation:(void (^)(void))actions
{
	if (actions != nil)
		actions();
}

- (void)drawRect:(NSRect)rect
{
	if (_uiBackgroundColor != nil) {
		[_uiBackgroundColor setFill];
		NSRectFill(rect);
	}
}

@end
