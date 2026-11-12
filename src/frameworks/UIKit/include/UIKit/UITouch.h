/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UITOUCH_H
#define UIKIT_UITOUCH_H

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#import <CoreGraphics/CGGeometry.h>

@class UIView, UIWindow;

typedef NS_ENUM(NSInteger, UITouchPhase) {
	UITouchPhaseBegan,
	UITouchPhaseMoved,
	UITouchPhaseStationary,
	UITouchPhaseEnded,
	UITouchPhaseCancelled
};

typedef NS_ENUM(NSInteger, UITouchType) {
	UITouchTypeDirect,
	UITouchTypeIndirect,
	UITouchTypePencil,
	UITouchTypeIndirectPointer
};

/*
 * A finger on the touch screen, or the primary mouse button, which is one
 * finger. Touch screens come from the windowing backend through AppKit's
 * direct touches (see AppKit's NSTouch.h).
 */
@interface UITouch : NSObject

@property (nonatomic, readonly) UITouchPhase phase;
@property (nonatomic, readonly) NSUInteger tapCount;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) UITouchType type;
@property (nonatomic, readonly, strong) UIView *view;
@property (nonatomic, readonly, strong) UIWindow *window;
@property (nonatomic, readonly, copy) NSArray *gestureRecognizers;
/* No pressure or contact size is reported: these are a finger's typical values. */
@property (nonatomic, readonly) CGFloat majorRadius;
@property (nonatomic, readonly) CGFloat majorRadiusTolerance;
@property (nonatomic, readonly) CGFloat force;
@property (nonatomic, readonly) CGFloat maximumPossibleForce;
@property (nonatomic, readonly) CGFloat altitudeAngle;

- (CGPoint)locationInView:(UIView *)view;
- (CGPoint)previousLocationInView:(UIView *)view;
- (CGPoint)preciseLocationInView:(UIView *)view;
- (CGPoint)precisePreviousLocationInView:(UIView *)view;

@end

#endif /* UIKIT_UITOUCH_H */
