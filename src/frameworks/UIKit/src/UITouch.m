/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UITouch.h>
#import <UIKit/UIEvent.h>
#import <UIKit/UIView.h>
#import <UIKit/UIWindow.h>
#import <AppKit/NSEvent.h>
#import <Foundation/NSProcessInfo.h>
#include <math.h>

#import "UIKitPrivate.h"

@implementation UITouch {
	/* In the host window's base coordinates, as AppKit reports them. */
	NSPoint _location;
	NSPoint _previousLocation;
	NSPoint _startLocation;
}

- (void)updateWithEvent:(NSEvent *)event phase:(UITouchPhase)phase
{
	if (phase == UITouchPhaseBegan)
		_tapCount = [event clickCount];
	[self uikitMoveTo:[event locationInWindow] timestamp:[event timestamp] phase:phase];
}

- (void)uikitMoveTo:(NSPoint)location timestamp:(NSTimeInterval)timestamp phase:(UITouchPhase)phase
{
	_previousLocation = phase == UITouchPhaseBegan ? location : _location;
	_location = location;
	if (phase == UITouchPhaseBegan)
		_startLocation = location;
	_phase = phase;
	_timestamp = timestamp > 0 ? timestamp : [[NSProcessInfo processInfo] systemUptime];
}

- (CGPoint)convertLocation:(NSPoint)location toView:(UIView *)view
{
	UIView *target = view ?: (UIView *)_window;
	NSPoint point = target != nil ? [target convertPoint:location fromView:nil] : location;
	return CGPointMake(point.x, point.y);
}

- (CGPoint)locationInView:(UIView *)view { return [self convertLocation:_location toView:view]; }
- (CGPoint)previousLocationInView:(UIView *)view { return [self convertLocation:_previousLocation toView:view]; }
- (CGPoint)preciseLocationInView:(UIView *)view { return [self locationInView:view]; }
- (CGPoint)precisePreviousLocationInView:(UIView *)view { return [self previousLocationInView:view]; }
- (CGPoint)uikitStartLocationInView:(UIView *)view { return [self convertLocation:_startLocation toView:view]; }

- (UITouchType)type { return UITouchTypeDirect; }
- (CGFloat)majorRadius { return 20; }
- (CGFloat)majorRadiusTolerance { return 5; }
- (CGFloat)force { return 0; }
- (CGFloat)maximumPossibleForce { return 0; }
- (CGFloat)altitudeAngle { return M_PI_2; }
- (NSArray *)gestureRecognizers { return [_uikitRecognizers copy] ?: @[]; }

- (NSString *)description
{
	return [NSString stringWithFormat:@"<UITouch: %p; phase = %ld; tap count = %lu; view = <%@ %p>; location = %@>", self,
		(long)_phase, (unsigned long)_tapCount, [_view class], _view, NSStringFromPoint(_location)];
}

@end

@implementation UIEvent {
	NSMutableSet<UITouch *> *_touches;
}

+ (UIEvent *)uikitTouchesEvent
{
	static UIEvent *event;
	if (event == nil)
		event = [[UIEvent alloc] init];
	return event;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_touches = [NSMutableSet set];
		_type = UIEventTypeTouches;
	}
	return self;
}

- (void)uikitAddTouch:(UITouch *)touch { [_touches addObject:touch]; }
- (void)uikitRemoveTouch:(UITouch *)touch { [_touches removeObject:touch]; }
- (void)uikitSetTimestamp:(NSTimeInterval)timestamp { _timestamp = timestamp; }

- (NSSet<UITouch *> *)allTouches
{
	return [_touches copy];
}

- (NSSet<UITouch *> *)touchesForView:(UIView *)view
{
	NSMutableSet *result = [NSMutableSet set];
	for (UITouch *touch in _touches)
		if ([[touch view] isDescendantOf:view])
			[result addObject:touch];
	return result;
}

- (NSSet<UITouch *> *)touchesForWindow:(UIWindow *)window
{
	NSMutableSet *result = [NSMutableSet set];
	for (UITouch *touch in _touches)
		if ([touch window] == window)
			[result addObject:touch];
	return result;
}

- (NSSet<UITouch *> *)touchesForGestureRecognizer:(UIGestureRecognizer *)gesture
{
	NSMutableSet *result = [NSMutableSet set];
	for (UITouch *touch in _touches)
		if ([[touch uikitRecognizers] containsObject:gesture])
			[result addObject:touch];
	return result;
}

- (NSArray<UITouch *> *)coalescedTouchesForTouch:(UITouch *)touch { return touch != nil ? @[touch] : @[]; }
- (NSArray<UITouch *> *)predictedTouchesForTouch:(UITouch *)touch { return @[]; }

@end
