/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UILAYOUTGUIDE_H
#define UIKIT_UILAYOUTGUIDE_H

#import <Foundation/Foundation.h>
#import <AppKit/NSLayoutGuide.h>
#import <AppKit/NSLayoutConstraint.h>
#import <Foundation/NSLayoutAnchor.h>
#import <UIKit/UIView.h>
#import <UIKit/UIGeometry.h>

typedef float UILayoutPriority;
static const UILayoutPriority UILayoutPriorityRequired = 1000;
static const UILayoutPriority UILayoutPriorityDefaultHigh = 750;
static const UILayoutPriority UILayoutPriorityDefaultLow = 250;
static const UILayoutPriority UILayoutPriorityFittingSizeLevel = 50;

typedef NS_ENUM(NSInteger, UILayoutConstraintAxis) {
	UILayoutConstraintAxisHorizontal = 0,
	UILayoutConstraintAxisVertical = 1,
};

extern const NSDirectionalEdgeInsets NSDirectionalEdgeInsetsZero;
extern const CGSize UILayoutFittingCompressedSize;
extern const CGSize UILayoutFittingExpandedSize;

/* A rectangle constraints can position, solved by AppKit's layout. */
@interface UILayoutGuide : NSLayoutGuide
@property (nonatomic, readonly) CGRect layoutFrame;
@end

@interface UIView (UIConstraintBasedLayout)
+ (BOOL)requiresConstraintBasedLayout;
@property (nonatomic, readonly) UILayoutGuide *safeAreaLayoutGuide;
@property (nonatomic, readonly) UILayoutGuide *layoutMarginsGuide;
@property (nonatomic, readonly) UILayoutGuide *readableContentGuide;
@property (nonatomic, readonly) UIEdgeInsets safeAreaInsets;
@property (nonatomic) UIEdgeInsets layoutMargins;
@property (nonatomic) NSDirectionalEdgeInsets directionalLayoutMargins;
@property (nonatomic) BOOL preservesSuperviewLayoutMargins;
@property (nonatomic) BOOL insetsLayoutMarginsFromSafeArea;
- (void)layoutMarginsDidChange;
- (void)safeAreaInsetsDidChange;
- (void)setNeedsUpdateConstraints;
- (void)updateConstraintsIfNeeded;
- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize;
- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize withHorizontalFittingPriority:(UILayoutPriority)horizontalPriority verticalFittingPriority:(UILayoutPriority)verticalPriority;
- (UILayoutPriority)contentHuggingPriorityForAxis:(UILayoutConstraintAxis)axis;
- (void)setContentHuggingPriority:(UILayoutPriority)priority forAxis:(UILayoutConstraintAxis)axis;
- (UILayoutPriority)contentCompressionResistancePriorityForAxis:(UILayoutConstraintAxis)axis;
- (void)setContentCompressionResistancePriority:(UILayoutPriority)priority forAxis:(UILayoutConstraintAxis)axis;
- (NSArray<NSLayoutConstraint *> *)constraintsAffectingLayoutForAxis:(UILayoutConstraintAxis)axis;
- (BOOL)hasAmbiguousLayout;
@end

#endif /* UIKIT_UILAYOUTGUIDE_H */
