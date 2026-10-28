/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIVIEWCONTROLLER_H
#define UIKIT_UIVIEWCONTROLLER_H

#import <UIKit/UIResponder.h>
#import <UIKit/UIGeometry.h>
#import <CoreGraphics/CGGeometry.h>

@class UIView, UINavigationItem, UITabBarItem, UIBarButtonItem;
@class UINavigationController, UITabBarController;
@class NSString, NSArray;

typedef NS_ENUM(NSInteger, UIModalPresentationStyle) {
	UIModalPresentationFullScreen = 0,
	UIModalPresentationPageSheet,
	UIModalPresentationFormSheet,
	UIModalPresentationCurrentContext,
};

typedef NS_ENUM(NSInteger, UIModalTransitionStyle) {
	UIModalTransitionStyleCoverVertical = 0,
	UIModalTransitionStyleFlipHorizontal,
	UIModalTransitionStyleCrossDissolve,
	UIModalTransitionStylePartialCurl,
};

/*
 * Presentation is immediate: a presented controller's view covers its
 * presenter's window until it is dismissed, and nothing animates.
 */
@interface UIViewController : UIResponder {
@private
	UIView *_view;
	NSString *_title;
}

@property (nonatomic, strong) UIView *view;
@property (nonatomic, copy) NSString *title;
- (BOOL)isViewLoaded;
- (void)loadView;
- (void)viewDidLoad;
- (void)viewDidUnload;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
- (void)didReceiveMemoryWarning;
/* Darling's first UIKit had argumentless forms; they are still called. */
- (void)viewWillAppear;
- (void)viewDidAppear;

@property (nonatomic, readonly) UINavigationItem *navigationItem;
@property (nonatomic, strong) UITabBarItem *tabBarItem;
@property (nonatomic, readonly) UINavigationController *navigationController;
@property (nonatomic, readonly) UITabBarController *tabBarController;
@property (nonatomic, readonly) UIViewController *parentViewController;
@property (nonatomic, readonly) NSArray *childViewControllers;
- (void)addChildViewController:(UIViewController *)child;
- (void)removeFromParentViewController;
- (void)willMoveToParentViewController:(UIViewController *)parent;
- (void)didMoveToParentViewController:(UIViewController *)parent;

@property (nonatomic, readonly) UIViewController *presentedViewController;
@property (nonatomic, readonly) UIViewController *presentingViewController;
@property (nonatomic, readonly) UIViewController *modalViewController;
@property (nonatomic) UIModalPresentationStyle modalPresentationStyle;
@property (nonatomic) UIModalTransitionStyle modalTransitionStyle;
- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)presentModalViewController:(UIViewController *)controller animated:(BOOL)animated;
- (void)dismissModalViewControllerAnimated:(BOOL)animated;

@property (nonatomic, getter=isEditing) BOOL editing;
- (void)setEditing:(BOOL)editing animated:(BOOL)animated;
- (UIBarButtonItem *)editButtonItem;

@property (nonatomic) BOOL hidesBottomBarWhenPushed;
@property (nonatomic) BOOL wantsFullScreenLayout;
@property (nonatomic) BOOL automaticallyAdjustsScrollViewInsets;
@property (nonatomic) NSUInteger edgesForExtendedLayout;
@property (nonatomic) CGSize contentSizeForViewInPopover;
@property (nonatomic) CGSize preferredContentSize;
@property (nonatomic, copy) NSArray *toolbarItems;
- (void)setToolbarItems:(NSArray *)items animated:(BOOL)animated;

@property (nonatomic, readonly) UIInterfaceOrientation interfaceOrientation;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation;
- (BOOL)shouldAutorotate;
- (NSUInteger)supportedInterfaceOrientations;
@end

#endif /* UIKIT_UIVIEWCONTROLLER_H */
