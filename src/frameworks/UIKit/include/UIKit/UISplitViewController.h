/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISPLITVIEWCONTROLLER_H
#define UIKIT_UISPLITVIEWCONTROLLER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>

@class UISplitViewController, UIBarButtonItem;

typedef NS_ENUM(NSInteger, UISplitViewControllerDisplayMode) {
	UISplitViewControllerDisplayModeAutomatic,
	UISplitViewControllerDisplayModePrimaryHidden,
	UISplitViewControllerDisplayModeAllVisible,
	UISplitViewControllerDisplayModePrimaryOverlay,
};

extern CGFloat const UISplitViewControllerAutomaticDimension;

@protocol UISplitViewControllerDelegate <NSObject>
@optional
- (BOOL)splitViewController:(UISplitViewController *)splitViewController showViewController:(UIViewController *)controller sender:(id)sender;
- (BOOL)splitViewController:(UISplitViewController *)splitViewController showDetailViewController:(UIViewController *)controller sender:(id)sender;
- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondary ontoPrimaryViewController:(UIViewController *)primary;
- (BOOL)splitViewController:(UISplitViewController *)splitViewController shouldHideViewController:(UIViewController *)controller inOrientation:(UIInterfaceOrientation)orientation;
@end

/* A phone's split view: collapsed, showing the primary controller, with
 * detail controllers pushed onto it (or presented, if it cannot push). */
@interface UISplitViewController : UIViewController
@property (nonatomic, copy) NSArray<__kindof UIViewController *> *viewControllers;
@property (nonatomic, weak) id<UISplitViewControllerDelegate> delegate;
@property (nonatomic, readonly, getter=isCollapsed) BOOL collapsed;
@property (nonatomic) BOOL presentsWithGesture;
@property (nonatomic) UISplitViewControllerDisplayMode preferredDisplayMode;
@property (nonatomic, readonly) UISplitViewControllerDisplayMode displayMode;
@property (nonatomic) CGFloat preferredPrimaryColumnWidthFraction;
@property (nonatomic) CGFloat minimumPrimaryColumnWidth;
@property (nonatomic) CGFloat maximumPrimaryColumnWidth;
@property (nonatomic, readonly) CGFloat primaryColumnWidth;
- (UIBarButtonItem *)displayModeButtonItem;
@end

@interface UIViewController (UISplitViewController)
@property (nonatomic, readonly) UISplitViewController *splitViewController;
- (void)collapseSecondaryViewController:(UIViewController *)secondary forSplitViewController:(UISplitViewController *)splitViewController;
@end

#endif /* UIKIT_UISPLITVIEWCONTROLLER_H */
