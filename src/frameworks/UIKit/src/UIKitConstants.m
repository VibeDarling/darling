/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIKit.h>

/*
 * Constants iOS apps link from UIKit that nothing here reads yet. The
 * values are the ones iOS uses, since apps compare against them and some
 * store them.
 */

const UIWindowLevel UIWindowLevelNormal = 0;
const UIWindowLevel UIWindowLevelStatusBar = 1000;
const UIWindowLevel UIWindowLevelAlert = 2000;

const UIBackgroundTaskIdentifier UIBackgroundTaskInvalid = 0;

UIAccessibilityTraits UIAccessibilityTraitButton = 1 << 0;

/* No accessibility settings are on. */
BOOL UIAccessibilityIsReduceMotionEnabled(void) { return NO; }
BOOL UIAccessibilityIsReduceTransparencyEnabled(void) { return NO; }
BOOL UIAccessibilityIsVoiceOverRunning(void) { return NO; }
BOOL UIAccessibilityIsBoldTextEnabled(void) { return NO; }
BOOL UIAccessibilityDarkerSystemColorsEnabled(void) { return NO; }

const CGFloat UIViewNoIntrinsicMetric = -1;
NSString *const UITrackingRunLoopMode = @"UITrackingRunLoopMode";

NSString *const UIApplicationWillChangeStatusBarOrientationNotification = @"UIApplicationWillChangeStatusBarOrientationNotification";
NSString *const UIApplicationDidChangeStatusBarOrientationNotification = @"UIApplicationDidChangeStatusBarOrientationNotification";
NSString *const UIApplicationUserDidTakeScreenshotNotification = @"UIApplicationUserDidTakeScreenshotNotification";

NSString *const UITextFieldTextDidBeginEditingNotification = @"UITextFieldTextDidBeginEditingNotification";
NSString *const UITextFieldTextDidChangeNotification = @"UITextFieldTextDidChangeNotification";
NSString *const UITextFieldTextDidEndEditingNotification = @"UITextFieldTextDidEndEditingNotification";
NSString *const UITextViewTextDidBeginEditingNotification = @"UITextViewTextDidBeginEditingNotification";
NSString *const UITextViewTextDidChangeNotification = @"UITextViewTextDidChangeNotification";
NSString *const UITextViewTextDidEndEditingNotification = @"UITextViewTextDidEndEditingNotification";

NSString *const UIPasteboardChangedNotification = @"UIPasteboardChangedNotification";
NSArray<NSString *> *UIPasteboardTypeListString;
NSArray<NSString *> *UIPasteboardTypeListURL;
NSArray<NSString *> *UIPasteboardTypeListImage;
NSArray<NSString *> *UIPasteboardTypeListColor;

__attribute__((constructor))
static void UIKitInitPasteboardTypeLists(void)
{
	UIPasteboardTypeListString = @[ @"public.utf8-plain-text", @"public.text" ];
	UIPasteboardTypeListURL = @[ @"public.url" ];
	UIPasteboardTypeListImage = @[ @"public.png", @"public.tiff", @"public.jpeg", @"com.compuserve.gif" ];
	UIPasteboardTypeListColor = @[ @"com.apple.uikit.color" ];
}

UIActivityType const UIActivityTypePostToFacebook = @"com.apple.UIKit.activity.PostToFacebook";
UIActivityType const UIActivityTypePostToTwitter = @"com.apple.UIKit.activity.PostToTwitter";
UIActivityType const UIActivityTypePostToWeibo = @"com.apple.UIKit.activity.PostToWeibo";
UIActivityType const UIActivityTypeMessage = @"com.apple.UIKit.activity.Message";
UIActivityType const UIActivityTypeMail = @"com.apple.UIKit.activity.Mail";
UIActivityType const UIActivityTypePrint = @"com.apple.UIKit.activity.Print";
UIActivityType const UIActivityTypeCopyToPasteboard = @"com.apple.UIKit.activity.CopyToPasteboard";
UIActivityType const UIActivityTypeAssignToContact = @"com.apple.UIKit.activity.AssignToContact";
UIActivityType const UIActivityTypeSaveToCameraRoll = @"com.apple.UIKit.activity.SaveToCameraRoll";
UIActivityType const UIActivityTypeAddToReadingList = @"com.apple.UIKit.activity.AddToReadingList";
UIActivityType const UIActivityTypePostToFlickr = @"com.apple.UIKit.activity.PostToFlickr";
UIActivityType const UIActivityTypePostToVimeo = @"com.apple.UIKit.activity.PostToVimeo";
UIActivityType const UIActivityTypePostToTencentWeibo = @"com.apple.UIKit.activity.TencentWeibo";
UIActivityType const UIActivityTypeAirDrop = @"com.apple.UIKit.activity.AirDrop";
UIActivityType const UIActivityTypeOpenInIBooks = @"com.apple.UIKit.activity.OpenInIBooks";

NSString *const UICollectionElementKindSectionHeader = @"UICollectionElementKindSectionHeader";
NSString *const UICollectionElementKindSectionFooter = @"UICollectionElementKindSectionFooter";

UIFontDescriptorAttributeName const UIFontDescriptorFamilyAttribute = @"NSFontFamilyAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorNameAttribute = @"NSFontNameAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorFaceAttribute = @"NSFontFaceAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorSizeAttribute = @"NSFontSizeAttribute";

UIFontTextStyle const UIFontTextStyleTitle1 = @"UICTFontTextStyleTitle1";
UIFontTextStyle const UIFontTextStyleTitle2 = @"UICTFontTextStyleTitle2";
UIFontTextStyle const UIFontTextStyleTitle3 = @"UICTFontTextStyleTitle3";
UIFontTextStyle const UIFontTextStyleHeadline = @"UICTFontTextStyleHeadline";
UIFontTextStyle const UIFontTextStyleSubheadline = @"UICTFontTextStyleSubhead";
UIFontTextStyle const UIFontTextStyleBody = @"UICTFontTextStyleBody";
UIFontTextStyle const UIFontTextStyleCallout = @"UICTFontTextStyleCallout";
UIFontTextStyle const UIFontTextStyleFootnote = @"UICTFontTextStyleFootnote";
UIFontTextStyle const UIFontTextStyleCaption1 = @"UICTFontTextStyleCaption1";
UIFontTextStyle const UIFontTextStyleCaption2 = @"UICTFontTextStyleCaption2";

UIImagePickerControllerInfoKey const UIImagePickerControllerMediaType = @"UIImagePickerControllerMediaType";
UIImagePickerControllerInfoKey const UIImagePickerControllerOriginalImage = @"UIImagePickerControllerOriginalImage";
UIImagePickerControllerInfoKey const UIImagePickerControllerEditedImage = @"UIImagePickerControllerEditedImage";
UIImagePickerControllerInfoKey const UIImagePickerControllerCropRect = @"UIImagePickerControllerCropRect";
UIImagePickerControllerInfoKey const UIImagePickerControllerMediaURL = @"UIImagePickerControllerMediaURL";
UIImagePickerControllerInfoKey const UIImagePickerControllerReferenceURL = @"UIImagePickerControllerReferenceURL";

NSString *const UIStateRestorationViewControllerStoryboardKey = @"UIStateRestorationViewControllerStoryboardKey";
NSString *const UITransitionContextFromViewControllerKey = @"UITransitionContextFromViewControllerKey";
NSString *const UITransitionContextToViewControllerKey = @"UITransitionContextToViewControllerKey";
NSString *const UITransitionContextFromViewKey = @"UITransitionContextFromViewKey";
NSString *const UITransitionContextToViewKey = @"UITransitionContextToViewKey";

/* Notifications and keys newer iOS apps observe or read; nothing here posts most of them. */
NSString *const UIApplicationProtectedDataDidBecomeAvailable = @"UIApplicationProtectedDataDidBecomeAvailable";
NSString *const UIApplicationProtectedDataWillBecomeUnavailable = @"UIApplicationProtectedDataWillBecomeUnavailable";
NSString *const UIApplicationSignificantTimeChangeNotification = @"UIApplicationSignificantTimeChangeNotification";
NSString *const UIApplicationBackgroundRefreshStatusDidChangeNotification = @"UIApplicationBackgroundRefreshStatusDidChangeNotification";
NSString *const UIWindowDidResignKeyNotification = @"UIWindowDidResignKeyNotification";
NSString *const UIWindowDidBecomeKeyNotification = @"UIWindowDidBecomeKeyNotification";
NSString *const UIWindowDidBecomeVisibleNotification = @"UIWindowDidBecomeVisibleNotification";
NSString *const UIWindowDidBecomeHiddenNotification = @"UIWindowDidBecomeHiddenNotification";
NSString *const UIApplicationStatusBarOrientationUserInfoKey = @"UIApplicationStatusBarOrientationUserInfoKey";
NSString *const UIApplicationStatusBarFrameUserInfoKey = @"UIApplicationStatusBarFrameUserInfoKey";
NSString *const UIDeviceBatteryLevelDidChangeNotification = @"UIDeviceBatteryLevelDidChangeNotification";
NSString *const UIDeviceBatteryStateDidChangeNotification = @"UIDeviceBatteryStateDidChangeNotification";
NSString *const UIApplicationLaunchOptionsAnnotationKey = @"UIApplicationLaunchOptionsAnnotationKey";
NSString *const UIApplicationLaunchOptionsRemoteNotificationKey = @"UIApplicationLaunchOptionsRemoteNotificationKey";
NSString *const UIApplicationOpenURLOptionsAnnotationKey = @"UIApplicationOpenURLOptionsAnnotationKey";
NSString *const UIApplicationOpenURLOptionsSourceApplicationKey = @"UIApplicationOpenURLOptionsSourceApplicationKey";
NSString *const UIApplicationOpenSettingsURLString = @"app-settings:";

NSString *const UITextContentTypeName = @"name";
NSString *const UITextContentTypeUsername = @"username";
NSString *const UITextContentTypePassword = @"password";
NSString *const UITextContentTypeNewPassword = @"new-password";

/* UIFontWidth is a CGFloat; these are iOS's values. */
const CGFloat UIFontWidthStandard = 0;
const CGFloat UIFontWidthCondensed = -0.2;
const CGFloat UIFontWidthExpanded = 0.2;
const CGFloat UIFontWidthCompressed = -0.3;

UIAccessibilityTraits UIAccessibilityTraitAllowsDirectInteraction = 1 << 13;

NSString *const UIAccessibilityVoiceOverStatusDidChangeNotification = @"UIAccessibilityVoiceOverStatusDidChangeNotification";
NSString *const UIAccessibilitySwitchControlStatusDidChangeNotification = @"UIAccessibilitySwitchControlStatusDidChangeNotification";
NSString *const UIAccessibilityAssistiveTouchStatusDidChangeNotification = @"UIAccessibilityAssistiveTouchStatusDidChangeNotification";
NSString *const UIAccessibilityBoldTextStatusDidChangeNotification = @"UIAccessibilityBoldTextStatusDidChangeNotification";
NSString *const UIAccessibilityButtonShapesEnabledStatusDidChangeNotification = @"UIAccessibilityButtonShapesEnabledStatusDidChangeNotification";
NSString *const UIAccessibilityClosedCaptioningStatusDidChangeNotification = @"UIAccessibilityClosedCaptioningStatusDidChangeNotification";
NSString *const UIAccessibilityDarkerSystemColorsStatusDidChangeNotification = @"UIAccessibilityDarkerSystemColorsStatusDidChangeNotification";
NSString *const UIAccessibilityGrayscaleStatusDidChangeNotification = @"UIAccessibilityGrayscaleStatusDidChangeNotification";
NSString *const UIAccessibilityHearingDevicePairedEarDidChangeNotification = @"UIAccessibilityHearingDevicePairedEarDidChangeNotification";
NSString *const UIAccessibilityInvertColorsStatusDidChangeNotification = @"UIAccessibilityInvertColorsStatusDidChangeNotification";
NSString *const UIAccessibilityMonoAudioStatusDidChangeNotification = @"UIAccessibilityMonoAudioStatusDidChangeNotification";
NSString *const UIAccessibilityOnOffSwitchLabelsDidChangeNotification = @"UIAccessibilityOnOffSwitchLabelsDidChangeNotification";
NSString *const UIAccessibilityReduceMotionStatusDidChangeNotification = @"UIAccessibilityReduceMotionStatusDidChangeNotification";
NSString *const UIAccessibilityReduceTransparencyStatusDidChangeNotification = @"UIAccessibilityReduceTransparencyStatusDidChangeNotification";
NSString *const UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification = @"UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification";

BOOL UIAccessibilityButtonShapesEnabled(void) { return NO; }
BOOL UIAccessibilityIsAssistiveTouchRunning(void) { return NO; }
BOOL UIAccessibilityIsClosedCaptioningEnabled(void) { return NO; }
BOOL UIAccessibilityIsGrayscaleEnabled(void) { return NO; }
BOOL UIAccessibilityIsGuidedAccessEnabled(void) { return NO; }
BOOL UIAccessibilityIsInvertColorsEnabled(void) { return NO; }
BOOL UIAccessibilityIsMonoAudioEnabled(void) { return NO; }
BOOL UIAccessibilityIsOnOffSwitchLabelsEnabled(void) { return NO; }
BOOL UIAccessibilityIsShakeToUndoEnabled(void) { return YES; }
BOOL UIAccessibilityIsSwitchControlRunning(void) { return NO; }
BOOL UIAccessibilityPrefersCrossFadeTransitions(void) { return NO; }
BOOL UIAccessibilityShouldDifferentiateWithoutColor(void) { return NO; }
/* UIAccessibilityHearingDeviceEar: no hearing device is paired. */
NSUInteger UIAccessibilityHearingDevicePairedEar(void) { return 0; }
