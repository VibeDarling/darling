/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIGESTURERECOGNIZER_H
#define UIKIT_UIGESTURERECOGNIZER_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIView.h>

@class UIGestureRecognizer, UITouch, UIEvent;

typedef NS_ENUM(NSInteger, UIGestureRecognizerState) {
	UIGestureRecognizerStatePossible,
	UIGestureRecognizerStateBegan,
	UIGestureRecognizerStateChanged,
	UIGestureRecognizerStateEnded,
	UIGestureRecognizerStateCancelled,
	UIGestureRecognizerStateFailed,
	UIGestureRecognizerStateRecognized = UIGestureRecognizerStateEnded,
};

@protocol UIGestureRecognizerDelegate <NSObject>
@optional
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)other;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)other;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch;
@end

@interface UIGestureRecognizer : NSObject
- (instancetype)initWithTarget:(id)target action:(SEL)action;
- (void)addTarget:(id)target action:(SEL)action;
- (void)removeTarget:(id)target action:(SEL)action;
@property (nonatomic, readonly) UIGestureRecognizerState state;
@property (nonatomic, weak) id<UIGestureRecognizerDelegate> delegate;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) UIView *view;
@property (nonatomic) BOOL cancelsTouchesInView;
@property (nonatomic) BOOL delaysTouchesBegan;
@property (nonatomic) BOOL delaysTouchesEnded;
@property (nonatomic, copy) NSString *name;
- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)other;
- (CGPoint)locationInView:(UIView *)view;
- (NSUInteger)numberOfTouches;
- (CGPoint)locationOfTouch:(NSUInteger)index inView:(UIView *)view;
@end

@interface UIView (UIGestureRecognizers)
@property (nonatomic, copy) NSArray<UIGestureRecognizer *> *gestureRecognizers;
- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (void)removeGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
@end

@interface UITapGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@end

@interface UILongPressGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@property (nonatomic) NSTimeInterval minimumPressDuration;
@property (nonatomic) CGFloat allowableMovement;
@end

@interface UIPanGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger minimumNumberOfTouches;
@property (nonatomic) NSUInteger maximumNumberOfTouches;
- (CGPoint)translationInView:(UIView *)view;
- (void)setTranslation:(CGPoint)translation inView:(UIView *)view;
- (CGPoint)velocityInView:(UIView *)view;
@end

typedef NS_OPTIONS(NSUInteger, UIRectEdge) {
	UIRectEdgeNone = 0,
	UIRectEdgeTop = 1 << 0,
	UIRectEdgeLeft = 1 << 1,
	UIRectEdgeBottom = 1 << 2,
	UIRectEdgeRight = 1 << 3,
	UIRectEdgeAll = 0xf,
};

@interface UIScreenEdgePanGestureRecognizer : UIPanGestureRecognizer
@property (nonatomic) UIRectEdge edges;
@end

typedef NS_OPTIONS(NSUInteger, UISwipeGestureRecognizerDirection) {
	UISwipeGestureRecognizerDirectionRight = 1 << 0,
	UISwipeGestureRecognizerDirectionLeft = 1 << 1,
	UISwipeGestureRecognizerDirectionUp = 1 << 2,
	UISwipeGestureRecognizerDirectionDown = 1 << 3,
};

@interface UISwipeGestureRecognizer : UIGestureRecognizer
@property (nonatomic) UISwipeGestureRecognizerDirection direction;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@end

/* Two-finger gestures: a pointer is one finger, so these never begin. */
@interface UIPinchGestureRecognizer : UIGestureRecognizer
@property (nonatomic) CGFloat scale;
@property (nonatomic, readonly) CGFloat velocity;
@end

@interface UIRotationGestureRecognizer : UIGestureRecognizer
@property (nonatomic) CGFloat rotation;
@property (nonatomic, readonly) CGFloat velocity;
@end

#endif /* UIKIT_UIGESTURERECOGNIZER_H */
