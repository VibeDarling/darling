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

extern NSString *const UIMenuControllerWillShowMenuNotification;
extern NSString *const UIMenuControllerDidShowMenuNotification;
extern NSString *const UIMenuControllerWillHideMenuNotification;
extern NSString *const UIMenuControllerDidHideMenuNotification;
extern NSString *const UIMenuControllerMenuFrameDidChangeNotification;

@interface UIMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title action:(SEL)action;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) SEL action;
@end

/* The edit menu: shown as an action sheet of the items its target takes. */
@interface UIMenuController : NSObject
+ (UIMenuController *)sharedMenuController;
@property (nonatomic, getter=isMenuVisible) BOOL menuVisible;
@property (nonatomic) UIMenuControllerArrowDirection arrowDirection;
@property (nonatomic, copy) NSArray<UIMenuItem *> *menuItems;
@property (nonatomic, readonly) CGRect menuFrame;
- (void)setMenuVisible:(BOOL)visible animated:(BOOL)animated;
- (void)setTargetRect:(CGRect)rect inView:(UIView *)view;
- (void)update;
@end

#endif /* UIKIT_UIMENUCONTROLLER_H */
