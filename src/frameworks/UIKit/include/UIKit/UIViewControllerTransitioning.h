/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIVIEWCONTROLLERTRANSITIONING_H
#define UIKIT_UIVIEWCONTROLLERTRANSITIONING_H

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIView.h>

@class UIView;

extern NSString *const UITransitionContextFromViewControllerKey;
extern NSString *const UITransitionContextToViewControllerKey;
extern NSString *const UITransitionContextFromViewKey;
extern NSString *const UITransitionContextToViewKey;

@protocol UIViewControllerContextTransitioning <NSObject>
@property (nonatomic, readonly) UIView *containerView;
@property (nonatomic, readonly, getter=isAnimated) BOOL animated;
@property (nonatomic, readonly, getter=isInteractive) BOOL interactive;
@property (nonatomic, readonly) BOOL transitionWasCancelled;
- (void)updateInteractiveTransition:(CGFloat)percentComplete;
- (void)finishInteractiveTransition;
- (void)cancelInteractiveTransition;
- (void)completeTransition:(BOOL)didComplete;
- (UIViewController *)viewControllerForKey:(NSString *)key;
- (UIView *)viewForKey:(NSString *)key;
- (CGRect)initialFrameForViewController:(UIViewController *)controller;
- (CGRect)finalFrameForViewController:(UIViewController *)controller;
@end

@protocol UIViewControllerAnimatedTransitioning <NSObject>
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext;
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext;
@optional
- (void)animationEnded:(BOOL)transitionCompleted;
@end

@protocol UIViewControllerInteractiveTransitioning <NSObject>
- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext;
@optional
- (CGFloat)completionSpeed;
- (UIViewAnimationCurve)completionCurve;
@end

@protocol UIViewControllerTransitioningDelegate <NSObject>
@optional
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source;
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed;
- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id<UIViewControllerAnimatedTransitioning>)animator;
- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator;
@end

/* Transitions are not animated, so nothing drives one of these; it keeps
 * what it is told for subclasses that read it back. */
@interface UIPercentDrivenInteractiveTransition : NSObject <UIViewControllerInteractiveTransitioning>
@property (nonatomic, readonly) CGFloat duration;
@property (nonatomic, readonly) CGFloat percentComplete;
@property (nonatomic) CGFloat completionSpeed;
@property (nonatomic) UIViewAnimationCurve completionCurve;
@property (nonatomic) BOOL wantsInteractiveStart;
- (void)pauseInteractiveTransition;
- (void)updateInteractiveTransition:(CGFloat)percentComplete;
- (void)cancelInteractiveTransition;
- (void)finishInteractiveTransition;
@end

#endif /* UIKIT_UIVIEWCONTROLLERTRANSITIONING_H */
