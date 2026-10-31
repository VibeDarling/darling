/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISTACKVIEW_H
#define UIKIT_UISTACKVIEW_H

#import <UIKit/UIView.h>
#import <UIKit/UILayoutGuide.h>

typedef NS_ENUM(NSInteger, UIStackViewDistribution) {
	UIStackViewDistributionFill = 0,
	UIStackViewDistributionFillEqually,
	UIStackViewDistributionFillProportionally,
	UIStackViewDistributionEqualSpacing,
	UIStackViewDistributionEqualCentering,
};

typedef NS_ENUM(NSInteger, UIStackViewAlignment) {
	UIStackViewAlignmentFill,
	UIStackViewAlignmentLeading,
	UIStackViewAlignmentTop = UIStackViewAlignmentLeading,
	UIStackViewAlignmentFirstBaseline,
	UIStackViewAlignmentCenter,
	UIStackViewAlignmentTrailing,
	UIStackViewAlignmentBottom = UIStackViewAlignmentTrailing,
	UIStackViewAlignmentLastBaseline,
};

extern const CGFloat UIStackViewSpacingUseDefault;
extern const CGFloat UIStackViewSpacingUseSystem;

/*
 * Lays out its arranged subviews in a row or a column with constraints,
 * as iOS's does, so they size from their intrinsic sizes and the app's
 * own constraints. Hidden arranged subviews take no room. Baseline
 * alignments align the views' tops or bottoms.
 */
@interface UIStackView : UIView
- (instancetype)initWithArrangedSubviews:(NSArray<UIView *> *)views;
@property (nonatomic, readonly, copy) NSArray<UIView *> *arrangedSubviews;
- (void)addArrangedSubview:(UIView *)view;
- (void)removeArrangedSubview:(UIView *)view;
- (void)insertArrangedSubview:(UIView *)view atIndex:(NSUInteger)stackIndex;
@property (nonatomic) UILayoutConstraintAxis axis;
@property (nonatomic) UIStackViewDistribution distribution;
@property (nonatomic) UIStackViewAlignment alignment;
@property (nonatomic) CGFloat spacing;
- (void)setCustomSpacing:(CGFloat)spacing afterView:(UIView *)arrangedSubview;
- (CGFloat)customSpacingAfterView:(UIView *)arrangedSubview;
@property (nonatomic, getter=isBaselineRelativeArrangement) BOOL baselineRelativeArrangement;
@property (nonatomic, getter=isLayoutMarginsRelativeArrangement) BOOL layoutMarginsRelativeArrangement;
@end

#endif /* UIKIT_UISTACKVIEW_H */
