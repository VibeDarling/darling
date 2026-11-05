/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#pragma once
#import <UIKit/UIViewController.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

// Rung 2: the numeric values (Default/Cancel/Destructive = 0/1/2, ActionSheet = 0, Alert = 1)
// are those in the MIT-licensed WinObjC headers UIAlertAction.h and UIAlertController.h.
// Apple's documentation pages name the constants without values.
typedef NS_ENUM(NSInteger, UIAlertActionStyle) {
    UIAlertActionStyleDefault = 0,
    UIAlertActionStyleCancel,
    UIAlertActionStyleDestructive,
};

typedef NS_ENUM(NSInteger, UIAlertControllerStyle) {
    UIAlertControllerStyleActionSheet = 0,
    UIAlertControllerStyleAlert,
};

NS_ASSUME_NONNULL_BEGIN

// Data model only: the action's handler is stored but nothing can select an action because
// there is no presentation.
@interface UIAlertAction : NSObject {
@package
	NSString *_uiTitle;
	UIAlertActionStyle _uiStyle;
	void (^_uiHandler)(UIAlertAction *);
}
+ (instancetype)actionWithTitle:(nullable NSString *)title style:(UIAlertActionStyle)style
                        handler:(void (^_Nullable)(UIAlertAction *action))handler;
// Readonly is not stated on the pages that could be fetched (rung 6).
@property(nonatomic, readonly, nullable) NSString *title;
@property(nonatomic, readonly) UIAlertActionStyle style;
@end

// title is inherited from UIViewController.
@interface UIAlertController : UIViewController {
@package
	NSString *_uiMessage;
	UIAlertControllerStyle _uiPreferredStyle;
	NSMutableArray *_uiActions;
}
+ (instancetype)alertControllerWithTitle:(nullable NSString *)title message:(nullable NSString *)message
                          preferredStyle:(UIAlertControllerStyle)preferredStyle;
@property(nonatomic, copy, nullable) NSString *message;
@property(nonatomic, readonly) UIAlertControllerStyle preferredStyle;
- (void)addAction:(UIAlertAction *)action;
@property(nonatomic, readonly) NSArray<UIAlertAction *> *actions;
@end

NS_ASSUME_NONNULL_END
