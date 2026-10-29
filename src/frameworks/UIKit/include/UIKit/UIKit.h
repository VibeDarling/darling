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
#import <UIKit/NSAttributedString.h>
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
#import <UIKit/UIAppearance.h>
#import <UIKit/UILayoutGuide.h>
#import <UIKit/UIGestureRecognizer.h>
#import <UIKit/UITableViewController.h>
#import <UIKit/UIToolbar.h>
#import <UIKit/UISlider.h>
#import <UIKit/UIProgressView.h>
#import <UIKit/UIPageControl.h>
#import <UIKit/UIPickerView.h>
#import <UIKit/UIDatePicker.h>
#import <UIKit/UITextView.h>
#import <UIKit/UIBezierPath.h>
#import <UIKit/UINib.h>
#import <UIKit/UIStoryboard.h>
#import <UIKit/UIStoryboardSegue.h>
#import <UIKit/UIViewControllerTransitioning.h>
#import <UIKit/UISplitViewController.h>
#import <UIKit/UIPageViewController.h>
#import <UIKit/UIPopoverController.h>
#import <UIKit/UIActivity.h>
#import <UIKit/UIActivityViewController.h>
#import <UIKit/UIDocumentInteractionController.h>
#import <UIKit/UIImagePickerController.h>
#import <UIKit/UIMenuController.h>
#import <UIKit/UIPrintInteractionController.h>
#import <UIKit/UIFontDescriptor.h>
#import <UIKit/UIMotionEffect.h>
#import <UIKit/UICollectionView.h>

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

/* Constants apps link against; defined in UIKitConstants.m. */
typedef CGFloat UIWindowLevel;
extern const UIWindowLevel UIWindowLevelNormal;
extern const UIWindowLevel UIWindowLevelStatusBar;
extern const UIWindowLevel UIWindowLevelAlert;

typedef NSUInteger UIBackgroundTaskIdentifier;
extern const UIBackgroundTaskIdentifier UIBackgroundTaskInvalid;

typedef uint64_t UIAccessibilityTraits;
extern UIAccessibilityTraits UIAccessibilityTraitButton;
BOOL UIAccessibilityIsReduceMotionEnabled(void);
BOOL UIAccessibilityIsReduceTransparencyEnabled(void);
BOOL UIAccessibilityIsVoiceOverRunning(void);
BOOL UIAccessibilityIsBoldTextEnabled(void);
BOOL UIAccessibilityDarkerSystemColorsEnabled(void);

extern const CGFloat UIViewNoIntrinsicMetric;
extern NSString *const UITrackingRunLoopMode;

extern NSString *const UIApplicationWillChangeStatusBarOrientationNotification;
extern NSString *const UIApplicationDidChangeStatusBarOrientationNotification;
extern NSString *const UIApplicationUserDidTakeScreenshotNotification;

extern NSString *const UITextFieldTextDidBeginEditingNotification;
extern NSString *const UITextFieldTextDidChangeNotification;
extern NSString *const UITextViewTextDidBeginEditingNotification;
extern NSString *const UITextViewTextDidChangeNotification;
extern NSString *const UITextViewTextDidEndEditingNotification;

extern NSString *const UIPasteboardChangedNotification;
extern NSArray<NSString *> *UIPasteboardTypeListString;
extern NSArray<NSString *> *UIPasteboardTypeListURL;
extern NSArray<NSString *> *UIPasteboardTypeListImage;
extern NSArray<NSString *> *UIPasteboardTypeListColor;

extern UIActivityType const UIActivityTypePostToFacebook;
extern UIActivityType const UIActivityTypePostToTwitter;
extern UIActivityType const UIActivityTypePostToWeibo;
extern UIActivityType const UIActivityTypeMessage;
extern UIActivityType const UIActivityTypeMail;
extern UIActivityType const UIActivityTypePrint;
extern UIActivityType const UIActivityTypeCopyToPasteboard;
extern UIActivityType const UIActivityTypeAssignToContact;
extern UIActivityType const UIActivityTypeSaveToCameraRoll;
extern UIActivityType const UIActivityTypeAddToReadingList;
extern UIActivityType const UIActivityTypePostToFlickr;
extern UIActivityType const UIActivityTypePostToVimeo;
extern UIActivityType const UIActivityTypePostToTencentWeibo;
extern UIActivityType const UIActivityTypeAirDrop;
extern UIActivityType const UIActivityTypeOpenInIBooks;

extern NSString *const UICollectionElementKindSectionHeader;
extern NSString *const UICollectionElementKindSectionFooter;

extern UIFontDescriptorAttributeName const UIFontDescriptorFamilyAttribute;
extern UIFontDescriptorAttributeName const UIFontDescriptorNameAttribute;
extern UIFontDescriptorAttributeName const UIFontDescriptorFaceAttribute;
extern UIFontDescriptorAttributeName const UIFontDescriptorSizeAttribute;

extern UIFontTextStyle const UIFontTextStyleTitle1;
extern UIFontTextStyle const UIFontTextStyleTitle2;
extern UIFontTextStyle const UIFontTextStyleTitle3;
extern UIFontTextStyle const UIFontTextStyleHeadline;
extern UIFontTextStyle const UIFontTextStyleSubheadline;
extern UIFontTextStyle const UIFontTextStyleBody;
extern UIFontTextStyle const UIFontTextStyleCallout;
extern UIFontTextStyle const UIFontTextStyleFootnote;
extern UIFontTextStyle const UIFontTextStyleCaption1;
extern UIFontTextStyle const UIFontTextStyleCaption2;

typedef NSString *UIImagePickerControllerInfoKey;
extern UIImagePickerControllerInfoKey const UIImagePickerControllerMediaType;
extern UIImagePickerControllerInfoKey const UIImagePickerControllerOriginalImage;
extern UIImagePickerControllerInfoKey const UIImagePickerControllerEditedImage;
extern UIImagePickerControllerInfoKey const UIImagePickerControllerCropRect;
extern UIImagePickerControllerInfoKey const UIImagePickerControllerMediaURL;
extern UIImagePickerControllerInfoKey const UIImagePickerControllerReferenceURL;

extern NSString *const UIStateRestorationViewControllerStoryboardKey;
extern NSString *const UITransitionContextFromViewControllerKey;
extern NSString *const UITransitionContextToViewControllerKey;
extern NSString *const UITransitionContextFromViewKey;
extern NSString *const UITransitionContextToViewKey;

#endif /* UIKIT_UIKIT_H */
