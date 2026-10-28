/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* The iOS-facing umbrella.  UIKit here is a source-compatible surface built on
 * Darling's AppKit, not a port of Apple's framework: classes appear as they gain
 * an implementation (see src/frameworks/UIKit/README.md). */

#ifndef UIKIT_UIKIT_H
#define UIKIT_UIKIT_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <UIKit/UIResponder.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIApplicationDelegate.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIGraphics.h>
#import <UIKit/UIImage.h>
#import <UIKit/UITouch.h>
#import <UIKit/UIEvent.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIView.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UILabel.h>
#import <UIKit/UICollectionViewCompositionalLayout.h>
#import <UIKit/UIGeometry.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIPasteboard.h>
#import <UIKit/UIStringDrawing.h>
#import <UIKit/UIImageView.h>
#import <UIKit/UIControl.h>
#import <UIKit/UITextField.h>
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UITabBarController.h>
#import <UIKit/UIScrollView.h>
#import <UIKit/UITableView.h>
#import <UIKit/UIAlertView.h>
#import <UIKit/UIWebView.h>

extern NSString *const UIKeyboardWillShowNotification;
extern NSString *const UIKeyboardDidShowNotification;
extern NSString *const UIKeyboardWillHideNotification;
extern NSString *const UIKeyboardDidHideNotification;
extern NSString *const UIKeyboardWillChangeFrameNotification;
extern NSString *const UIKeyboardFrameBeginUserInfoKey;
extern NSString *const UIKeyboardFrameEndUserInfoKey;
extern NSString *const UIKeyboardAnimationDurationUserInfoKey;
extern NSString *const UIKeyboardAnimationCurveUserInfoKey;
extern NSString *const UIKeyboardBoundsUserInfoKey;
extern NSString *const UIKeyboardCenterBeginUserInfoKey;
extern NSString *const UIKeyboardCenterEndUserInfoKey;

#endif /* UIKIT_UIKIT_H */
