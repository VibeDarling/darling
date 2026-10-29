/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UITABBARCONTROLLER_H
#define UIKIT_UITABBARCONTROLLER_H

#import <UIKit/UIViewController.h>
#import <UIKit/UIView.h>
#import <UIKit/UIBarButtonItem.h>

@class UITabBar, UITabBarItem, UITabBarController, UIImage, UIColor, UINavigationController;

typedef NS_ENUM(NSInteger, UITabBarSystemItem) {
	UITabBarSystemItemMore,
	UITabBarSystemItemFavorites,
	UITabBarSystemItemFeatured,
	UITabBarSystemItemTopRated,
	UITabBarSystemItemRecents,
	UITabBarSystemItemContacts,
	UITabBarSystemItemHistory,
	UITabBarSystemItemBookmarks,
	UITabBarSystemItemSearch,
	UITabBarSystemItemDownloads,
	UITabBarSystemItemMostRecent,
	UITabBarSystemItemMostViewed,
};

@interface UITabBarItem : UIBarItem
- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image tag:(NSInteger)tag;
- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage;
- (instancetype)initWithTabBarSystemItem:(UITabBarSystemItem)systemItem tag:(NSInteger)tag;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, copy) NSString *badgeValue;
- (void)setAnimatedBadge:(BOOL)animated;
/* Private: the view behind the tab, whose _badge ivar holds the badge. */
- (UIView *)view;
@end

@protocol UITabBarDelegate <NSObject>
@optional
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item;
@end

@interface UITabBar : UIView
@property (nonatomic, weak) id<UITabBarDelegate> delegate;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, weak) UITabBarItem *selectedItem;
@property (nonatomic) UIBarStyle barStyle;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, strong) UIColor *barTintColor;
@property (nonatomic, getter=isTranslucent) BOOL translucent;
- (void)setItems:(NSArray *)items animated:(BOOL)animated;
@end

@protocol UITabBarControllerDelegate <NSObject>
@optional
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController;
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController;
@end

@interface UITabBarController : UIViewController <UITabBarDelegate>
@property (nonatomic, copy) NSArray *viewControllers;
@property (nonatomic, weak) UIViewController *selectedViewController;
@property (nonatomic) NSUInteger selectedIndex;
@property (nonatomic, readonly) UITabBar *tabBar;
@property (nonatomic, weak) id<UITabBarControllerDelegate> delegate;
@property (nonatomic, copy) NSArray *customizableViewControllers;
@property (nonatomic, readonly) UINavigationController *moreNavigationController;
- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated;
/* Private UIKit API: show no tab as selected, and show it again. */
- (void)concealTabBarSelection;
- (void)revealTabBarSelection;
- (UIView *)_transitionView;
@end

#endif /* UIKIT_UITABBARCONTROLLER_H */
