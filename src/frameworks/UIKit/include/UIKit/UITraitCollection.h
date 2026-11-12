/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UITRAITCOLLECTION_H
#define UIKIT_UITRAITCOLLECTION_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGBase.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIView.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIScreen.h>

typedef NSString *UIContentSizeCategory;
extern UIContentSizeCategory const UIContentSizeCategoryUnspecified;
extern UIContentSizeCategory const UIContentSizeCategoryExtraSmall;
extern UIContentSizeCategory const UIContentSizeCategorySmall;
extern UIContentSizeCategory const UIContentSizeCategoryMedium;
extern UIContentSizeCategory const UIContentSizeCategoryLarge;
extern UIContentSizeCategory const UIContentSizeCategoryExtraLarge;
extern UIContentSizeCategory const UIContentSizeCategoryExtraExtraLarge;
extern UIContentSizeCategory const UIContentSizeCategoryExtraExtraExtraLarge;
extern UIContentSizeCategory const UIContentSizeCategoryAccessibilityMedium;
extern UIContentSizeCategory const UIContentSizeCategoryAccessibilityLarge;
extern UIContentSizeCategory const UIContentSizeCategoryAccessibilityExtraLarge;
extern UIContentSizeCategory const UIContentSizeCategoryAccessibilityExtraExtraLarge;
extern UIContentSizeCategory const UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
extern NSNotificationName const UIContentSizeCategoryDidChangeNotification;
BOOL UIContentSizeCategoryIsAccessibilityCategory(UIContentSizeCategory category);
NSComparisonResult UIContentSizeCategoryCompareToCategory(UIContentSizeCategory lhs, UIContentSizeCategory rhs);

typedef NS_ENUM(NSInteger, UIUserInterfaceSizeClass) {
	UIUserInterfaceSizeClassUnspecified = 0,
	UIUserInterfaceSizeClassCompact = 1,
	UIUserInterfaceSizeClassRegular = 2,
};

typedef NS_ENUM(NSInteger, UIUserInterfaceStyle) {
	UIUserInterfaceStyleUnspecified,
	UIUserInterfaceStyleLight,
	UIUserInterfaceStyleDark,
};

typedef NS_ENUM(NSInteger, UIForceTouchCapability) {
	UIForceTouchCapabilityUnknown = 0,
	UIForceTouchCapabilityUnavailable = 1,
	UIForceTouchCapabilityAvailable = 2,
};

typedef NS_ENUM(NSInteger, UIDisplayGamut) {
	UIDisplayGamutUnspecified = -1,
	UIDisplayGamutSRGB,
	UIDisplayGamutP3,
};

typedef NS_ENUM(NSInteger, UIAccessibilityContrast) {
	UIAccessibilityContrastUnspecified = -1,
	UIAccessibilityContrastNormal,
	UIAccessibilityContrastHigh,
};

typedef NS_ENUM(NSInteger, UILegibilityWeight) {
	UILegibilityWeightUnspecified = -1,
	UILegibilityWeightRegular,
	UILegibilityWeightBold,
};

typedef NS_ENUM(NSInteger, UIUserInterfaceLevel) {
	UIUserInterfaceLevelUnspecified = -1,
	UIUserInterfaceLevelBase,
	UIUserInterfaceLevelElevated,
};

typedef NS_ENUM(NSInteger, UIUserInterfaceActiveAppearance) {
	UIUserInterfaceActiveAppearanceUnspecified = -1,
	UIUserInterfaceActiveAppearanceInactive,
	UIUserInterfaceActiveAppearanceActive,
};

/*
 * The device's traits: a phone, its screen's scale, compact width (regular
 * height in portrait), the light appearance, the large text size. Nothing
 * changes them while an app runs, so -traitCollectionDidChange: is sent only
 * when a view's or controller's own override changes them. Dynamic colors
 * are resolved once, when made, against the current trait collection.
 */
@interface UITraitCollection : NSObject <NSCopying, NSSecureCoding>
+ (UITraitCollection *)traitCollectionWithTraitsFromCollections:(NSArray<UITraitCollection *> *)traitCollections;
+ (UITraitCollection *)traitCollectionWithUserInterfaceIdiom:(UIUserInterfaceIdiom)idiom;
+ (UITraitCollection *)traitCollectionWithDisplayScale:(CGFloat)scale;
+ (UITraitCollection *)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass;
+ (UITraitCollection *)traitCollectionWithVerticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass;
+ (UITraitCollection *)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)userInterfaceStyle;
+ (UITraitCollection *)traitCollectionWithLayoutDirection:(UIUserInterfaceLayoutDirection)layoutDirection;
+ (UITraitCollection *)traitCollectionWithPreferredContentSizeCategory:(UIContentSizeCategory)preferredContentSizeCategory;
+ (UITraitCollection *)traitCollectionWithForceTouchCapability:(UIForceTouchCapability)capability;
+ (UITraitCollection *)traitCollectionWithDisplayGamut:(UIDisplayGamut)displayGamut;
+ (UITraitCollection *)traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)accessibilityContrast;
+ (UITraitCollection *)traitCollectionWithLegibilityWeight:(UILegibilityWeight)legibilityWeight;
+ (UITraitCollection *)traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)userInterfaceLevel;

- (BOOL)containsTraitsInCollection:(UITraitCollection *)trait;
- (BOOL)hasDifferentColorAppearanceComparedToTraitCollection:(UITraitCollection *)traitCollection;

@property (nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, readonly) UIUserInterfaceStyle userInterfaceStyle;
@property (nonatomic, readonly) UIUserInterfaceLayoutDirection layoutDirection;
@property (nonatomic, readonly) CGFloat displayScale;
@property (nonatomic, readonly) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic, readonly) UIUserInterfaceSizeClass verticalSizeClass;
@property (nonatomic, readonly) UIForceTouchCapability forceTouchCapability;
@property (nonatomic, readonly, copy) UIContentSizeCategory preferredContentSizeCategory;
@property (nonatomic, readonly) UIDisplayGamut displayGamut;
@property (nonatomic, readonly) UIAccessibilityContrast accessibilityContrast;
@property (nonatomic, readonly) UIUserInterfaceLevel userInterfaceLevel;
@property (nonatomic, readonly) UILegibilityWeight legibilityWeight;
@property (nonatomic, readonly) UIUserInterfaceActiveAppearance activeAppearance;

/* What dynamic colors resolve against. */
@property (class, nonatomic, strong) UITraitCollection *currentTraitCollection;
- (void)performAsCurrentTraitCollection:(void (^)(void))actions;
@end

@protocol UITraitEnvironment <NSObject>
@property (nonatomic, readonly) UITraitCollection *traitCollection;
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection;
@end

/* A view's traits are its controller's or superview's, with its own
   override of the appearance. */
@interface UIView (UITraitEnvironment) <UITraitEnvironment>
@property (nonatomic) UIUserInterfaceStyle overrideUserInterfaceStyle;
@end

@interface UIViewController (UITraitEnvironment) <UITraitEnvironment>
@property (nonatomic) UIUserInterfaceStyle overrideUserInterfaceStyle;
- (void)setOverrideTraitCollection:(UITraitCollection *)collection forChildViewController:(UIViewController *)childViewController;
- (UITraitCollection *)overrideTraitCollectionForChildViewController:(UIViewController *)childViewController;
@end

@interface UIScreen (UITraitEnvironment) <UITraitEnvironment>
@end

#endif /* UIKIT_UITRAITCOLLECTION_H */
