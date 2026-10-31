/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIStackView.h>
#import "UIKitPrivate.h"

const CGFloat UIStackViewSpacingUseDefault = 3.40282347e+38F;
const CGFloat UIStackViewSpacingUseSystem = 1.17549435e-38F;

@interface UIStackView ()
- (void)uikitArrangedSubviewVisibilityChanged;
@end

/* A shown or hidden arranged subview gives up or takes back its room. */
@implementation UIView (UIStackViewHiding)

- (void)setHidden:(BOOL)hidden
{
	BOOL was = [self isHidden];
	[super setHidden:hidden];
	NSView *superview = [self superview];
	if (was != hidden && [superview isKindOfClass:[UIStackView class]])
		[(UIStackView *)superview uikitArrangedSubviewVisibilityChanged];
}

@end

static NSLayoutConstraint *UIKitConstraint(id first, NSLayoutAttribute firstAttribute, NSLayoutRelation relation,
	id second, NSLayoutAttribute secondAttribute, CGFloat multiplier, CGFloat constant, UILayoutPriority priority)
{
	NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:first attribute:firstAttribute relatedBy:relation
		toItem:second attribute:secondAttribute multiplier:multiplier constant:constant];
	[constraint setPriority:priority];
	return constraint;
}

@implementation UIStackView {
	NSMutableArray<UIView *> *_arranged;
	NSMapTable<UIView *, NSNumber *> *_customSpacing;
	NSMutableArray<NSLayoutConstraint *> *_constraints;
	NSMutableArray<UILayoutGuide *> *_spacers;
	UILayoutConstraintAxis _axis;
	UIStackViewDistribution _distribution;
	UIStackViewAlignment _alignment;
	CGFloat _spacing;
	BOOL _baselineRelative;
	BOOL _marginsRelative;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_arranged = [NSMutableArray array];
		_customSpacing = [NSMapTable weakToStrongObjectsMapTable];
		_constraints = [NSMutableArray array];
		_spacers = [NSMutableArray array];
	}
	return self;
}

- (instancetype)initWithArrangedSubviews:(NSArray<UIView *> *)views
{
	if ((self = [self initWithFrame:CGRectZero]))
		for (UIView *view in views)
			[self addArrangedSubview:view];
	return self;
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	_arranged = [NSMutableArray array];
	_customSpacing = [NSMapTable weakToStrongObjectsMapTable];
	_constraints = [NSMutableArray array];
	_spacers = [NSMutableArray array];
	_axis = [coder decodeIntegerForKey:@"UIStackViewAxis"];
	_distribution = [coder decodeIntegerForKey:@"UIStackViewDistribution"];
	_alignment = [coder decodeIntegerForKey:@"UIStackViewAlignment"];
	_spacing = [coder decodeDoubleForKey:@"UIStackViewSpacing"];
	_baselineRelative = [coder decodeBoolForKey:@"UIStackViewBaselineRelative"];
	_marginsRelative = [coder decodeBoolForKey:@"UIStackViewLayoutMarginsRelative"];
	for (UIView *view in [coder decodeObjectForKey:@"UIStackViewArrangedSubviews"])
		if ([view isKindOfClass:[UIView class]])
			[_arranged addObject:view];
	for (UIView *view in _arranged) {
		[view setTranslatesAutoresizingMaskIntoConstraints:NO];
		if ([view superview] != self)
			[self addSubview:view];
	}
	[self uikitRebuild];
}

- (NSArray<UIView *> *)arrangedSubviews { return [_arranged copy]; }
- (UILayoutConstraintAxis)axis { return _axis; }
- (UIStackViewDistribution)distribution { return _distribution; }
- (UIStackViewAlignment)alignment { return _alignment; }
- (CGFloat)spacing { return _spacing; }
- (BOOL)isBaselineRelativeArrangement { return _baselineRelative; }
- (BOOL)isLayoutMarginsRelativeArrangement { return _marginsRelative; }
- (void)setAxis:(UILayoutConstraintAxis)axis { _axis = axis; [self uikitRebuild]; }
- (void)setDistribution:(UIStackViewDistribution)distribution { _distribution = distribution; [self uikitRebuild]; }
- (void)setAlignment:(UIStackViewAlignment)alignment { _alignment = alignment; [self uikitRebuild]; }
- (void)setSpacing:(CGFloat)spacing { _spacing = spacing; [self uikitRebuild]; }
- (void)setBaselineRelativeArrangement:(BOOL)relative { _baselineRelative = relative; }
- (void)setLayoutMarginsRelativeArrangement:(BOOL)relative { _marginsRelative = relative; [self uikitRebuild]; }

- (void)setCustomSpacing:(CGFloat)spacing afterView:(UIView *)view
{
	if (view == nil)
		return;
	if (spacing == UIStackViewSpacingUseDefault)
		[_customSpacing removeObjectForKey:view];
	else
		[_customSpacing setObject:@(spacing) forKey:view];
	[self uikitRebuild];
}

- (CGFloat)customSpacingAfterView:(UIView *)view
{
	NSNumber *spacing = [_customSpacing objectForKey:view];
	return spacing != nil ? [spacing doubleValue] : UIStackViewSpacingUseDefault;
}

- (void)addArrangedSubview:(UIView *)view
{
	[self insertArrangedSubview:view atIndex:[_arranged count]];
}

- (void)insertArrangedSubview:(UIView *)view atIndex:(NSUInteger)index
{
	if (view == nil)
		return;
	[_arranged removeObject:view];
	[_arranged insertObject:view atIndex:MIN(index, [_arranged count])];
	[view setTranslatesAutoresizingMaskIntoConstraints:NO];
	if ([view superview] != self)
		[self addSubview:view];
	[self uikitRebuild];
}

/* It stays a subview, as on iOS; only removeFromSuperview takes it away. */
- (void)removeArrangedSubview:(UIView *)view
{
	if (![_arranged containsObject:view])
		return;
	[_arranged removeObject:view];
	[self uikitRebuild];
}

- (void)willRemoveSubview:(UIView *)subview
{
	[super willRemoveSubview:subview];
	if ([_arranged containsObject:subview]) {
		[_arranged removeObject:subview];
		/* Its constraints go with it; the rest are remade once it is out. */
		dispatch_async(dispatch_get_main_queue(), ^{
			[self uikitRebuild];
		});
	}
}

- (void)uikitArrangedSubviewVisibilityChanged
{
	[self uikitRebuild];
}

- (CGFloat)uikitSpacingAfter:(UIView *)view
{
	NSNumber *custom = [_customSpacing objectForKey:view];
	CGFloat spacing = custom != nil ? [custom doubleValue] : _spacing;
	return spacing == UIStackViewSpacingUseSystem ? 8 : spacing;
}

/* Remakes every constraint the stack owns. */
- (void)uikitRebuild
{
	if (_constraints == nil)
		return;
	[NSLayoutConstraint deactivateConstraints:_constraints];
	[_constraints removeAllObjects];
	for (UILayoutGuide *spacer in _spacers)
		[self removeLayoutGuide:spacer];
	[_spacers removeAllObjects];

	NSMutableArray<UIView *> *views = [NSMutableArray array];
	for (UIView *view in _arranged)
		if (![view isHidden] && [view superview] == self)
			[views addObject:view];
	if ([views count] == 0) {
		[self setNeedsLayout];
		return;
	}

	BOOL horizontal = _axis == UILayoutConstraintAxisHorizontal;
	NSLayoutAttribute leading = horizontal ? NSLayoutAttributeLeading : NSLayoutAttributeTop;
	NSLayoutAttribute trailing = horizontal ? NSLayoutAttributeTrailing : NSLayoutAttributeBottom;
	NSLayoutAttribute length = horizontal ? NSLayoutAttributeWidth : NSLayoutAttributeHeight;
	NSLayoutAttribute center = horizontal ? NSLayoutAttributeCenterX : NSLayoutAttributeCenterY;
	NSLayoutAttribute crossStart = horizontal ? NSLayoutAttributeTop : NSLayoutAttributeLeading;
	NSLayoutAttribute crossEnd = horizontal ? NSLayoutAttributeBottom : NSLayoutAttributeTrailing;
	NSLayoutAttribute crossCenter = horizontal ? NSLayoutAttributeCenterY : NSLayoutAttributeCenterX;
	NSLayoutAttribute crossLength = horizontal ? NSLayoutAttributeHeight : NSLayoutAttributeWidth;
	id edges = _marginsRelative ? (id)[self layoutMarginsGuide] : (id)self;
	NSMutableArray<NSLayoutConstraint *> *made = _constraints;
	CGFloat required = UILayoutPriorityRequired;

	/* Along the axis: end to end, the ends at the stack's edges. */
	[made addObject:UIKitConstraint([views firstObject], leading, NSLayoutRelationEqual, edges, leading, 1, 0, required)];
	[made addObject:UIKitConstraint([views lastObject], trailing, NSLayoutRelationEqual, edges, trailing, 1, 0, required)];
	UILayoutGuide *firstSpacer = nil;
	for (NSUInteger i = 1; i < [views count]; i++) {
		UIView *before = [views objectAtIndex:i - 1], *view = [views objectAtIndex:i];
		CGFloat spacing = [self uikitSpacingAfter:before];
		if (_distribution == UIStackViewDistributionEqualSpacing || _distribution == UIStackViewDistributionEqualCentering) {
			/* Equal gaps (or equal distances between centers), at least
			   the spacing apart. */
			BOOL centers = _distribution == UIStackViewDistributionEqualCentering;
			UILayoutGuide *spacer = [[UILayoutGuide alloc] init];
			[self addLayoutGuide:spacer];
			[_spacers addObject:spacer];
			[made addObject:UIKitConstraint(spacer, leading, NSLayoutRelationEqual, before, centers ? center : trailing, 1, 0, required)];
			[made addObject:UIKitConstraint(spacer, trailing, NSLayoutRelationEqual, view, centers ? center : leading, 1, 0, required)];
			[made addObject:UIKitConstraint(view, leading, NSLayoutRelationGreaterThanOrEqual, before, trailing, 1, spacing, required)];
			if (firstSpacer != nil)
				[made addObject:UIKitConstraint(spacer, length, NSLayoutRelationEqual, firstSpacer, length, 1, 0, required)];
			else
				firstSpacer = spacer;
		} else {
			[made addObject:UIKitConstraint(view, leading, NSLayoutRelationEqual, before, trailing, 1, spacing, required)];
		}
	}
	UIView *first = [views firstObject];
	if (_distribution == UIStackViewDistributionFillEqually) {
		for (NSUInteger i = 1; i < [views count]; i++)
			[made addObject:UIKitConstraint([views objectAtIndex:i], length, NSLayoutRelationEqual, first, length, 1, 0, required)];
	} else if (_distribution == UIStackViewDistributionFillProportionally) {
		/* In proportion to their intrinsic lengths, when they have them. */
		NSSize firstSize = [first intrinsicContentSize];
		CGFloat firstLength = horizontal ? firstSize.width : firstSize.height;
		for (NSUInteger i = 1; i < [views count] && firstLength > 0; i++) {
			NSSize size = [[views objectAtIndex:i] intrinsicContentSize];
			CGFloat viewLength = horizontal ? size.width : size.height;
			if (viewLength > 0)
				[made addObject:UIKitConstraint([views objectAtIndex:i], length, NSLayoutRelationEqual, first, length,
					viewLength / firstLength, 0, UILayoutPriorityRequired - 1)];
		}
	}

	/* Across it: as the alignment says, and never past the edges. */
	for (UIView *view in views) {
		switch (_alignment) {
		case UIStackViewAlignmentFill:
			[made addObject:UIKitConstraint(view, crossStart, NSLayoutRelationEqual, edges, crossStart, 1, 0, required)];
			[made addObject:UIKitConstraint(view, crossEnd, NSLayoutRelationEqual, edges, crossEnd, 1, 0, required)];
			break;
		case UIStackViewAlignmentLeading:
		case UIStackViewAlignmentFirstBaseline:
			[made addObject:UIKitConstraint(view, crossStart, NSLayoutRelationEqual, edges, crossStart, 1, 0, required)];
			[made addObject:UIKitConstraint(view, crossEnd, NSLayoutRelationLessThanOrEqual, edges, crossEnd, 1, 0, required)];
			break;
		case UIStackViewAlignmentTrailing:
		case UIStackViewAlignmentLastBaseline:
			[made addObject:UIKitConstraint(view, crossEnd, NSLayoutRelationEqual, edges, crossEnd, 1, 0, required)];
			[made addObject:UIKitConstraint(view, crossStart, NSLayoutRelationGreaterThanOrEqual, edges, crossStart, 1, 0, required)];
			break;
		case UIStackViewAlignmentCenter:
			[made addObject:UIKitConstraint(view, crossCenter, NSLayoutRelationEqual, edges, crossCenter, 1, 0, required)];
			[made addObject:UIKitConstraint(view, crossStart, NSLayoutRelationGreaterThanOrEqual, edges, crossStart, 1, 0, required)];
			break;
		}
	}
	/* Otherwise as small across as its largest view, as iOS's hugs. */
	if (_alignment != UIStackViewAlignmentFill)
		[made addObject:UIKitConstraint(self, crossLength, NSLayoutRelationEqual, nil, NSLayoutAttributeNotAnAttribute, 1, 0, UILayoutPriorityFittingSizeLevel - 1)];

	[NSLayoutConstraint activateConstraints:made];
	[self setNeedsLayout];
}

@end
