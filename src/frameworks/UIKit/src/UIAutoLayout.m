/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UILayoutGuide.h>
#import <UIKit/UILabel.h>
#import <UIKit/UIImageView.h>
#import <UIKit/UIControl.h>
#import <UIKit/UISlider.h>
#import <UIKit/UIProgressView.h>
#import <UIKit/UITextField.h>
#import "UIKitPrivate.h"
#import <objc/runtime.h>

/*
 * Auto Layout is AppKit's (Cocotron's solver runs when a window lays out);
 * this is iOS's API on top of it: layout guides, margins, the axis-named
 * priorities, and the intrinsic sizes iOS's views report.
 */

const NSDirectionalEdgeInsets NSDirectionalEdgeInsetsZero = { 0, 0, 0, 0 };
const CGSize UILayoutFittingCompressedSize = { 0, 0 };
const CGSize UILayoutFittingExpandedSize = { 10000, 10000 };

@implementation UILayoutGuide

- (CGRect)layoutFrame
{
	return NSRectToCGRect([self frame]);
}

@end

/* A guide pinned inside its view by four constraints whose constants are the insets. */
@interface UIKitInsetGuide : NSObject {
@public
	UILayoutGuide *guide;
	NSLayoutConstraint *top, *left, *bottom, *right;
}
@end

@implementation UIKitInsetGuide
@end

static char UIKitSafeAreaGuideKey, UIKitMarginsGuideKey, UIKitReadableGuideKey, UIKitMarginsKey, UIKitLayoutFlagsKey;

static UIKitInsetGuide *UIKitGuide(UIView *view, const void *key, NSString *identifier, UIEdgeInsets insets)
{
	UIKitInsetGuide *entry = objc_getAssociatedObject(view, key);
	if (entry != nil)
		return entry;
	entry = [[UIKitInsetGuide alloc] init];
	entry->guide = [[UILayoutGuide alloc] init];
	[entry->guide setIdentifier:identifier];
	[view addLayoutGuide:entry->guide];
	entry->top = [[entry->guide topAnchor] constraintEqualToAnchor:[view topAnchor] constant:insets.top];
	entry->left = [[entry->guide leftAnchor] constraintEqualToAnchor:[view leftAnchor] constant:insets.left];
	entry->bottom = [[view bottomAnchor] constraintEqualToAnchor:[entry->guide bottomAnchor] constant:insets.bottom];
	entry->right = [[view rightAnchor] constraintEqualToAnchor:[entry->guide rightAnchor] constant:insets.right];
	[NSLayoutConstraint activateConstraints:@[ entry->top, entry->left, entry->bottom, entry->right ]];
	objc_setAssociatedObject(view, key, entry, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return entry;
}

static void UIKitSetGuideInsets(UIKitInsetGuide *entry, UIEdgeInsets insets)
{
	if (entry == nil)
		return;
	[entry->top setConstant:insets.top];
	[entry->left setConstant:insets.left];
	[entry->bottom setConstant:insets.bottom];
	[entry->right setConstant:insets.right];
}

/* Flags kept per view: bit 0 preserves the superview's margins, bit 1
 * clears insetting margins from the safe area. */
static NSUInteger UIKitLayoutFlags(UIView *view)
{
	return [objc_getAssociatedObject(view, &UIKitLayoutFlagsKey) unsignedIntegerValue];
}

static void UIKitSetLayoutFlag(UIView *view, NSUInteger flag, BOOL on)
{
	NSUInteger flags = UIKitLayoutFlags(view);
	flags = on ? (flags | flag) : (flags & ~flag);
	objc_setAssociatedObject(view, &UIKitLayoutFlagsKey, @(flags), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UIView (UIConstraintBasedLayout)

+ (BOOL)requiresConstraintBasedLayout { return NO; }

/* Views here are not under a status bar or a home indicator. */
- (UIEdgeInsets)safeAreaInsets { return UIEdgeInsetsZero; }
- (void)safeAreaInsetsDidChange { }

- (UILayoutGuide *)safeAreaLayoutGuide
{
	return UIKitGuide(self, &UIKitSafeAreaGuideKey, @"UIViewSafeAreaLayoutGuide", [self safeAreaInsets])->guide;
}

- (UIEdgeInsets)layoutMargins
{
	NSValue *value = objc_getAssociatedObject(self, &UIKitMarginsKey);
	if (value == nil)
		return UIEdgeInsetsMake(8, 8, 8, 8);
	UIEdgeInsets insets;
	[value getValue:&insets];
	return insets;
}

- (void)setLayoutMargins:(UIEdgeInsets)margins
{
	objc_setAssociatedObject(self, &UIKitMarginsKey, [NSValue valueWithBytes:&margins objCType:@encode(UIEdgeInsets)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	UIKitSetGuideInsets(objc_getAssociatedObject(self, &UIKitMarginsGuideKey), margins);
	[self layoutMarginsDidChange];
}

- (NSDirectionalEdgeInsets)directionalLayoutMargins
{
	UIEdgeInsets margins = [self layoutMargins];
	NSDirectionalEdgeInsets directional = { margins.top, margins.left, margins.bottom, margins.right };
	return directional;
}

- (void)setDirectionalLayoutMargins:(NSDirectionalEdgeInsets)margins
{
	[self setLayoutMargins:UIEdgeInsetsMake(margins.top, margins.leading, margins.bottom, margins.trailing)];
}

- (void)layoutMarginsDidChange { }
- (BOOL)preservesSuperviewLayoutMargins { return (UIKitLayoutFlags(self) & 1) != 0; }
- (void)setPreservesSuperviewLayoutMargins:(BOOL)preserves { UIKitSetLayoutFlag(self, 1, preserves); }
- (BOOL)insetsLayoutMarginsFromSafeArea { return (UIKitLayoutFlags(self) & 2) == 0; }
- (void)setInsetsLayoutMarginsFromSafeArea:(BOOL)insets { UIKitSetLayoutFlag(self, 2, !insets); }

- (UILayoutGuide *)layoutMarginsGuide
{
	return UIKitGuide(self, &UIKitMarginsGuideKey, @"UIViewLayoutMarginsGuide", [self layoutMargins])->guide;
}

/* Text no wider than reads well: margins, up to 672 points across. */
- (UILayoutGuide *)readableContentGuide
{
	UIEdgeInsets margins = [self layoutMargins];
	CGFloat width = [self bounds].size.width;
	CGFloat extra = MAX(0, (width - margins.left - margins.right - 672) / 2);
	return UIKitGuide(self, &UIKitReadableGuideKey, @"UIViewReadableContentGuide",
		UIEdgeInsetsMake(margins.top, margins.left + extra, margins.bottom, margins.right + extra))->guide;
}

- (void)setNeedsUpdateConstraints { [self setNeedsUpdateConstraints:YES]; }
- (void)updateConstraintsIfNeeded { [self updateConstraintsForSubtreeIfNeeded]; }

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize
{
	[self layoutSubtreeIfNeeded];
	NSSize intrinsic = [self intrinsicContentSize];
	CGSize fitted = [self sizeThatFits:targetSize];
	CGFloat width = intrinsic.width != UIViewNoIntrinsicMetric ? intrinsic.width : fitted.width;
	CGFloat height = intrinsic.height != UIViewNoIntrinsicMetric ? intrinsic.height : fitted.height;
	return CGSizeMake(width, height);
}

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize withHorizontalFittingPriority:(UILayoutPriority)horizontalPriority verticalFittingPriority:(UILayoutPriority)verticalPriority
{
	CGSize size = [self systemLayoutSizeFittingSize:targetSize];
	if (horizontalPriority >= UILayoutPriorityRequired)
		size.width = targetSize.width;
	if (verticalPriority >= UILayoutPriorityRequired)
		size.height = targetSize.height;
	return size;
}

- (UILayoutPriority)contentHuggingPriorityForAxis:(UILayoutConstraintAxis)axis
{
	return [self contentHuggingPriorityForOrientation:(NSLayoutConstraintOrientation)axis];
}

- (void)setContentHuggingPriority:(UILayoutPriority)priority forAxis:(UILayoutConstraintAxis)axis
{
	[self setContentHuggingPriority:priority forOrientation:(NSLayoutConstraintOrientation)axis];
}

- (UILayoutPriority)contentCompressionResistancePriorityForAxis:(UILayoutConstraintAxis)axis
{
	return [self contentCompressionResistancePriorityForOrientation:(NSLayoutConstraintOrientation)axis];
}

- (void)setContentCompressionResistancePriority:(UILayoutPriority)priority forAxis:(UILayoutConstraintAxis)axis
{
	[self setContentCompressionResistancePriority:priority forOrientation:(NSLayoutConstraintOrientation)axis];
}

- (NSArray *)constraintsAffectingLayoutForAxis:(UILayoutConstraintAxis)axis
{
	return [self constraints];
}

- (BOOL)hasAmbiguousLayout { return NO; }

@end

#pragma mark - Intrinsic sizes

@implementation UILabel (UIConstraintBasedLayout)

- (NSSize)intrinsicContentSize
{
	CGFloat width = [self numberOfLines] == 1 ? CGFLOAT_MAX : [self bounds].size.width;
	if ([self preferredMaxLayoutWidth] > 0)
		width = [self preferredMaxLayoutWidth];
	if (width <= 0)
		width = CGFLOAT_MAX;
	CGSize size = [self sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
	return NSMakeSize(ceil(size.width), ceil(size.height));
}

@end

@implementation UIImageView (UIConstraintBasedLayout)

- (NSSize)intrinsicContentSize
{
	UIImage *image = [self image];
	if (image == nil)
		return NSMakeSize(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric);
	CGSize size = [image size];
	return NSMakeSize(size.width, size.height);
}

@end

@implementation UISwitch (UIConstraintBasedLayout)
- (NSSize)intrinsicContentSize { return NSMakeSize(51, 31); }
@end

@implementation UISlider (UIConstraintBasedLayout)
- (NSSize)intrinsicContentSize { return NSMakeSize(UIViewNoIntrinsicMetric, 31); }
@end

@implementation UIProgressView (UIConstraintBasedLayout)
- (NSSize)intrinsicContentSize { return NSMakeSize(UIViewNoIntrinsicMetric, 2); }
@end

@implementation UIActivityIndicatorView (UIConstraintBasedLayout)

- (NSSize)intrinsicContentSize
{
	CGFloat side = [self activityIndicatorViewStyle] == UIActivityIndicatorViewStyleWhiteLarge ? 37 : 20;
	return NSMakeSize(side, side);
}

@end

@implementation UITextField (UIConstraintBasedLayout)

- (NSSize)intrinsicContentSize
{
	UIFont *font = [self font];
	CGFloat height = ceil([font lineHeight]) + ([self borderStyle] == UITextBorderStyleRoundedRect ? 13 : 4);
	return NSMakeSize(UIViewNoIntrinsicMetric, height);
}

@end
