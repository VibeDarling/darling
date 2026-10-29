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
#import <AppKit/NSTouch.h>

#import "UIKitPrivate.h"
#import <objc/message.h>
#include <dispatch/dispatch.h>
#include <math.h>

/* AppKit's: the view a finger began in, which UIKit hit tested for it. */
@interface NSTouch (UIKitTouchView)
- (NSView *)_view;
@end

/* AppKit installs an activated constraint on a view with this. */
@interface NSView (UIKitConstraintInstall)
- (void)nsli_addConstraint:(id)constraint;
@end

/* Set once any constraint is installed on a UIView: solving constraints
 * walks the whole window, which apps without any should not pay for. */
static BOOL sUIKitUsesConstraints;

@implementation UIView {
	BOOL _uiAppearanceApplied;
	UISemanticContentAttribute _uiSemanticContentAttribute;
	UIColor *_uiTintColor;
	UIViewTintAdjustmentMode _uiTintAdjustmentMode;
}

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

/* From a nib: made as UIKit's nearest class makes views (an app's own
 * -initWithFrame: does not run, as on iOS), then given the archived
 * properties, each UIKit class its own. */
- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self uikitInitForCoder:coder];
	if (self != nil)
		[self uikitDecodeNib:coder];
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

/* Nibs keep a view's bounds and center, not its frame. */
CGRect UIKitArchivedFrame(NSCoder *coder)
{
	CGRect bounds = [coder decodeCGRectForKey:@"UIBounds"];
	CGPoint center = [coder decodeCGPointForKey:@"UICenter"];
	return CGRectMake(center.x - bounds.size.width / 2, center.y - bounds.size.height / 2, bounds.size.width, bounds.size.height);
}

- (instancetype)uikitInitForCoder:(NSCoder *)coder
{
	IMP init = UIKitOwnImplementation([self class], @selector(initWithFrame:));
	return ((id (*)(id, SEL, CGRect))init)(self, @selector(initWithFrame:), UIKitArchivedFrame(coder));
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	CGRect bounds = [coder decodeCGRectForKey:@"UIBounds"];
	if (bounds.origin.x != 0 || bounds.origin.y != 0)
		[self setBoundsOrigin:NSMakePoint(bounds.origin.x, bounds.origin.y)];
	if ([coder containsValueForKey:@"UIBackgroundColor"])
		[self setBackgroundColor:[coder decodeObjectForKey:@"UIBackgroundColor"]];
	[self setAutoresizingMask:[coder decodeIntegerForKey:@"UIAutoresizingMask"]];
	[self setAutoresizesSubviews:[coder decodeBoolForKey:@"UIAutoresizeSubviews"]];
	[self setHidden:[coder decodeBoolForKey:@"UIHidden"]];
	if ([coder containsValueForKey:@"UIAlpha"])
		[self setAlpha:[coder decodeDoubleForKey:@"UIAlpha"]];
	[self setOpaque:[coder decodeBoolForKey:@"UIOpaque"]];
	[self setClipsToBounds:[coder decodeBoolForKey:@"UIClipsToBounds"]];
	[self setTag:[coder decodeIntegerForKey:@"UITag"]];
	if ([coder containsValueForKey:@"UIContentMode"])
		[self setContentMode:[coder decodeIntegerForKey:@"UIContentMode"]];
	[self setUserInteractionEnabled:![coder decodeBoolForKey:@"UIUserInteractionDisabled"]];
	[self setMultipleTouchEnabled:[coder decodeBoolForKey:@"UIMultipleTouchEnabled"]];
	[self setExclusiveTouch:[coder decodeBoolForKey:@"UIExclusiveTouch"]];
	if ([coder containsValueForKey:@"UITintColor"])
		[self setTintColor:[coder decodeObjectForKey:@"UITintColor"]];
	[self setSemanticContentAttribute:[coder decodeIntegerForKey:@"UIViewSemanticContentAttribute"]];
	if ([coder decodeBoolForKey:@"UIViewDoesNotTranslateAutoresizingMaskIntoConstraints"])
		[self setTranslatesAutoresizingMaskIntoConstraints:NO];

	for (NSView *subview in [coder decodeObjectForKey:@"UISubviews"]) {
		if ([subview isKindOfClass:[NSView class]])
			[self addSubview:subview];
	}
	/* Decoded constraints are marked active but belong to no view yet;
	 * with the subviews in place, they can find theirs. */
	for (NSLayoutConstraint *constraint in [coder decodeObjectForKey:@"UIViewAutolayoutConstraints"]) {
		if (![constraint isKindOfClass:[NSLayoutConstraint class]])
			continue;
		@try {
			[constraint setActive:NO];
			[constraint setActive:YES];
		} @catch (NSException *exception) {
			NSLog(@"UIView: a nib's constraint does not fit its views: %@", [exception reason]);
		}
	}
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

/*
 * On iOS a view that moves or resizes is redrawn where it was and where it is
 * now; AppKit leaves that to the caller.  Views laid out after their window
 * first displayed (from -layoutSubviews) would otherwise never be drawn.
 */
- (void)setFrame:(NSRect)frame
{
	NSRect old = [self frame];
	[super setFrame:frame];
	if (NSEqualRects(old, frame))
		return;
	/* A new size lays the view out again, as -setFrameSize: does; later,
	 * since this may be the constraint solver placing views. */
	if (!NSEqualSizes(old.size, frame.size))
		[self setNeedsLayout];
	NSView *superview = [self superview];
	if (superview != nil && [self window] != nil) {
		[superview setNeedsDisplayInRect:old];
		[superview setNeedsDisplayInRect:frame];
	}
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

- (void)nsli_addConstraint:(id)constraint
{
	sUIKitUsesConstraints = YES;
	[super nsli_addConstraint:constraint];
}

- (void)layoutIfNeeded
{
	/* Constraints may reach anything in the window, so solve from the top
	 * (with the safe areas where the views are now). */
	if (sUIKitUsesConstraints && ([self needsUpdateConstraints] || [self needsLayout])) {
		UIKitUpdateSafeAreas();
		NSView *root = self;
		while ([root superview] != nil)
			root = [root superview];
		[root setNeedsLayout:YES];
		[root layoutSubtreeIfNeeded];
	}
	if (_uiNeedsLayout) {
		_uiNeedsLayout = NO;
		[self layoutSubviews];
	}
}

#pragma mark - Touches

/* The primary mouse button is one finger; touch screen fingers come as
 * AppKit's direct touches, one UITouch for each. */
static UITouch *sMouseTouch;
static NSMutableDictionary<id, UITouch *> *sScreenTouches;

/* Fingers that come down quickly in the same place count taps. */
static NSTimeInterval sLastTapTime;
static CGPoint sLastTapPoint;
static NSUInteger sTapCount;

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
	if (sMouseTouch != nil)
		return;
	UITouch *touch = [[UITouch alloc] init];
	touch.view = self;
	touch.window = _uiWindow;
	[touch updateWithEvent:event phase:UITouchPhaseBegan];
	sMouseTouch = touch;
	UIKitDispatchTouch(touch, UITouchPhaseBegan);
}

- (void)mouseDragged:(NSEvent *)event
{
	UITouch *touch = sMouseTouch;
	if (touch == nil)
		return;
	[touch updateWithEvent:event phase:UITouchPhaseMoved];
	UIKitDispatchTouch(touch, UITouchPhaseMoved);
}

- (void)mouseUp:(NSEvent *)event
{
	UITouch *touch = sMouseTouch;
	if (touch == nil)
		return;
	sMouseTouch = nil;
	[touch updateWithEvent:event phase:UITouchPhaseEnded];
	UIKitDispatchTouch(touch, UITouchPhaseEnded);
}

/* All UIViews take touch screen fingers themselves. */
- (NSUInteger)allowedTouchTypes
{
	return NSTouchTypeMaskDirect | NSTouchTypeMaskIndirect;
}

- (void)uikitScreenTouches:(NSEvent *)event phase:(NSTouchPhase)phase
{
	if (sScreenTouches == nil)
		sScreenTouches = [NSMutableDictionary dictionary];
	for (NSTouch *screenTouch in [event touchesMatchingPhase:phase inView:self]) {
		if ([screenTouch _view] != self)
			continue;
		NSPoint location = [screenTouch locationInView:nil];
		UITouch *touch = [sScreenTouches objectForKey:[screenTouch identity]];
		UITouchPhase touchPhase;
		if (phase == NSTouchPhaseBegan) {
			touch = [[UITouch alloc] init];
			touch.view = self;
			touch.window = _uiWindow;
			CGPoint point = CGPointMake(location.x, location.y);
			if ([event timestamp] - sLastTapTime < 0.35 && hypot(point.x - sLastTapPoint.x, point.y - sLastTapPoint.y) < 30)
				sTapCount++;
			else
				sTapCount = 1;
			sLastTapTime = [event timestamp];
			sLastTapPoint = point;
			touch.tapCount = sTapCount;
			[sScreenTouches setObject:touch forKey:[screenTouch identity]];
			touchPhase = UITouchPhaseBegan;
		} else if (touch == nil) {
			continue;
		} else {
			touchPhase = phase == NSTouchPhaseMoved ? UITouchPhaseMoved
				: phase == NSTouchPhaseEnded ? UITouchPhaseEnded : UITouchPhaseCancelled;
		}
		if (touchPhase == UITouchPhaseEnded || touchPhase == UITouchPhaseCancelled)
			[sScreenTouches removeObjectForKey:[screenTouch identity]];
		[touch uikitMoveTo:location timestamp:[event timestamp] phase:touchPhase];
		UIKitDispatchTouch(touch, touchPhase);
	}
}

- (void)touchesBeganWithEvent:(NSEvent *)event { [self uikitScreenTouches:event phase:NSTouchPhaseBegan]; }
- (void)touchesMovedWithEvent:(NSEvent *)event { [self uikitScreenTouches:event phase:NSTouchPhaseMoved]; }
- (void)touchesEndedWithEvent:(NSEvent *)event { [self uikitScreenTouches:event phase:NSTouchPhaseEnded]; }
- (void)touchesCancelledWithEvent:(NSEvent *)event { [self uikitScreenTouches:event phase:NSTouchPhaseCancelled]; }

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
/* Private iOS names for frame.origin and clipsToBounds. */
- (CGPoint)origin { return [self frame].origin; }
- (void)setOrigin:(CGPoint)origin
{
	[self setFrameOrigin:NSMakePoint(origin.x, origin.y)];
}
- (BOOL)clipsSubviews { return _uiClipsToBounds; }
- (void)setClipsSubviews:(BOOL)clips { _uiClipsToBounds = clips; }
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
	/* An inherited tint may now be another one. */
	if (_uiTintColor == nil || _uiTintAdjustmentMode == UIViewTintAdjustmentModeAutomatic)
		[self uikitTintChangedInColor:YES adjustment:YES];
	[self didMoveToSuperview];
}

#pragma mark - Tint

- (UIView *)uikitSuperview
{
	NSView *superview = [self superview];
	return [superview isKindOfClass:[UIView class]] ? (UIView *)superview : nil;
}

- (UIViewTintAdjustmentMode)uikitEffectiveTintAdjustmentMode
{
	for (UIView *view = self; view != nil; view = [view uikitSuperview])
		if (view->_uiTintAdjustmentMode != UIViewTintAdjustmentModeAutomatic)
			return view->_uiTintAdjustmentMode;
	return UIViewTintAdjustmentModeNormal;
}

- (UIColor *)tintColor
{
	/* Dimmed views (behind a presented alert, on iOS) draw their tint in gray. */
	if ([self uikitEffectiveTintAdjustmentMode] == UIViewTintAdjustmentModeDimmed)
		return [UIColor colorWithWhite:0.56 alpha:1];
	for (UIView *view = self; view != nil; view = [view uikitSuperview])
		if (view->_uiTintColor != nil)
			return view->_uiTintColor;
	return [UIColor systemBlueColor];
}

- (void)setTintColor:(UIColor *)color
{
	_uiTintColor = color;
	[self uikitTintChangedInColor:YES adjustment:NO];
}

- (UIViewTintAdjustmentMode)tintAdjustmentMode
{
	return _uiTintAdjustmentMode == UIViewTintAdjustmentModeAutomatic ? [self uikitEffectiveTintAdjustmentMode] : _uiTintAdjustmentMode;
}

- (void)setTintAdjustmentMode:(UIViewTintAdjustmentMode)mode
{
	_uiTintAdjustmentMode = mode;
	[self uikitTintChangedInColor:NO adjustment:YES];
}

- (void)tintColorDidChange
{
}

#pragma mark - Layout direction

/* Darling's text is left to right, so only a forced direction changes it. */
+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute
{
	return [self userInterfaceLayoutDirectionForSemanticContentAttribute:attribute relativeToLayoutDirection:UIUserInterfaceLayoutDirectionLeftToRight];
}

+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute relativeToLayoutDirection:(UIUserInterfaceLayoutDirection)direction
{
	switch (attribute) {
	case UISemanticContentAttributeForceRightToLeft:
		return UIUserInterfaceLayoutDirectionRightToLeft;
	case UISemanticContentAttributeForceLeftToRight:
	case UISemanticContentAttributePlayback:
	case UISemanticContentAttributeSpatial:
		return UIUserInterfaceLayoutDirectionLeftToRight;
	default:
		return direction;
	}
}

- (UISemanticContentAttribute)semanticContentAttribute { return _uiSemanticContentAttribute; }
- (void)setSemanticContentAttribute:(UISemanticContentAttribute)attribute { _uiSemanticContentAttribute = attribute; }

- (UIUserInterfaceLayoutDirection)effectiveUserInterfaceLayoutDirection
{
	return [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:_uiSemanticContentAttribute];
}

/*
 * Tells this view, and the subviews that inherit what changed (the color, the
 * adjustment mode or both), that its tint changed.
 */
- (void)uikitTintChangedInColor:(BOOL)color adjustment:(BOOL)adjustment
{
	[self tintColorDidChange];
	for (NSView *subview in [self subviews]) {
		if (![subview isKindOfClass:[UIView class]])
			continue;
		UIView *child = (UIView *)subview;
		BOOL inheritsColor = color && child->_uiTintColor == nil;
		BOOL inheritsAdjustment = adjustment && child->_uiTintAdjustmentMode == UIViewTintAdjustmentModeAutomatic;
		if (inheritsColor || inheritsAdjustment)
			[child uikitTintChangedInColor:inheritsColor adjustment:inheritsAdjustment];
	}
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	if (!_uiAppearanceApplied && [self window] != nil) {
		_uiAppearanceApplied = YES;
		UIKitApplyAppearance(self);
	}
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

/*
 * iOS 7's top and bottom layout guides, as nibs archive them: hidden views
 * a view controller's view holds, which the controller sizes to the bars
 * covering it. The constraints Interface Builder placed them with are
 * replaced by the controller's own.
 */
@implementation _UILayoutGuide {
	NSString *_identifier;
	NSArray *_constraintsToRemove;
	NSLayoutConstraint *_length;
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	_identifier = [coder decodeObjectForKey:@"_UILayoutGuideIdentifier"];
	_constraintsToRemove = [coder decodeObjectForKey:@"_UILayoutGuideConstraintsToRemove"];
}

- (NSString *)uikitIdentifier { return _identifier; }
- (void)uikitSetIdentifier:(NSString *)identifier { _identifier = [identifier copy]; }
- (CGFloat)length { return _length != nil ? [_length constant] : 0; }

/* Pins the guide to the top or the bottom of the view, length high. */
- (void)uikitPinInView:(UIView *)view length:(CGFloat)length
{
	if (_length != nil) {
		[_length setConstant:length];
		return;
	}
	for (NSLayoutConstraint *constraint in _constraintsToRemove) {
		if ([constraint isKindOfClass:[NSLayoutConstraint class]])
			[constraint setActive:NO];
	}
	for (NSLayoutConstraint *constraint in [self constraints]) {
		if ([constraint isKindOfClass:[_UILayoutSupportConstraint class]])
			[constraint setActive:NO];
	}
	BOOL top = ![_identifier isEqualToString:@"_UIViewControllerBottom"];
	_length = [[self heightAnchor] constraintEqualToConstant:length];
	[NSLayoutConstraint activateConstraints:@[
		top ? [[self topAnchor] constraintEqualToAnchor:[view topAnchor]] : [[self bottomAnchor] constraintEqualToAnchor:[view bottomAnchor]],
		[[self leftAnchor] constraintEqualToAnchor:[view leftAnchor]],
		[[self widthAnchor] constraintEqualToConstant:0],
		_length,
	]];
}

@end

@implementation _UILayoutSupportConstraint
@end
