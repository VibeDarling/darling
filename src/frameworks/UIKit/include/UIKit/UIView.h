/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIVIEW_H
#define UIKIT_UIVIEW_H

#import <AppKit/NSView.h>
#import <CoreGraphics/CGGeometry.h>

@class UIColor, UIWindow, UIEvent, UITouch;
#import <Foundation/NSSet.h>
#import <CoreGraphics/CGAffineTransform.h>

typedef NS_ENUM(NSInteger, UIViewContentMode) {
	UIViewContentModeScaleToFill,
	UIViewContentModeScaleAspectFit,
	UIViewContentModeScaleAspectFill,
	UIViewContentModeRedraw,
	UIViewContentModeCenter,
	UIViewContentModeTop,
	UIViewContentModeBottom,
	UIViewContentModeLeft,
	UIViewContentModeRight,
	UIViewContentModeTopLeft,
	UIViewContentModeTopRight,
	UIViewContentModeBottomLeft,
	UIViewContentModeBottomRight,
};

typedef NS_ENUM(NSInteger, UIViewAnimationCurve) {
	UIViewAnimationCurveEaseInOut,
	UIViewAnimationCurveEaseIn,
	UIViewAnimationCurveEaseOut,
	UIViewAnimationCurveLinear,
};

typedef NS_ENUM(NSInteger, UIViewTintAdjustmentMode) {
	UIViewTintAdjustmentModeAutomatic,
	UIViewTintAdjustmentModeNormal,
	UIViewTintAdjustmentModeDimmed,
};

typedef NS_OPTIONS(NSUInteger, UIViewAnimationOptions) {
	UIViewAnimationOptionNone = 0,
	UIViewAnimationOptionLayoutSubviews = 1 << 0,
	UIViewAnimationOptionAllowUserInteraction = 1 << 1,
	UIViewAnimationOptionBeginFromCurrentState = 1 << 2,
	UIViewAnimationOptionRepeat = 1 << 3,
	UIViewAnimationOptionAutoreverse = 1 << 4,
	UIViewAnimationOptionOverrideInheritedDuration = 1 << 5,
	UIViewAnimationOptionOverrideInheritedCurve = 1 << 6,
	UIViewAnimationOptionAllowAnimatedContent = 1 << 7,
	UIViewAnimationOptionShowHideTransitionViews = 1 << 8,
	UIViewAnimationOptionOverrideInheritedOptions = 1 << 9,
	UIViewAnimationOptionCurveEaseInOut = 0 << 16,
	UIViewAnimationOptionCurveEaseIn = 1 << 16,
	UIViewAnimationOptionCurveEaseOut = 2 << 16,
	UIViewAnimationOptionCurveLinear = 3 << 16,
	UIViewAnimationOptionTransitionNone = 0 << 20,
	UIViewAnimationOptionTransitionFlipFromLeft = 1 << 20,
	UIViewAnimationOptionTransitionFlipFromRight = 2 << 20,
	UIViewAnimationOptionTransitionCurlUp = 3 << 20,
	UIViewAnimationOptionTransitionCurlDown = 4 << 20,
	UIViewAnimationOptionTransitionCrossDissolve = 5 << 20,
	UIViewAnimationOptionTransitionFlipFromTop = 6 << 20,
	UIViewAnimationOptionTransitionFlipFromBottom = 7 << 20,
	UIViewAnimationOptionPreferredFramesPerSecondDefault = 0 << 24,
	UIViewAnimationOptionPreferredFramesPerSecond60 = 3 << 24,
	UIViewAnimationOptionPreferredFramesPerSecond30 = 7 << 24,
};

typedef NS_OPTIONS(NSUInteger, UIViewKeyframeAnimationOptions) {
	UIViewKeyframeAnimationOptionLayoutSubviews = UIViewAnimationOptionLayoutSubviews,
	UIViewKeyframeAnimationOptionAllowUserInteraction = UIViewAnimationOptionAllowUserInteraction,
	UIViewKeyframeAnimationOptionBeginFromCurrentState = UIViewAnimationOptionBeginFromCurrentState,
	UIViewKeyframeAnimationOptionRepeat = UIViewAnimationOptionRepeat,
	UIViewKeyframeAnimationOptionAutoreverse = UIViewAnimationOptionAutoreverse,
	UIViewKeyframeAnimationOptionOverrideInheritedDuration = UIViewAnimationOptionOverrideInheritedDuration,
	UIViewKeyframeAnimationOptionOverrideInheritedOptions = UIViewAnimationOptionOverrideInheritedOptions,
	UIViewKeyframeAnimationOptionCalculationModeLinear = 0 << 10,
	UIViewKeyframeAnimationOptionCalculationModeDiscrete = 1 << 10,
	UIViewKeyframeAnimationOptionCalculationModePaced = 2 << 10,
	UIViewKeyframeAnimationOptionCalculationModeCubic = 3 << 10,
	UIViewKeyframeAnimationOptionCalculationModeCubicPaced = 4 << 10,
};

/*
 * The values are UIKit's.  They equal AppKit's NSAutoresizingMaskOptions bit for
 * bit, and because every UIView is flipped, AppKit's "min Y" margin is the top
 * one, as UIKit's FlexibleTopMargin is.  NSView's -autoresizingMask therefore
 * serves both.
 */
typedef NS_OPTIONS(NSUInteger, UIViewAutoresizing) {
	UIViewAutoresizingNone                 = 0,
	UIViewAutoresizingFlexibleLeftMargin   = 1 << 0,
	UIViewAutoresizingFlexibleWidth        = 1 << 1,
	UIViewAutoresizingFlexibleRightMargin  = 1 << 2,
	UIViewAutoresizingFlexibleTopMargin    = 1 << 3,
	UIViewAutoresizingFlexibleHeight       = 1 << 4,
	UIViewAutoresizingFlexibleBottomMargin = 1 << 5
};

/*
 * UIView is an AppKit view: Darling has no separate compositor, so the UIKit
 * tree *is* the window's content view tree.  Its coordinate system is flipped
 * to match UIKit (origin top-left).
 *
 * Deviation from iOS: NSView already declares -window (NSWindow *) and its own
 * ivars, so the UIKit hosting window is exposed internally as -uiWindow rather
 * than shadowing -window with an incompatible type.
 */
typedef NS_ENUM(NSInteger, UIUserInterfaceLayoutDirection) {
	UIUserInterfaceLayoutDirectionLeftToRight,
	UIUserInterfaceLayoutDirectionRightToLeft,
};

typedef NS_ENUM(NSInteger, UISemanticContentAttribute) {
	UISemanticContentAttributeUnspecified,
	UISemanticContentAttributePlayback,
	UISemanticContentAttributeSpatial,
	UISemanticContentAttributeForceLeftToRight,
	UISemanticContentAttributeForceRightToLeft,
};

@interface UIView : NSView {
@package
	UIColor *_uiBackgroundColor;
	UIWindow *_uiWindow;
	BOOL _uiNeedsLayout;
	BOOL _uiUserInteractionDisabled;
	BOOL _uiLayoutScheduled;
	BOOL _uiClipsToBounds;
	BOOL _uiOpaque;
	BOOL _uiNeedsDisplayOnBoundsChange;
	BOOL _uiExclusiveTouch;
	BOOL _uiMultipleTouchEnabled;
	NSInteger _uiTag;
	UIViewContentMode _uiContentMode;
	CGAffineTransform _uiTransform;
}

- (instancetype)initWithFrame:(CGRect)frame;

@property (nonatomic, strong) UIColor *backgroundColor;

- (void)layoutSubviews;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;

/*
 * Touches come from the pointer (see UITouch.h).  The view under the pointer
 * gets them; by default a view passes them on to its superview, which is
 * UIKit's responder chain for views.
 */
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;

/*
 * The rest of UIView's geometry and hierarchy API that NSView does not
 * already provide under the same selector.  Animations are not animated:
 * the changes made inside an animation block take effect at once and the
 * completion runs afterwards.
 */
@property (nonatomic) CGFloat alpha;
@property (nonatomic) NSInteger tag;
@property (nonatomic) CGPoint center;
@property (nonatomic) BOOL clipsToBounds;
/* Private iOS names for frame.origin and clipsToBounds. */
@property (nonatomic) CGPoint origin;
@property (nonatomic) BOOL clipsSubviews;
@property (nonatomic, getter=isOpaque) BOOL opaque;
@property (nonatomic) UIViewContentMode contentMode;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic, getter=isExclusiveTouch) BOOL exclusiveTouch;
@property (nonatomic, getter=isMultipleTouchEnabled) BOOL multipleTouchEnabled;
@property (nonatomic) BOOL needsDisplayOnBoundsChange;
@property (nonatomic) CGFloat contentScaleFactor;

/*
 * A view without its own tint color has its superview's, and the root has the
 * system blue.  tintColorDidChange is sent to every view whose tint changes.
 */
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic) UIViewTintAdjustmentMode tintAdjustmentMode;
- (void)tintColorDidChange;
@property (nonatomic) UISemanticContentAttribute semanticContentAttribute;
@property (nonatomic, readonly) UIUserInterfaceLayoutDirection effectiveUserInterfaceLayoutDirection;
+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute;
+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute relativeToLayoutDirection:(UIUserInterfaceLayoutDirection)direction;

- (void)setNeedsDisplay;
- (CGSize)sizeThatFits:(CGSize)size;
- (void)sizeToFit;
- (UIView *)viewWithTag:(NSInteger)tag;
- (void)bringSubviewToFront:(UIView *)view;
- (void)sendSubviewToBack:(UIView *)view;
- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index;
- (void)insertSubview:(UIView *)view belowSubview:(UIView *)sibling;
- (void)insertSubview:(UIView *)view aboveSubview:(UIView *)sibling;
- (BOOL)endEditing:(BOOL)force;
- (BOOL)isDescendantOfView:(UIView *)view;

/* Called as on iOS when the view moves (from NSView's own notifications). */
- (void)willMoveToSuperview:(UIView *)superview;
- (void)didMoveToSuperview;
- (void)willMoveToWindow:(UIWindow *)window;
- (void)didMoveToWindow;
- (void)didAddSubview:(UIView *)subview;
- (void)willRemoveSubview:(UIView *)subview;

+ (void)beginAnimations:(NSString *)animationID context:(void *)context;
+ (void)commitAnimations;
+ (void)setAnimationDelegate:(id)delegate;
+ (void)setAnimationDidStopSelector:(SEL)selector;
+ (void)setAnimationWillStartSelector:(SEL)selector;
+ (void)setAnimationDuration:(NSTimeInterval)duration;
+ (void)setAnimationDelay:(NSTimeInterval)delay;
+ (void)setAnimationCurve:(UIViewAnimationCurve)curve;
+ (void)setAnimationBeginsFromCurrentState:(BOOL)fromCurrentState;
+ (void)setAnimationRepeatCount:(float)repeatCount;
+ (void)setAnimationTransition:(NSInteger)transition forView:(UIView *)view cache:(BOOL)cache;
+ (void)setAnimationsEnabled:(BOOL)enabled;
+ (BOOL)areAnimationsEnabled;
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations;
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)performWithoutAnimation:(void (^)(void))actions;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)transitionWithView:(UIView *)view duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)transitionFromView:(UIView *)fromView toView:(UIView *)toView duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options completion:(void (^)(BOOL finished))completion;
+ (void)animateKeyframesWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewKeyframeAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)addKeyframeWithRelativeStartTime:(double)frameStartTime relativeDuration:(double)frameDuration animations:(void (^)(void))animations;
+ (void)modifyAnimationsWithRepeatCount:(CGFloat)count autoreverses:(BOOL)autoreverses animations:(void (^)(void))animations;
+ (NSTimeInterval)inheritedAnimationDuration;

@end

/* iOS's first responder, on top of AppKit's: -becomeFirstResponder and
 * -resignFirstResponder called by the app make the view the window's first
 * responder, or give that up, when -canBecomeFirstResponder allows it (NO by
 * default, as on iOS). See UITextInput.h for views that take typing. */
@interface UIView (UIKitFirstResponder)
- (BOOL)canBecomeFirstResponder;
- (BOOL)isFirstResponder;
@end

#endif /* UIKIT_UIVIEW_H */
