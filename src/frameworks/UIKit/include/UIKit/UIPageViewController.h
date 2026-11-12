/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIPAGEVIEWCONTROLLER_H
#define UIKIT_UIPAGEVIEWCONTROLLER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>

@class UIPageViewController;

typedef NS_ENUM(NSInteger, UIPageViewControllerNavigationOrientation) {
	UIPageViewControllerNavigationOrientationHorizontal,
	UIPageViewControllerNavigationOrientationVertical,
};

typedef NS_ENUM(NSInteger, UIPageViewControllerSpineLocation) {
	UIPageViewControllerSpineLocationNone,
	UIPageViewControllerSpineLocationMin,
	UIPageViewControllerSpineLocationMid,
	UIPageViewControllerSpineLocationMax,
};

typedef NS_ENUM(NSInteger, UIPageViewControllerNavigationDirection) {
	UIPageViewControllerNavigationDirectionForward,
	UIPageViewControllerNavigationDirectionReverse,
};

typedef NS_ENUM(NSInteger, UIPageViewControllerTransitionStyle) {
	UIPageViewControllerTransitionStylePageCurl,
	UIPageViewControllerTransitionStyleScroll,
};

extern NSString *const UIPageViewControllerOptionSpineLocationKey;
extern NSString *const UIPageViewControllerOptionInterPageSpacingKey;

@protocol UIPageViewControllerDataSource <NSObject>
@required
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController;
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController;
@optional
- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController;
- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController;
@end

@protocol UIPageViewControllerDelegate <NSObject>
@optional
- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers;
- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed;
- (UIPageViewControllerSpineLocation)pageViewController:(UIPageViewController *)pageViewController spineLocationForInterfaceOrientation:(UIInterfaceOrientation)orientation;
@end

/* Shows one page at a time; a swipe (or a drag) turns to the next. */
@interface UIPageViewController : UIViewController
- (instancetype)initWithTransitionStyle:(UIPageViewControllerTransitionStyle)style navigationOrientation:(UIPageViewControllerNavigationOrientation)orientation options:(NSDictionary *)options;
@property (nonatomic, weak) id<UIPageViewControllerDelegate> delegate;
@property (nonatomic, weak) id<UIPageViewControllerDataSource> dataSource;
@property (nonatomic, readonly) UIPageViewControllerTransitionStyle transitionStyle;
@property (nonatomic, readonly) UIPageViewControllerNavigationOrientation navigationOrientation;
@property (nonatomic, readonly) UIPageViewControllerSpineLocation spineLocation;
@property (nonatomic, getter=isDoubleSided) BOOL doubleSided;
@property (nonatomic, readonly) NSArray *gestureRecognizers;
@property (nonatomic, readonly) NSArray<UIViewController *> *viewControllers;
- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers direction:(UIPageViewControllerNavigationDirection)direction animated:(BOOL)animated completion:(void (^)(BOOL finished))completion;
@end

#endif /* UIKIT_UIPAGEVIEWCONTROLLER_H */
