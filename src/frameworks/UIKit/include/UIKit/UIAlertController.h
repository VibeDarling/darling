/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIALERTCONTROLLER_H
#define UIKIT_UIALERTCONTROLLER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>

@class UITextField;

typedef NS_ENUM(NSInteger, UIAlertActionStyle) {
	UIAlertActionStyleDefault = 0,
	UIAlertActionStyleCancel,
	UIAlertActionStyleDestructive,
};

typedef NS_ENUM(NSInteger, UIAlertControllerStyle) {
	UIAlertControllerStyleActionSheet = 0,
	UIAlertControllerStyleAlert,
};

@interface UIAlertAction : NSObject <NSCopying>
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) UIAlertActionStyle style;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@end

/*
 * iOS 8's alerts and action sheets. Presenting one shows it as UIAlertView
 * and UIActionSheet show theirs; choosing an action dismisses it, then runs
 * the action's handler.
 */
@interface UIAlertController : UIViewController
+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle;
- (void)addAction:(UIAlertAction *)action;
@property (nonatomic, readonly) NSArray<UIAlertAction *> *actions;
@property (nonatomic, strong) UIAlertAction *preferredAction;
- (void)addTextFieldWithConfigurationHandler:(void (^)(UITextField *textField))configurationHandler;
@property (nonatomic, readonly) NSArray<UITextField *> *textFields;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, readonly) UIAlertControllerStyle preferredStyle;
@end

#endif /* UIKIT_UIALERTCONTROLLER_H */
