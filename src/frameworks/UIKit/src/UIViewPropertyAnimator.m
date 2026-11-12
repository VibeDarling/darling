/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIViewPropertyAnimator.h>

@implementation UICubicTimingParameters {
	UIViewAnimationCurve _curve;
	CGPoint _point1, _point2;
}

- (instancetype)init
{
	return [self initWithAnimationCurve:UIViewAnimationCurveEaseInOut];
}

- (instancetype)initWithAnimationCurve:(UIViewAnimationCurve)curve
{
	if ((self = [super init])) {
		_curve = curve;
		switch (curve) {
		case UIViewAnimationCurveEaseIn: _point1 = CGPointMake(0.42, 0); _point2 = CGPointMake(1, 1); break;
		case UIViewAnimationCurveEaseOut: _point1 = CGPointMake(0, 0); _point2 = CGPointMake(0.58, 1); break;
		case UIViewAnimationCurveLinear: _point1 = CGPointMake(0, 0); _point2 = CGPointMake(1, 1); break;
		default: _point1 = CGPointMake(0.42, 0); _point2 = CGPointMake(0.58, 1); break;
		}
	}
	return self;
}

- (instancetype)initWithControlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2
{
	if ((self = [super init])) {
		_curve = UIViewAnimationCurveEaseInOut;
		_point1 = point1;
		_point2 = point2;
	}
	return self;
}

- (UITimingCurveType)timingCurveType { return UITimingCurveTypeCubic; }
- (UIViewAnimationCurve)animationCurve { return _curve; }
- (CGPoint)controlPoint1 { return _point1; }
- (CGPoint)controlPoint2 { return _point2; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (void)encodeWithCoder:(NSCoder *)coder { }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }

@end

@implementation UISpringTimingParameters {
	CGVector _velocity;
}

- (instancetype)init { return [self initWithDampingRatio:1]; }
- (instancetype)initWithDampingRatio:(CGFloat)ratio { return [self initWithDampingRatio:ratio initialVelocity:CGVectorMake(0, 0)]; }

- (instancetype)initWithDampingRatio:(CGFloat)ratio initialVelocity:(CGVector)velocity
{
	if ((self = [super init]))
		_velocity = velocity;
	return self;
}

- (instancetype)initWithMass:(CGFloat)mass stiffness:(CGFloat)stiffness damping:(CGFloat)damping initialVelocity:(CGVector)velocity
{
	return [self initWithDampingRatio:1 initialVelocity:velocity];
}

- (UITimingCurveType)timingCurveType { return UITimingCurveTypeSpring; }
- (CGVector)initialVelocity { return _velocity; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (void)encodeWithCoder:(NSCoder *)coder { }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }

@end

@implementation UIViewPropertyAnimator {
	NSTimeInterval _duration;
	NSTimeInterval _delay;
	id<UITimingCurveProvider> _timingParameters;
	NSMutableArray *_animations;
	NSMutableArray *_completions;
	UIViewAnimatingState _state;
	BOOL _running;
	BOOL _reversed;
	CGFloat _fraction;
	/* Which start the pending finish belongs to: a pause or stop makes
	   an older one stale. */
	NSUInteger _generation;
	/* When it last started running, and how far it had got then. */
	NSDate *_runningSince;
	CGFloat _fractionThen;
}

@synthesize userInteractionEnabled = _userInteractionEnabled;
@synthesize manualHitTestingEnabled = _manualHitTestingEnabled;
@synthesize interruptible = _interruptible;
@synthesize scrubsLinearly = _scrubsLinearly;
@synthesize pausesOnCompletion = _pausesOnCompletion;

- (instancetype)initWithDuration:(NSTimeInterval)duration timingParameters:(id<UITimingCurveProvider>)parameters
{
	if ((self = [super init])) {
		_duration = MAX(duration, 0);
		_timingParameters = parameters ?: [[UICubicTimingParameters alloc] init];
		_animations = [NSMutableArray array];
		_completions = [NSMutableArray array];
		_userInteractionEnabled = YES;
		_interruptible = YES;
		_scrubsLinearly = YES;
	}
	return self;
}

- (instancetype)initWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve animations:(void (^)(void))animations
{
	if ((self = [self initWithDuration:duration timingParameters:[[UICubicTimingParameters alloc] initWithAnimationCurve:curve]]))
		[self addAnimations:animations];
	return self;
}

- (instancetype)initWithDuration:(NSTimeInterval)duration controlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2 animations:(void (^)(void))animations
{
	if ((self = [self initWithDuration:duration timingParameters:[[UICubicTimingParameters alloc] initWithControlPoint1:point1 controlPoint2:point2]]))
		[self addAnimations:animations];
	return self;
}

- (instancetype)initWithDuration:(NSTimeInterval)duration dampingRatio:(CGFloat)ratio animations:(void (^)(void))animations
{
	if ((self = [self initWithDuration:duration timingParameters:[[UISpringTimingParameters alloc] initWithDampingRatio:ratio]]))
		[self addAnimations:animations];
	return self;
}

+ (instancetype)runningPropertyAnimatorWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(UIViewAnimatingPosition finalPosition))completion
{
	UIViewPropertyAnimator *animator = [[self alloc] initWithDuration:duration curve:UIViewAnimationCurveEaseInOut animations:animations];
	[animator addCompletion:completion];
	[animator startAnimationAfterDelay:delay];
	return animator;
}

- (id)copyWithZone:(NSZone *)zone
{
	UIViewPropertyAnimator *copy = [[[self class] alloc] initWithDuration:_duration timingParameters:_timingParameters];
	[copy->_animations setArray:_animations];
	[copy->_completions setArray:_completions];
	return copy;
}

- (id<UITimingCurveProvider>)timingParameters { return _timingParameters; }
- (NSTimeInterval)duration { return _duration; }
- (NSTimeInterval)delay { return _delay; }
- (UIViewAnimatingState)state { return _state; }
- (BOOL)isRunning { return _running; }
- (BOOL)isReversed { return _reversed; }
- (void)setReversed:(BOOL)reversed { _reversed = reversed; }
- (CGFloat)fractionComplete { return _fraction; }

- (void)setFractionComplete:(CGFloat)fraction
{
	[self uikitActivate];
	_fraction = MIN(MAX(fraction, 0), 1);
}

- (void)addAnimations:(void (^)(void))animation
{
	if (animation == nil)
		return;
	/* Added while running, it takes effect at once, as it would join in. */
	if (_state == UIViewAnimatingStateActive)
		animation();
	else
		[_animations addObject:[animation copy]];
}

- (void)addAnimations:(void (^)(void))animation delayFactor:(CGFloat)delayFactor
{
	[self addAnimations:animation];
}

- (void)addCompletion:(void (^)(UIViewAnimatingPosition finalPosition))completion
{
	if (completion != nil)
		[_completions addObject:[completion copy]];
}

/* Active: the changes are made, once. */
- (void)uikitActivate
{
	if (_state != UIViewAnimatingStateInactive)
		return;
	_state = UIViewAnimatingStateActive;
	NSArray *animations = [_animations copy];
	[_animations removeAllObjects];
	for (void (^animation)(void) in animations)
		animation();
}

- (void)uikitScheduleFinishAfter:(NSTimeInterval)seconds
{
	NSUInteger generation = ++_generation;
	_runningSince = [NSDate date];
	_fractionThen = _fraction;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (self->_generation == generation && self->_running)
			[self uikitReachEnd];
	});
}

- (void)uikitReachEnd
{
	_fraction = 1;
	if (_pausesOnCompletion) {
		_running = NO;
		return;
	}
	[self finishAnimationAtPosition:_reversed ? UIViewAnimatingPositionStart : UIViewAnimatingPositionEnd];
}

- (void)startAnimation
{
	[self startAnimationAfterDelay:0];
}

- (void)startAnimationAfterDelay:(NSTimeInterval)delay
{
	if (_state == UIViewAnimatingStateStopped)
		[NSException raise:NSInternalInconsistencyException format:@"It is an error to call -startAnimation on a stopped property animator"];
	if (_running)
		return;
	_delay = delay;
	dispatch_block_t start = ^{
		[self uikitActivate];
		self->_running = YES;
		[self uikitScheduleFinishAfter:self->_duration * (1 - self->_fraction)];
	};
	if (delay > 0)
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), start);
	else
		start();
}

- (void)pauseAnimation
{
	if (_state == UIViewAnimatingStateStopped)
		[NSException raise:NSInternalInconsistencyException format:@"It is an error to call -pauseAnimation on a stopped property animator"];
	[self uikitActivate];
	if (_running && _duration > 0)
		_fraction = MIN(_fractionThen + -[_runningSince timeIntervalSinceNow] / _duration, 1);
	_running = NO;
	_generation++;
}

- (void)stopAnimation:(BOOL)withoutFinishing
{
	if (_state != UIViewAnimatingStateActive)
		return;
	_running = NO;
	_generation++;
	if (withoutFinishing) {
		_state = UIViewAnimatingStateInactive;
		[_completions removeAllObjects];
	} else {
		_state = UIViewAnimatingStateStopped;
	}
}

- (void)finishAnimationAtPosition:(UIViewAnimatingPosition)position
{
	_running = NO;
	_generation++;
	_state = UIViewAnimatingStateInactive;
	NSArray *completions = [_completions copy];
	[_completions removeAllObjects];
	for (void (^completion)(UIViewAnimatingPosition) in completions)
		completion(position);
}

- (void)continueAnimationWithTimingParameters:(id<UITimingCurveProvider>)parameters durationFactor:(CGFloat)durationFactor
{
	if (parameters != nil)
		_timingParameters = parameters;
	if (durationFactor > 0)
		_duration *= durationFactor;
	[self startAnimation];
}

@end
