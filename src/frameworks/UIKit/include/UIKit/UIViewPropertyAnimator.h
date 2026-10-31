/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIVIEWPROPERTYANIMATOR_H
#define UIKIT_UIVIEWPROPERTYANIMATOR_H

#import <UIKit/UIView.h>
#import <UIKit/UIGeometry.h>

typedef NS_ENUM(NSInteger, UIViewAnimatingState) {
	UIViewAnimatingStateInactive,
	UIViewAnimatingStateActive,
	UIViewAnimatingStateStopped,
};

typedef NS_ENUM(NSInteger, UIViewAnimatingPosition) {
	UIViewAnimatingPositionEnd,
	UIViewAnimatingPositionStart,
	UIViewAnimatingPositionCurrent,
};

typedef NS_ENUM(NSInteger, UITimingCurveType) {
	UITimingCurveTypeBuiltin,
	UITimingCurveTypeCubic,
	UITimingCurveTypeSpring,
	UITimingCurveTypeComposed,
};

@protocol UITimingCurveProvider <NSCoding, NSCopying>
@property (nonatomic, readonly) UITimingCurveType timingCurveType;
@end

@interface UICubicTimingParameters : NSObject <UITimingCurveProvider>
- (instancetype)initWithAnimationCurve:(UIViewAnimationCurve)curve;
- (instancetype)initWithControlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2;
@property (nonatomic, readonly) UIViewAnimationCurve animationCurve;
@property (nonatomic, readonly) CGPoint controlPoint1;
@property (nonatomic, readonly) CGPoint controlPoint2;
@end

@interface UISpringTimingParameters : NSObject <UITimingCurveProvider>
- (instancetype)initWithDampingRatio:(CGFloat)ratio;
- (instancetype)initWithDampingRatio:(CGFloat)ratio initialVelocity:(CGVector)velocity;
- (instancetype)initWithMass:(CGFloat)mass stiffness:(CGFloat)stiffness damping:(CGFloat)damping initialVelocity:(CGVector)velocity;
@property (nonatomic, readonly) CGVector initialVelocity;
@end

@protocol UIViewAnimating <NSObject>
@property (nonatomic, readonly) UIViewAnimatingState state;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, getter=isReversed) BOOL reversed;
@property (nonatomic) CGFloat fractionComplete;
- (void)startAnimation;
- (void)startAnimationAfterDelay:(NSTimeInterval)delay;
- (void)pauseAnimation;
- (void)stopAnimation:(BOOL)withoutFinishing;
- (void)finishAnimationAtPosition:(UIViewAnimatingPosition)finalPosition;
@end

@protocol UIViewImplicitlyAnimating <UIViewAnimating>
@optional
- (void)addAnimations:(void (^)(void))animation;
- (void)addAnimations:(void (^)(void))animation delayFactor:(CGFloat)delayFactor;
- (void)addCompletion:(void (^)(UIViewAnimatingPosition finalPosition))completion;
- (void)continueAnimationWithTimingParameters:(id<UITimingCurveProvider>)parameters durationFactor:(CGFloat)durationFactor;
@end

/*
 * As UIView's animation blocks (see UIView.h): the changes take effect
 * when the animator starts, and it finishes, with its completions, once
 * its duration has passed. Pausing stops that clock; scrubbing
 * fractionComplete changes nothing on screen.
 */
@interface UIViewPropertyAnimator : NSObject <UIViewImplicitlyAnimating, NSCopying>
- (instancetype)initWithDuration:(NSTimeInterval)duration timingParameters:(id<UITimingCurveProvider>)parameters;
- (instancetype)initWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve animations:(void (^)(void))animations;
- (instancetype)initWithDuration:(NSTimeInterval)duration controlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2 animations:(void (^)(void))animations;
- (instancetype)initWithDuration:(NSTimeInterval)duration dampingRatio:(CGFloat)ratio animations:(void (^)(void))animations;
+ (instancetype)runningPropertyAnimatorWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(UIViewAnimatingPosition finalPosition))completion;
@property (nonatomic, readonly, copy) id<UITimingCurveProvider> timingParameters;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval delay;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic, getter=isManualHitTestingEnabled) BOOL manualHitTestingEnabled;
@property (nonatomic, getter=isInterruptible) BOOL interruptible;
@property (nonatomic) BOOL scrubsLinearly;
@property (nonatomic) BOOL pausesOnCompletion;
@end

#endif /* UIKIT_UIVIEWPROPERTYANIMATOR_H */
