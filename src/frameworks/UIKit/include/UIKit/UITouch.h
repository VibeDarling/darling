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

/*
 * Darling's displays have a pointer, not a touch screen: the primary mouse
 * button is the one finger, so there is never more than one touch.
 */
@interface UITouch : NSObject

@property (nonatomic, readonly) UITouchPhase phase;
@property (nonatomic, readonly) NSUInteger tapCount;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly, strong) UIView *view;
@property (nonatomic, readonly, strong) UIWindow *window;

- (CGPoint)locationInView:(UIView *)view;
- (CGPoint)previousLocationInView:(UIView *)view;

@end

#endif /* UIKIT_UITOUCH_H */
