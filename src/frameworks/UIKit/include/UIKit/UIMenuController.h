/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIMENUCONTROLLER_H
#define UIKIT_UIMENUCONTROLLER_H

#import <UIKit/UIView.h>

typedef NS_ENUM(NSInteger, UIMenuControllerArrowDirection) {
	UIMenuControllerArrowDefault,
	UIMenuControllerArrowUp,
	UIMenuControllerArrowDown,
	UIMenuControllerArrowLeft,
	UIMenuControllerArrowRight,
};

extern NSNotificationName const UIMenuControllerWillShowMenuNotification;
extern NSNotificationName const UIMenuControllerDidShowMenuNotification;
extern NSNotificationName const UIMenuControllerWillHideMenuNotification;
extern NSNotificationName const UIMenuControllerDidHideMenuNotification;
extern NSNotificationName const UIMenuControllerMenuFrameDidChangeNotification;

NS_ASSUME_NONNULL_BEGIN

@interface UIMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title action:(SEL)action;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) SEL action;
@end

/* The edit menu: shown as an action sheet of the items its target takes. */
@interface UIMenuController : NSObject
@property (class, nonatomic, readonly) UIMenuController *sharedMenuController;
@property (nonatomic, getter=isMenuVisible) BOOL menuVisible;
@property (nonatomic) UIMenuControllerArrowDirection arrowDirection;
@property (nullable, nonatomic, copy) NSArray<UIMenuItem *> *menuItems;
@property (nonatomic, readonly) CGRect menuFrame;
- (void)setMenuVisible:(BOOL)visible animated:(BOOL)animated;
- (void)setTargetRect:(CGRect)rect inView:(UIView *)view;
- (void)update;
- (void)showMenuFromView:(UIView *)targetView rect:(CGRect)targetRect;
- (void)hideMenuFromView:(UIView *)targetView;
- (void)hideMenu;
@end

NS_ASSUME_NONNULL_END

#endif /* UIKIT_UIMENUCONTROLLER_H */
