/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIALERTVIEW_H
#define UIKIT_UIALERTVIEW_H

#import <UIKit/UIView.h>

@class UIAlertView, UIActionSheet, UITextField, UIBarButtonItem, UITabBar, UIWindow;

typedef NS_ENUM(NSInteger, UIAlertViewStyle) {
	UIAlertViewStyleDefault,
	UIAlertViewStyleSecureTextInput,
	UIAlertViewStylePlainTextInput,
	UIAlertViewStyleLoginAndPasswordInput,
};

@protocol UIAlertViewDelegate <NSObject>
@optional
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)alertViewCancel:(UIAlertView *)alertView;
- (void)willPresentAlertView:(UIAlertView *)alertView;
- (void)didPresentAlertView:(UIAlertView *)alertView;
- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex;
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;
- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView;
@end

/*
 * Alerts and action sheets cover the key window until a button is chosen.
 * Nothing runs a nested event loop: show returns at once, as on iOS.
 */
@interface UIAlertView : UIView
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, weak) id delegate;
@property (nonatomic) NSInteger cancelButtonIndex;
@property (nonatomic, readonly) NSInteger firstOtherButtonIndex;
@property (nonatomic, readonly) NSInteger numberOfButtons;
@property (nonatomic, readonly, getter=isVisible) BOOL visible;
@property (nonatomic) UIAlertViewStyle alertViewStyle;
- (NSInteger)addButtonWithTitle:(NSString *)title;
- (NSString *)buttonTitleAtIndex:(NSInteger)buttonIndex;
- (UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex;
- (void)show;
- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated;
/* Private UIKit API older apps use. */
@property (nonatomic, copy) NSString *context;
- (void)setNumberOfRows:(int)rows;
- (void)setRunsModal:(BOOL)modal;
- (void)addTextFieldWithValue:(NSString *)value label:(NSString *)label;
- (UITextField *)textField;
- (id)buttons;
- (void)_updateFrameForDisplay;
@end

typedef NS_ENUM(NSInteger, UIActionSheetStyle) {
	UIActionSheetStyleAutomatic = -1,
	UIActionSheetStyleDefault = 0,
	UIActionSheetStyleBlackTranslucent = 2,
	UIActionSheetStyleBlackOpaque = 1,
};

@protocol UIActionSheetDelegate <NSObject>
@optional
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)actionSheetCancel:(UIActionSheet *)actionSheet;
- (void)willPresentActionSheet:(UIActionSheet *)actionSheet;
- (void)didPresentActionSheet:(UIActionSheet *)actionSheet;
- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex;
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex;
@end

@interface UIActionSheet : UIView
- (instancetype)initWithTitle:(NSString *)title delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, weak) id delegate;
@property (nonatomic) UIActionSheetStyle actionSheetStyle;
@property (nonatomic) NSInteger cancelButtonIndex;
@property (nonatomic) NSInteger destructiveButtonIndex;
@property (nonatomic, readonly) NSInteger firstOtherButtonIndex;
@property (nonatomic, readonly) NSInteger numberOfButtons;
@property (nonatomic, readonly, getter=isVisible) BOOL visible;
- (NSInteger)addButtonWithTitle:(NSString *)title;
- (NSString *)buttonTitleAtIndex:(NSInteger)buttonIndex;
- (void)showInView:(UIView *)view;
- (void)showFromTabBar:(UITabBar *)view;
- (void)showFromToolbar:(UIView *)view;
- (void)showFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;
- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;
- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated;
/* Private UIKit API older apps use. */
@property (nonatomic, copy) NSString *context;
@end

/* Private UIKit's progress panel: a spinner and a line of text. */
@interface UIProgressHUD : UIView
- (instancetype)initWithWindow:(UIWindow *)window;
- (void)setText:(NSString *)text;
- (void)setShowsText:(BOOL)shows;
- (void)setFontSize:(int)size;
- (void)showInView:(UIView *)view;
- (void)show:(BOOL)show;
- (void)hide;
- (void)done;
@end

#endif /* UIKIT_UIALERTVIEW_H */
