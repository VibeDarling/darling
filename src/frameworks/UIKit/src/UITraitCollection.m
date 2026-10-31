/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UITraitCollection.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIApplication.h>
#import <objc/runtime.h>
#import "UIKitPrivate.h"

UIContentSizeCategory const UIContentSizeCategoryUnspecified = @"_UICTContentSizeCategoryUnspecified";
UIContentSizeCategory const UIContentSizeCategoryExtraSmall = @"UICTContentSizeCategoryXS";
UIContentSizeCategory const UIContentSizeCategorySmall = @"UICTContentSizeCategoryS";
UIContentSizeCategory const UIContentSizeCategoryMedium = @"UICTContentSizeCategoryM";
UIContentSizeCategory const UIContentSizeCategoryLarge = @"UICTContentSizeCategoryL";
UIContentSizeCategory const UIContentSizeCategoryExtraLarge = @"UICTContentSizeCategoryXL";
UIContentSizeCategory const UIContentSizeCategoryExtraExtraLarge = @"UICTContentSizeCategoryXXL";
UIContentSizeCategory const UIContentSizeCategoryExtraExtraExtraLarge = @"UICTContentSizeCategoryXXXL";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityMedium = @"UICTContentSizeCategoryAccessibilityM";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityLarge = @"UICTContentSizeCategoryAccessibilityL";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityExtraLarge = @"UICTContentSizeCategoryAccessibilityXL";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityExtraExtraLarge = @"UICTContentSizeCategoryAccessibilityXXL";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityExtraExtraExtraLarge = @"UICTContentSizeCategoryAccessibilityXXXL";
NSNotificationName const UIContentSizeCategoryDidChangeNotification = @"UIContentSizeCategoryDidChangeNotification";

static NSInteger UIKitContentSizeRank(UIContentSizeCategory category)
{
	static NSArray *order;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		order = @[ UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall, UIContentSizeCategoryMedium,
			UIContentSizeCategoryLarge, UIContentSizeCategoryExtraLarge, UIContentSizeCategoryExtraExtraLarge,
			UIContentSizeCategoryExtraExtraExtraLarge, UIContentSizeCategoryAccessibilityMedium,
			UIContentSizeCategoryAccessibilityLarge, UIContentSizeCategoryAccessibilityExtraLarge,
			UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge ];
	});
	NSUInteger index = category != nil ? [order indexOfObject:category] : NSNotFound;
	return index == NSNotFound ? -1 : (NSInteger)index;
}

BOOL UIContentSizeCategoryIsAccessibilityCategory(UIContentSizeCategory category)
{
	return UIKitContentSizeRank(category) >= UIKitContentSizeRank(UIContentSizeCategoryAccessibilityMedium);
}

NSComparisonResult UIContentSizeCategoryCompareToCategory(UIContentSizeCategory lhs, UIContentSizeCategory rhs)
{
	NSInteger a = UIKitContentSizeRank(lhs), b = UIKitContentSizeRank(rhs);
	return a < b ? NSOrderedAscending : a > b ? NSOrderedDescending : NSOrderedSame;
}

/* Each trait's unspecified value, which a collection made from others
   leaves to the ones before it. */
#define UIKIT_LAYOUT_DIRECTION_UNSPECIFIED ((UIUserInterfaceLayoutDirection)-1)

@implementation UITraitCollection {
@public
	UIUserInterfaceIdiom _idiom;
	UIUserInterfaceStyle _style;
	UIUserInterfaceLayoutDirection _layoutDirection;
	CGFloat _displayScale;
	UIUserInterfaceSizeClass _horizontal;
	UIUserInterfaceSizeClass _vertical;
	UIForceTouchCapability _forceTouch;
	UIContentSizeCategory _category;
	UIDisplayGamut _gamut;
	UIAccessibilityContrast _contrast;
	UIUserInterfaceLevel _level;
	UILegibilityWeight _weight;
	UIUserInterfaceActiveAppearance _active;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_idiom = UIUserInterfaceIdiomUnspecified;
		_style = UIUserInterfaceStyleUnspecified;
		_layoutDirection = UIKIT_LAYOUT_DIRECTION_UNSPECIFIED;
		_category = UIContentSizeCategoryUnspecified;
		_gamut = UIDisplayGamutUnspecified;
		_contrast = UIAccessibilityContrastUnspecified;
		_level = UIUserInterfaceLevelUnspecified;
		_weight = UILegibilityWeightUnspecified;
		_active = UIUserInterfaceActiveAppearanceUnspecified;
	}
	return self;
}

+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

/* Every trait of other that it specifies, over self's. */
- (void)uikitTakeTraitsFrom:(UITraitCollection *)other
{
	if (other->_idiom != UIUserInterfaceIdiomUnspecified) _idiom = other->_idiom;
	if (other->_style != UIUserInterfaceStyleUnspecified) _style = other->_style;
	if (other->_layoutDirection != UIKIT_LAYOUT_DIRECTION_UNSPECIFIED) _layoutDirection = other->_layoutDirection;
	if (other->_displayScale != 0) _displayScale = other->_displayScale;
	if (other->_horizontal != UIUserInterfaceSizeClassUnspecified) _horizontal = other->_horizontal;
	if (other->_vertical != UIUserInterfaceSizeClassUnspecified) _vertical = other->_vertical;
	if (other->_forceTouch != UIForceTouchCapabilityUnknown) _forceTouch = other->_forceTouch;
	if (![other->_category isEqualToString:UIContentSizeCategoryUnspecified]) _category = other->_category;
	if (other->_gamut != UIDisplayGamutUnspecified) _gamut = other->_gamut;
	if (other->_contrast != UIAccessibilityContrastUnspecified) _contrast = other->_contrast;
	if (other->_level != UIUserInterfaceLevelUnspecified) _level = other->_level;
	if (other->_weight != UILegibilityWeightUnspecified) _weight = other->_weight;
	if (other->_active != UIUserInterfaceActiveAppearanceUnspecified) _active = other->_active;
}

+ (UITraitCollection *)traitCollectionWithTraitsFromCollections:(NSArray<UITraitCollection *> *)traitCollections
{
	UITraitCollection *collection = [[UITraitCollection alloc] init];
	for (UITraitCollection *other in traitCollections)
		[collection uikitTakeTraitsFrom:other];
	return collection;
}

#define UIKIT_TRAIT_CONSTRUCTOR(selector, type, ivar) \
	+ (UITraitCollection *)selector:(type)value \
	{ \
		UITraitCollection *collection = [[UITraitCollection alloc] init]; \
		collection->ivar = value; \
		return collection; \
	}
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithUserInterfaceIdiom, UIUserInterfaceIdiom, _idiom)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithDisplayScale, CGFloat, _displayScale)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithHorizontalSizeClass, UIUserInterfaceSizeClass, _horizontal)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithVerticalSizeClass, UIUserInterfaceSizeClass, _vertical)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithUserInterfaceStyle, UIUserInterfaceStyle, _style)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithLayoutDirection, UIUserInterfaceLayoutDirection, _layoutDirection)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithForceTouchCapability, UIForceTouchCapability, _forceTouch)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithDisplayGamut, UIDisplayGamut, _gamut)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithAccessibilityContrast, UIAccessibilityContrast, _contrast)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithLegibilityWeight, UILegibilityWeight, _weight)
UIKIT_TRAIT_CONSTRUCTOR(traitCollectionWithUserInterfaceLevel, UIUserInterfaceLevel, _level)
#undef UIKIT_TRAIT_CONSTRUCTOR

+ (UITraitCollection *)traitCollectionWithPreferredContentSizeCategory:(UIContentSizeCategory)category
{
	UITraitCollection *collection = [[UITraitCollection alloc] init];
	collection->_category = [category copy] ?: UIContentSizeCategoryUnspecified;
	return collection;
}

/* The device's: the screen's size decides the size classes, as on an
   iPhone (only the big ones are regular wide in landscape). */
+ (UITraitCollection *)uikitDeviceTraits
{
	UITraitCollection *collection = [[UITraitCollection alloc] init];
	CGRect bounds = [[UIScreen mainScreen] bounds];
	BOOL landscape = bounds.size.width > bounds.size.height;
	collection->_idiom = UIUserInterfaceIdiomPhone;
	collection->_style = UIUserInterfaceStyleLight;
	collection->_layoutDirection = UIUserInterfaceLayoutDirectionLeftToRight;
	collection->_displayScale = [[UIScreen mainScreen] scale];
	collection->_horizontal = landscape && bounds.size.width >= 736 ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact;
	collection->_vertical = landscape ? UIUserInterfaceSizeClassCompact : UIUserInterfaceSizeClassRegular;
	collection->_forceTouch = UIForceTouchCapabilityUnavailable;
	collection->_category = UIContentSizeCategoryLarge;
	collection->_gamut = UIDisplayGamutSRGB;
	collection->_contrast = UIAccessibilityContrastNormal;
	collection->_level = UIUserInterfaceLevelBase;
	collection->_weight = UILegibilityWeightRegular;
	collection->_active = UIUserInterfaceActiveAppearanceActive;
	return collection;
}

static UITraitCollection *sCurrentTraitCollection;

+ (UITraitCollection *)currentTraitCollection
{
	return sCurrentTraitCollection ?: [self uikitDeviceTraits];
}

+ (void)setCurrentTraitCollection:(UITraitCollection *)collection
{
	sCurrentTraitCollection = collection;
}

- (void)performAsCurrentTraitCollection:(void (^)(void))actions
{
	UITraitCollection *previous = sCurrentTraitCollection;
	sCurrentTraitCollection = self;
	@try {
		if (actions != nil)
			actions();
	} @finally {
		sCurrentTraitCollection = previous;
	}
}

- (BOOL)containsTraitsInCollection:(UITraitCollection *)other
{
	if (other == nil)
		return YES;
	UITraitCollection *merged = [UITraitCollection traitCollectionWithTraitsFromCollections:@[ self, other ]];
	return [merged isEqual:self];
}

- (BOOL)hasDifferentColorAppearanceComparedToTraitCollection:(UITraitCollection *)other
{
	return other == nil || _style != other->_style || _contrast != other->_contrast || _level != other->_level || _gamut != other->_gamut;
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[UITraitCollection class]])
		return NO;
	UITraitCollection *other = object;
	return _idiom == other->_idiom && _style == other->_style && _layoutDirection == other->_layoutDirection
		&& _displayScale == other->_displayScale && _horizontal == other->_horizontal && _vertical == other->_vertical
		&& _forceTouch == other->_forceTouch && [_category isEqualToString:other->_category] && _gamut == other->_gamut
		&& _contrast == other->_contrast && _level == other->_level && _weight == other->_weight && _active == other->_active;
}

- (NSUInteger)hash
{
	return (NSUInteger)_style * 31 + (NSUInteger)_horizontal * 7 + (NSUInteger)_vertical + (NSUInteger)_displayScale;
}

- (UIUserInterfaceIdiom)userInterfaceIdiom { return _idiom; }
- (UIUserInterfaceStyle)userInterfaceStyle { return _style; }
- (UIUserInterfaceLayoutDirection)layoutDirection { return _layoutDirection; }
- (CGFloat)displayScale { return _displayScale; }
- (UIUserInterfaceSizeClass)horizontalSizeClass { return _horizontal; }
- (UIUserInterfaceSizeClass)verticalSizeClass { return _vertical; }
- (UIForceTouchCapability)forceTouchCapability { return _forceTouch; }
- (UIContentSizeCategory)preferredContentSizeCategory { return _category; }
- (UIDisplayGamut)displayGamut { return _gamut; }
- (UIAccessibilityContrast)accessibilityContrast { return _contrast; }
- (UIUserInterfaceLevel)userInterfaceLevel { return _level; }
- (UILegibilityWeight)legibilityWeight { return _weight; }
- (UIUserInterfaceActiveAppearance)activeAppearance { return _active; }

- (NSString *)description
{
	return [NSString stringWithFormat:@"<UITraitCollection: %p; UserInterfaceIdiom = %ld, DisplayScale = %g, HorizontalSizeClass = %ld, VerticalSizeClass = %ld, UserInterfaceStyle = %ld, PreferredContentSizeCategory = %@>",
		self, (long)_idiom, _displayScale, (long)_horizontal, (long)_vertical, (long)_style, _category];
}

@end

#pragma mark - Trait environments

static char UIKitOverrideStyleKey;

static UIUserInterfaceStyle UIKitOverrideStyle(id object)
{
	return [objc_getAssociatedObject(object, &UIKitOverrideStyleKey) integerValue];
}

static UITraitCollection *UIKitTraitsWithStyle(UITraitCollection *traits, UIUserInterfaceStyle style)
{
	if (style == UIUserInterfaceStyleUnspecified)
		return traits;
	return [UITraitCollection traitCollectionWithTraitsFromCollections:@[ traits, [UITraitCollection traitCollectionWithUserInterfaceStyle:style] ]];
}

@implementation UIScreen (UITraitEnvironment)
- (UITraitCollection *)traitCollection { return [UITraitCollection uikitDeviceTraits]; }
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection { }
@end

@implementation UIView (UITraitEnvironment)

- (UITraitCollection *)traitCollection
{
	UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
	for (NSView *view = self; view != nil && style == UIUserInterfaceStyleUnspecified; view = [view superview])
		if ([view isKindOfClass:[UIView class]])
			style = UIKitOverrideStyle(view);
	return UIKitTraitsWithStyle([UITraitCollection uikitDeviceTraits], style);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection { }

- (UIUserInterfaceStyle)overrideUserInterfaceStyle { return UIKitOverrideStyle(self); }

static void UIKitSendTraitsChanged(NSView *view, NSMapTable *previous)
{
	if ([view isKindOfClass:[UIView class]]) {
		UITraitCollection *before = [previous objectForKey:view];
		if (![[(UIView *)view traitCollection] isEqual:before])
			[(UIView *)view traitCollectionDidChange:before];
	}
	for (NSView *subview in [view subviews])
		UIKitSendTraitsChanged(subview, previous);
}

static void UIKitRecordTraits(NSView *view, NSMapTable *previous)
{
	if ([view isKindOfClass:[UIView class]])
		[previous setObject:[(UIView *)view traitCollection] forKey:view];
	for (NSView *subview in [view subviews])
		UIKitRecordTraits(subview, previous);
}

- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)style
{
	if (style == UIKitOverrideStyle(self))
		return;
	NSMapTable *previous = [NSMapTable strongToStrongObjectsMapTable];
	UIKitRecordTraits(self, previous);
	objc_setAssociatedObject(self, &UIKitOverrideStyleKey, style == UIUserInterfaceStyleUnspecified ? nil : @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	UIKitSendTraitsChanged(self, previous);
}

@end

static char UIKitChildOverridesKey;

@implementation UIViewController (UITraitEnvironment)

- (UITraitCollection *)traitCollection
{
	UITraitCollection *traits = [UITraitCollection uikitDeviceTraits];
	UIViewController *parent = [self parentViewController] ?: [self presentingViewController];
	if (parent != nil) {
		traits = [parent traitCollection];
		UITraitCollection *forChild = [parent overrideTraitCollectionForChildViewController:self];
		if (forChild != nil)
			traits = [UITraitCollection traitCollectionWithTraitsFromCollections:@[ traits, forChild ]];
	}
	return UIKitTraitsWithStyle(traits, UIKitOverrideStyle(self));
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection { }

- (UIUserInterfaceStyle)overrideUserInterfaceStyle { return UIKitOverrideStyle(self); }

/* The controllers below this one, which inherit its traits. */
static void UIKitControllerTraitsChanged(UIViewController *controller, NSMapTable *previous)
{
	UITraitCollection *before = [previous objectForKey:controller];
	if (![[controller traitCollection] isEqual:before])
		[controller traitCollectionDidChange:before];
	for (UIViewController *child in [controller childViewControllers])
		UIKitControllerTraitsChanged(child, previous);
	if ([controller presentedViewController] != nil)
		UIKitControllerTraitsChanged([controller presentedViewController], previous);
}

static void UIKitRecordControllerTraits(UIViewController *controller, NSMapTable *previous)
{
	[previous setObject:[controller traitCollection] forKey:controller];
	for (UIViewController *child in [controller childViewControllers])
		UIKitRecordControllerTraits(child, previous);
	if ([controller presentedViewController] != nil)
		UIKitRecordControllerTraits([controller presentedViewController], previous);
}

- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)style
{
	if (style == UIKitOverrideStyle(self))
		return;
	NSMapTable *previous = [NSMapTable strongToStrongObjectsMapTable];
	UIKitRecordControllerTraits(self, previous);
	objc_setAssociatedObject(self, &UIKitOverrideStyleKey, style == UIUserInterfaceStyleUnspecified ? nil : @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	UIKitControllerTraitsChanged(self, previous);
	/* Its views take the controller's appearance, as on iOS. */
	if ([self isViewLoaded])
		[[self view] setOverrideUserInterfaceStyle:style];
}

- (void)setOverrideTraitCollection:(UITraitCollection *)collection forChildViewController:(UIViewController *)child
{
	if (child == nil)
		return;
	NSMapTable *overrides = objc_getAssociatedObject(self, &UIKitChildOverridesKey);
	if (overrides == nil) {
		overrides = [NSMapTable weakToStrongObjectsMapTable];
		objc_setAssociatedObject(self, &UIKitChildOverridesKey, overrides, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	NSMapTable *previous = [NSMapTable strongToStrongObjectsMapTable];
	UIKitRecordControllerTraits(child, previous);
	if (collection != nil)
		[overrides setObject:collection forKey:child];
	else
		[overrides removeObjectForKey:child];
	UIKitControllerTraitsChanged(child, previous);
}

- (UITraitCollection *)overrideTraitCollectionForChildViewController:(UIViewController *)child
{
	return [objc_getAssociatedObject(self, &UIKitChildOverridesKey) objectForKey:child];
}

@end
