/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIEVENT_H
#define UIKIT_UIEVENT_H

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSSet.h>

@class UITouch, UIView;

typedef NS_ENUM(NSInteger, UIEventType) {
	UIEventTypeTouches,
	UIEventTypeMotion,
	UIEventTypeRemoteControl,
	UIEventTypePresses
};

typedef NS_ENUM(NSInteger, UIEventSubtype) {
	UIEventSubtypeNone = 0,
	UIEventSubtypeMotionShake = 1
};

@class UIWindow, UIGestureRecognizer;

/* The touches event: every finger down, the unchanged ones stationary. */
@interface UIEvent : NSObject

@property (nonatomic, readonly) UIEventType type;
@property (nonatomic, readonly) UIEventSubtype subtype;
@property (nonatomic, readonly) NSTimeInterval timestamp;

- (NSSet<UITouch *> *)allTouches;
- (NSSet<UITouch *> *)touchesForView:(UIView *)view;
- (NSSet<UITouch *> *)touchesForWindow:(UIWindow *)window;
- (NSSet<UITouch *> *)touchesForGestureRecognizer:(UIGestureRecognizer *)gesture;
- (NSArray<UITouch *> *)coalescedTouchesForTouch:(UITouch *)touch;
- (NSArray<UITouch *> *)predictedTouchesForTouch:(UITouch *)touch;

@end

#endif /* UIKIT_UIEVENT_H */
