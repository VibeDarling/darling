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

#import "UIKitPrivate.h"

@implementation UITouch {
	/* In the host window's base coordinates, as AppKit reports them. */
	NSPoint _location;
	NSPoint _previousLocation;
}

- (void)updateWithEvent:(NSEvent *)event phase:(UITouchPhase)phase
{
	NSPoint location = [event locationInWindow];
	_previousLocation = phase == UITouchPhaseBegan ? location : _location;
	_location = location;
	_phase = phase;
	/* Cocotron leaves event timestamps at zero. */
	_timestamp = [event timestamp] > 0 ? [event timestamp] : [[NSProcessInfo processInfo] systemUptime];
	if (phase == UITouchPhaseBegan)
		_tapCount = [event clickCount];
}

- (CGPoint)convertLocation:(NSPoint)location toView:(UIView *)view
{
	UIView *target = view ?: (UIView *)_window;
	NSPoint point = target != nil ? [target convertPoint:location fromView:nil] : location;
	return CGPointMake(point.x, point.y);
}

- (CGPoint)locationInView:(UIView *)view
{
	return [self convertLocation:_location toView:view];
}

- (CGPoint)previousLocationInView:(UIView *)view
{
	return [self convertLocation:_previousLocation toView:view];
}

@end

@implementation UIEvent {
	UITouch *_touch;
}

- (instancetype)initWithTouch:(UITouch *)touch
{
	if ((self = [super init])) {
		_touch = touch;
		_type = UIEventTypeTouches;
		_timestamp = [touch timestamp];
	}
	return self;
}

- (NSSet<UITouch *> *)allTouches
{
	return _touch != nil ? [NSSet setWithObject:_touch] : [NSSet set];
}

- (NSSet<UITouch *> *)touchesForView:(UIView *)view
{
	return [_touch view] == view ? [self allTouches] : [NSSet set];
}

@end
