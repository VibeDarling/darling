/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UINAVIGATIONCONTROLLER_H
#define UIKIT_UINAVIGATIONCONTROLLER_H

#import <UIKit/UIViewController.h>
#import <UIKit/UIView.h>
#import <UIKit/UIBarButtonItem.h>

@class UINavigationBar, UINavigationController, UIColor;

@interface UINavigationItem : NSObject
- (instancetype)initWithTitle:(NSString *)title;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *prompt;
@property (nonatomic, strong) UIView *titleView;
@property (nonatomic, strong) UIBarButtonItem *backBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *leftBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *rightBarButtonItem;
@property (nonatomic, copy) NSArray *leftBarButtonItems;
@property (nonatomic, copy) NSArray *rightBarButtonItems;
@property (nonatomic) BOOL hidesBackButton;
@property (nonatomic) BOOL leftItemsSupplementBackButton;
- (void)setLeftBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;
- (void)setRightBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;
- (void)setLeftBarButtonItems:(NSArray *)items animated:(BOOL)animated;
- (void)setRightBarButtonItems:(NSArray *)items animated:(BOOL)animated;
- (void)setHidesBackButton:(BOOL)hides animated:(BOOL)animated;
@end

@protocol UINavigationBarDelegate <NSObject>
@optional
- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item;
@end

/* An iOS 7 style bar: the top item's title in the middle, its back button
 * (the previous item's title) at the left, its bar button items beside. */
@interface UINavigationBar : UIView
@property (nonatomic, weak) id<UINavigationBarDelegate> delegate;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, readonly) UINavigationItem *topItem;
@property (nonatomic, readonly) UINavigationItem *backItem;
@property (nonatomic) UIBarStyle barStyle;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, strong) UIColor *barTintColor;
@property (nonatomic, getter=isTranslucent) BOOL translucent;
@property (nonatomic, copy) NSDictionary *titleTextAttributes;
+ (CGSize)defaultSize;
- (void)setItems:(NSArray *)items animated:(BOOL)animated;
- (void)pushNavigationItem:(UINavigationItem *)item animated:(BOOL)animated;
- (UINavigationItem *)popNavigationItemAnimated:(BOOL)animated;
@end

@protocol UINavigationControllerDelegate <NSObject>
@optional
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
@end

@interface UINavigationController : UIViewController
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;
@property (nonatomic, copy) NSArray *viewControllers;
@property (nonatomic, readonly) UIViewController *topViewController;
@property (nonatomic, readonly) UIViewController *visibleViewController;
@property (nonatomic, readonly) UINavigationBar *navigationBar;
@property (nonatomic, getter=isNavigationBarHidden) BOOL navigationBarHidden;
@property (nonatomic, getter=isToolbarHidden) BOOL toolbarHidden;
@property (nonatomic, weak) id<UINavigationControllerDelegate> delegate;
- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated;
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (UIViewController *)popViewControllerAnimated:(BOOL)animated;
- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated;
- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated;
- (void)setToolbarHidden:(BOOL)hidden animated:(BOOL)animated;
@end

#endif /* UIKIT_UINAVIGATIONCONTROLLER_H */
