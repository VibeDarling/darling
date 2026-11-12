/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UICollectionView.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UITouch.h>
#import "UIKitPrivate.h"
#include <float.h>

@interface UICollectionReusableView ()
- (void)uikitSetReuseIdentifier:(NSString *)identifier;
@end

@interface UICollectionView ()
- (void)uikitLayoutInvalidated;
@end

/*
 * A collection view asks its layout where every element goes, then keeps
 * views only for those in sight: scrolling moves the rest into reuse
 * queues and dequeues them for elements coming into view.
 */

#pragma mark - UICollectionViewLayoutAttributes

@implementation UICollectionViewLayoutAttributes {
	UICollectionElementCategory _category;
	NSString *_kind;
}

@synthesize frame = _frame;
@synthesize transform = _transform;
@synthesize alpha = _alpha;
@synthesize zIndex = _zIndex;
@synthesize hidden = _hidden;
@synthesize indexPath = _indexPath;

- (instancetype)init
{
	if ((self = [super init])) {
		_alpha = 1;
		_transform = CGAffineTransformIdentity;
	}
	return self;
}

+ (instancetype)uikitAttributesWithCategory:(UICollectionElementCategory)category kind:(NSString *)kind indexPath:(NSIndexPath *)indexPath
{
	UICollectionViewLayoutAttributes *attributes = [[self alloc] init];
	attributes->_category = category;
	attributes->_kind = [kind copy];
	attributes->_indexPath = indexPath;
	return attributes;
}

+ (instancetype)layoutAttributesForCellWithIndexPath:(NSIndexPath *)indexPath
{
	return [self uikitAttributesWithCategory:UICollectionElementCategoryCell kind:nil indexPath:indexPath];
}

+ (instancetype)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind withIndexPath:(NSIndexPath *)indexPath
{
	return [self uikitAttributesWithCategory:UICollectionElementCategorySupplementaryView kind:kind indexPath:indexPath];
}

+ (instancetype)layoutAttributesForDecorationViewOfKind:(NSString *)kind withIndexPath:(NSIndexPath *)indexPath
{
	return [self uikitAttributesWithCategory:UICollectionElementCategoryDecorationView kind:kind indexPath:indexPath];
}

- (id)copyWithZone:(NSZone *)zone
{
	UICollectionViewLayoutAttributes *copy = [[[self class] alloc] init];
	copy->_category = _category;
	copy->_kind = _kind;
	copy->_indexPath = _indexPath;
	copy->_frame = _frame;
	copy->_transform = _transform;
	copy->_alpha = _alpha;
	copy->_zIndex = _zIndex;
	copy->_hidden = _hidden;
	return copy;
}

- (UICollectionElementCategory)representedElementCategory { return _category; }
- (NSString *)representedElementKind { return _kind; }
- (CGPoint)center { return CGPointMake(CGRectGetMidX(_frame), CGRectGetMidY(_frame)); }

- (void)setCenter:(CGPoint)center
{
	_frame.origin = CGPointMake(center.x - _frame.size.width / 2, center.y - _frame.size.height / 2);
}

- (CGSize)size { return _frame.size; }
- (void)setSize:(CGSize)size { _frame.size = size; }
- (CGRect)bounds { return CGRectMake(0, 0, _frame.size.width, _frame.size.height); }
- (void)setBounds:(CGRect)bounds { _frame.size = bounds.size; }

- (BOOL)isEqual:(id)other
{
	if (![other isKindOfClass:[UICollectionViewLayoutAttributes class]])
		return NO;
	UICollectionViewLayoutAttributes *o = other;
	return o->_category == _category && [o->_indexPath isEqual:_indexPath] && (o->_kind == _kind || [o->_kind isEqual:_kind])
		&& CGRectEqualToRect(o->_frame, _frame) && o->_alpha == _alpha && o->_hidden == _hidden && o->_zIndex == _zIndex;
}

- (NSUInteger)hash { return [_indexPath hash] ^ _category; }

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p; index path: (%ld-%ld); frame = (%g %g; %g %g)>", [self class], self,
		(long)[_indexPath section], (long)[_indexPath item], _frame.origin.x, _frame.origin.y, _frame.size.width, _frame.size.height];
}

@end

#pragma mark - UICollectionViewLayout

@interface UICollectionViewLayout ()
- (void)uikitSetCollectionView:(UICollectionView *)collectionView;
@end

@implementation UICollectionViewLayout {
	__weak UICollectionView *_collectionView;
}

+ (Class)layoutAttributesClass { return [UICollectionViewLayoutAttributes class]; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [self init]))
		[self uikitDecodeNib:coder];
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder { }

- (UICollectionView *)collectionView { return _collectionView; }
- (void)uikitSetCollectionView:(UICollectionView *)collectionView { _collectionView = collectionView; }
- (void)prepareLayout { }
- (CGSize)collectionViewContentSize { return CGSizeZero; }
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect { return nil; }
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath { return nil; }
- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath { return nil; }
- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath { return nil; }
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds { return NO; }

- (void)invalidateLayout
{
	[_collectionView uikitLayoutInvalidated];
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)offset { return offset; }
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)offset withScrollingVelocity:(CGPoint)velocity { return offset; }
- (void)registerClass:(Class)viewClass forDecorationViewOfKind:(NSString *)kind { }
- (void)prepareForCollectionViewUpdates:(NSArray *)updateItems { }
- (void)finalizeCollectionViewUpdates { }
- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)indexPath { return [self layoutAttributesForItemAtIndexPath:indexPath]; }
- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)indexPath { return [self layoutAttributesForItemAtIndexPath:indexPath]; }

@end

#pragma mark - UICollectionViewFlowLayout

const CGSize UICollectionViewFlowLayoutAutomaticSize = { DBL_MAX, DBL_MAX };

static NSString *UIKitSupplementaryKey(NSString *kind, NSIndexPath *indexPath)
{
	return [NSString stringWithFormat:@"%@|%ld|%ld", kind, (long)[indexPath section], (long)[indexPath item]];
}

@implementation UICollectionViewFlowLayout {
	NSMutableArray<UICollectionViewLayoutAttributes *> *_all;
	NSMutableDictionary<NSIndexPath *, UICollectionViewLayoutAttributes *> *_items;
	NSMutableDictionary<NSString *, UICollectionViewLayoutAttributes *> *_supplementary;
	CGSize _contentSize;
	CGSize _preparedSize;
}

@synthesize minimumLineSpacing = _minimumLineSpacing;
@synthesize minimumInteritemSpacing = _minimumInteritemSpacing;
@synthesize itemSize = _itemSize;
@synthesize estimatedItemSize = _estimatedItemSize;
@synthesize scrollDirection = _scrollDirection;
@synthesize headerReferenceSize = _headerReferenceSize;
@synthesize footerReferenceSize = _footerReferenceSize;
@synthesize sectionInset = _sectionInset;
@synthesize sectionInsetReference = _sectionInsetReference;
@synthesize sectionHeadersPinToVisibleBounds = _sectionHeadersPinToVisibleBounds;
@synthesize sectionFootersPinToVisibleBounds = _sectionFootersPinToVisibleBounds;

- (instancetype)init
{
	if ((self = [super init])) {
		_minimumLineSpacing = 10;
		_minimumInteritemSpacing = 10;
		_itemSize = CGSizeMake(50, 50);
	}
	return self;
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	if ([coder containsValueForKey:@"UIItemSize"])
		_itemSize = [coder decodeCGSizeForKey:@"UIItemSize"];
	if ([coder containsValueForKey:@"UIEstimatedItemSize"])
		_estimatedItemSize = [coder decodeCGSizeForKey:@"UIEstimatedItemSize"];
	if ([coder containsValueForKey:@"UIMinimumLineSpacing"])
		_minimumLineSpacing = [coder decodeDoubleForKey:@"UIMinimumLineSpacing"];
	if ([coder containsValueForKey:@"UIMinimumInteritemSpacing"])
		_minimumInteritemSpacing = [coder decodeDoubleForKey:@"UIMinimumInteritemSpacing"];
	_scrollDirection = [coder decodeIntegerForKey:@"UIScrollDirection"];
	_headerReferenceSize = [coder decodeCGSizeForKey:@"UIHeaderReferenceSize"];
	_footerReferenceSize = [coder decodeCGSizeForKey:@"UIFooterReferenceSize"];
	_sectionInset = [coder decodeUIEdgeInsetsForKey:@"UISectionInset"];
}

- (void)setScrollDirection:(UICollectionViewScrollDirection)direction { _scrollDirection = direction; [self invalidateLayout]; }
- (void)setItemSize:(CGSize)size { _itemSize = size; [self invalidateLayout]; }
- (void)setSectionInset:(UIEdgeInsets)inset { _sectionInset = inset; [self invalidateLayout]; }
- (void)setMinimumLineSpacing:(CGFloat)spacing { _minimumLineSpacing = spacing; [self invalidateLayout]; }
- (void)setMinimumInteritemSpacing:(CGFloat)spacing { _minimumInteritemSpacing = spacing; [self invalidateLayout]; }
- (void)setHeaderReferenceSize:(CGSize)size { _headerReferenceSize = size; [self invalidateLayout]; }
- (void)setFooterReferenceSize:(CGSize)size { _footerReferenceSize = size; [self invalidateLayout]; }

- (void)prepareLayout
{
	[super prepareLayout];
	_all = [NSMutableArray array];
	_items = [NSMutableDictionary dictionary];
	_supplementary = [NSMutableDictionary dictionary];
	_contentSize = CGSizeZero;
	UICollectionView *collectionView = [self collectionView];
	if (collectionView == nil)
		return;
	NSSize bounds = [collectionView bounds].size;
	_preparedSize = CGSizeMake(bounds.width, bounds.height);
	BOOL vertical = _scrollDirection == UICollectionViewScrollDirectionVertical;
	CGFloat extent = vertical ? bounds.width : bounds.height;
	id delegate = [collectionView delegate];
	Class attributesClass = [[self class] layoutAttributesClass];

	/* Positions are worked out across the lines and along the scrolling. */
	CGRect (^place)(CGFloat, CGFloat, CGFloat, CGFloat) = ^CGRect(CGFloat across, CGFloat along, CGFloat acrossSize, CGFloat alongSize) {
		return vertical ? CGRectMake(across, along, acrossSize, alongSize) : CGRectMake(along, across, alongSize, acrossSize);
	};

	CGFloat along = 0;
	NSInteger sections = [collectionView numberOfSections];
	for (NSInteger s = 0; s < sections; s++) {
		UIEdgeInsets inset = [delegate respondsToSelector:@selector(collectionView:layout:insetForSectionAtIndex:)]
			? [delegate collectionView:collectionView layout:self insetForSectionAtIndex:s] : _sectionInset;
		CGFloat lineSpacing = [delegate respondsToSelector:@selector(collectionView:layout:minimumLineSpacingForSectionAtIndex:)]
			? [delegate collectionView:collectionView layout:self minimumLineSpacingForSectionAtIndex:s] : _minimumLineSpacing;
		CGFloat itemSpacing = [delegate respondsToSelector:@selector(collectionView:layout:minimumInteritemSpacingForSectionAtIndex:)]
			? [delegate collectionView:collectionView layout:self minimumInteritemSpacingForSectionAtIndex:s] : _minimumInteritemSpacing;
		NSIndexPath *sectionPath = [NSIndexPath indexPathForItem:0 inSection:s];

		CGSize header = [delegate respondsToSelector:@selector(collectionView:layout:referenceSizeForHeaderInSection:)]
			? [delegate collectionView:collectionView layout:self referenceSizeForHeaderInSection:s] : _headerReferenceSize;
		CGFloat headerAlong = vertical ? header.height : header.width;
		if (headerAlong > 0) {
			UICollectionViewLayoutAttributes *attributes = [attributesClass layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader withIndexPath:sectionPath];
			[attributes setFrame:place(0, along, extent, headerAlong)];
			[_all addObject:attributes];
			[_supplementary setObject:attributes forKey:UIKitSupplementaryKey(UICollectionElementKindSectionHeader, sectionPath)];
			along += headerAlong;
		}

		along += vertical ? inset.top : inset.left;
		CGFloat start = vertical ? inset.left : inset.top;
		CGFloat available = MAX(0, extent - start - (vertical ? inset.right : inset.bottom));
		NSInteger count = [collectionView numberOfItemsInSection:s];
		BOOL sized = [delegate respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)];
		CGSize fixed = _estimatedItemSize.width > 0 && _estimatedItemSize.height > 0 ? _estimatedItemSize : _itemSize;

		NSInteger first = 0;
		while (first < count) {
			/* Fill a line, then spread its items over it (all but the last). */
			NSMutableArray *line = [NSMutableArray array];
			CGFloat used = 0, thickness = 0;
			NSInteger i = first;
			for (; i < count; i++) {
				NSIndexPath *path = [NSIndexPath indexPathForItem:i inSection:s];
				CGSize size = sized ? [delegate collectionView:collectionView layout:self sizeForItemAtIndexPath:path] : fixed;
				CGFloat across = vertical ? size.width : size.height;
				CGFloat needed = used + ([line count] > 0 ? itemSpacing : 0) + across;
				if ([line count] > 0 && needed > available + 0.5)
					break;
				[line addObject:@[ path, [NSValue valueWithSize:NSMakeSize(size.width, size.height)] ]];
				used = needed;
				thickness = MAX(thickness, vertical ? size.height : size.width);
			}
			BOOL lastLine = i >= count;
			NSUInteger n = [line count];
			CGFloat gap = itemSpacing;
			if (!lastLine && n > 1)
				gap += (available - used) / (n - 1);
			CGFloat across = start;
			for (NSArray *entry in line) {
				NSSize size = [[entry objectAtIndex:1] sizeValue];
				CGFloat itemAcross = vertical ? size.width : size.height;
				CGFloat itemAlong = vertical ? size.height : size.width;
				UICollectionViewLayoutAttributes *attributes = [attributesClass layoutAttributesForCellWithIndexPath:[entry objectAtIndex:0]];
				[attributes setFrame:place(round(across), round(along + (thickness - itemAlong) / 2), itemAcross, itemAlong)];
				[_all addObject:attributes];
				[_items setObject:attributes forKey:[entry objectAtIndex:0]];
				across += itemAcross + gap;
			}
			along += thickness;
			if (!lastLine)
				along += lineSpacing;
			first = i;
		}
		along += vertical ? inset.bottom : inset.right;

		CGSize footer = [delegate respondsToSelector:@selector(collectionView:layout:referenceSizeForFooterInSection:)]
			? [delegate collectionView:collectionView layout:self referenceSizeForFooterInSection:s] : _footerReferenceSize;
		CGFloat footerAlong = vertical ? footer.height : footer.width;
		if (footerAlong > 0) {
			UICollectionViewLayoutAttributes *attributes = [attributesClass layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionFooter withIndexPath:sectionPath];
			[attributes setFrame:place(0, along, extent, footerAlong)];
			[_all addObject:attributes];
			[_supplementary setObject:attributes forKey:UIKitSupplementaryKey(UICollectionElementKindSectionFooter, sectionPath)];
			along += footerAlong;
		}
	}
	_contentSize = vertical ? CGSizeMake(extent, along) : CGSizeMake(along, extent);
}

- (CGSize)collectionViewContentSize { return _contentSize; }

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
	NSMutableArray *found = [NSMutableArray array];
	for (UICollectionViewLayoutAttributes *attributes in _all)
		if (CGRectIntersectsRect([attributes frame], rect))
			[found addObject:attributes];
	return found;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
	return [_items objectForKey:indexPath];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	return [_supplementary objectForKey:UIKitSupplementaryKey(kind, indexPath)];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
	return !CGSizeEqualToSize(newBounds.size, _preparedSize);
}

@end

#pragma mark - Reusable views and cells

@implementation UICollectionReusableView {
	NSString *_reuseIdentifier;
}

- (NSString *)reuseIdentifier { return _reuseIdentifier; }
- (void)uikitSetReuseIdentifier:(NSString *)identifier { _reuseIdentifier = [identifier copy]; }
- (void)prepareForReuse { }
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)attributes { }
- (void)willTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout { }
- (void)didTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout { }
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)attributes { return attributes; }

@end

@implementation UICollectionViewCell {
	UIView *_contentView;
	UIView *_backgroundView;
	UIView *_selectedBackgroundView;
	BOOL _selected;
	BOOL _highlighted;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]) == nil)
		return nil;
	_contentView = [[UIView alloc] initWithFrame:[self bounds]];
	[_contentView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[self addSubview:_contentView];
	return self;
}

/* The nib's content view (already a subview) replaces the cell's own. */
- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	UIView *contentView = [coder decodeObjectForKey:@"UIContentView"];
	if ([contentView isKindOfClass:[UIView class]] && contentView != _contentView) {
		[_contentView removeFromSuperview];
		_contentView = contentView;
		if ([_contentView superview] != self)
			[self addSubview:_contentView];
	}
}

- (UIView *)contentView { return _contentView; }
- (UIView *)backgroundView { return _backgroundView; }
- (UIView *)selectedBackgroundView { return _selectedBackgroundView; }

- (void)setBackgroundView:(UIView *)view
{
	[_backgroundView removeFromSuperview];
	_backgroundView = view;
	if (view != nil) {
		[view setFrame:[self bounds]];
		[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[self insertSubview:view atIndex:0];
	}
}

- (void)setSelectedBackgroundView:(UIView *)view
{
	[_selectedBackgroundView removeFromSuperview];
	_selectedBackgroundView = view;
	if (view != nil) {
		[view setFrame:[self bounds]];
		[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[self insertSubview:view belowSubview:_contentView];
	}
	[self uikitUpdateSelectionLook];
}

- (void)uikitUpdateSelectionLook
{
	[_selectedBackgroundView setHidden:!(_selected || _highlighted)];
}

/* As on iOS, labels and image views in the cell show their highlighted look. */
static void UIKitSetHighlightedInSubviews(NSView *view, BOOL highlighted)
{
	for (NSView *subview in [view subviews]) {
		if ([subview respondsToSelector:@selector(setHighlighted:)] && ![subview isKindOfClass:[UIControl class]])
			[(id)subview setHighlighted:highlighted];
		UIKitSetHighlightedInSubviews(subview, highlighted);
	}
}

- (BOOL)isSelected { return _selected; }

- (void)setSelected:(BOOL)selected
{
	_selected = selected;
	[self uikitUpdateSelectionLook];
	UIKitSetHighlightedInSubviews(_contentView, _selected || _highlighted);
}

- (BOOL)isHighlighted { return _highlighted; }

- (void)setHighlighted:(BOOL)highlighted
{
	_highlighted = highlighted;
	[self uikitUpdateSelectionLook];
	UIKitSetHighlightedInSubviews(_contentView, _selected || _highlighted);
}

- (void)prepareForReuse
{
	[super prepareForReuse];
	[self setSelected:NO];
	[self setHighlighted:NO];
}

@end

#pragma mark - UICollectionView

@implementation UICollectionView {
	UICollectionViewLayout *_layout;
	__weak id<UICollectionViewDataSource> _dataSource;
	UIView *_backgroundView;
	NSMutableArray<NSNumber *> *_itemCounts;
	NSMutableDictionary<NSIndexPath *, UICollectionViewCell *> *_visibleCells;
	NSMutableDictionary<NSString *, UICollectionReusableView *> *_visibleSupplementary;
	NSMutableDictionary<NSString *, NSMutableArray<UICollectionReusableView *> *> *_reuseQueues;
	/* Classes, or the nibs their views come from. */
	NSMutableDictionary<NSString *, id> *_cellClasses;
	NSMutableDictionary<NSString *, id> *_supplementaryClasses;
	NSMutableSet<NSIndexPath *> *_selected;
	NSIndexPath *_highlighted;
	BOOL _needsReload;
	BOOL _layoutValid;
	BOOL _tiling;
}

@synthesize allowsSelection = _allowsSelection;
@synthesize allowsMultipleSelection = _allowsMultipleSelection;
@synthesize prefetchingEnabled = _prefetchingEnabled;

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
	if ((self = [super initWithFrame:frame]) == nil)
		return nil;
	_itemCounts = [NSMutableArray array];
	_visibleCells = [NSMutableDictionary dictionary];
	_visibleSupplementary = [NSMutableDictionary dictionary];
	_reuseQueues = [NSMutableDictionary dictionary];
	_cellClasses = [NSMutableDictionary dictionary];
	_supplementaryClasses = [NSMutableDictionary dictionary];
	_selected = [NSMutableSet set];
	_allowsSelection = YES;
	_needsReload = YES;
	[self setCollectionViewLayout:layout ?: [[UICollectionViewFlowLayout alloc] init]];
	[self setBackgroundColor:[UIColor blackColor]];
	[self setClipsToBounds:YES];
	return self;
}

- (instancetype)uikitInitForCoder:(NSCoder *)coder
{
	UICollectionViewLayout *layout = [coder decodeObjectForKey:@"UICollectionLayout"];
	if (![layout isKindOfClass:[UICollectionViewLayout class]])
		layout = nil;
	IMP init = UIKitOwnImplementation([self class], @selector(initWithFrame:collectionViewLayout:));
	return ((id (*)(id, SEL, CGRect, UICollectionViewLayout *))init)(self, @selector(initWithFrame:collectionViewLayout:), UIKitArchivedFrame(coder), layout);
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	if ([coder containsValueForKey:@"UIDataSource"])
		_dataSource = [coder decodeObjectForKey:@"UIDataSource"];
	if ([coder containsValueForKey:@"UIAllowsSelection"])
		_allowsSelection = [coder decodeBoolForKey:@"UIAllowsSelection"];
	_allowsMultipleSelection = [coder decodeBoolForKey:@"UIAllowsMultipleSelection"];
}

- (instancetype)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame collectionViewLayout:nil];
}

- (UICollectionViewLayout *)collectionViewLayout { return _layout; }

- (void)setCollectionViewLayout:(UICollectionViewLayout *)layout
{
	if (layout == nil || layout == _layout)
		return;
	[_layout uikitSetCollectionView:nil];
	_layout = layout;
	[layout uikitSetCollectionView:self];
	[self uikitLayoutInvalidated];
}

- (void)setCollectionViewLayout:(UICollectionViewLayout *)layout animated:(BOOL)animated
{
	[self setCollectionViewLayout:layout];
}

- (void)uikitLayoutInvalidated
{
	_layoutValid = NO;
	[self setNeedsLayout];
}

- (id<UICollectionViewDataSource>)dataSource { return _dataSource; }

- (void)setDataSource:(id<UICollectionViewDataSource>)dataSource
{
	_dataSource = dataSource;
	[self reloadData];
}

- (id<UICollectionViewDelegate>)delegate { return (id<UICollectionViewDelegate>)[super delegate]; }

- (void)setDelegate:(id<UICollectionViewDelegate>)delegate
{
	[super setDelegate:delegate];
	[self uikitLayoutInvalidated];
}

- (UIView *)backgroundView { return _backgroundView; }

- (void)setBackgroundView:(UIView *)view
{
	[_backgroundView removeFromSuperview];
	_backgroundView = view;
	if (view != nil)
		[self insertSubview:view atIndex:0];
	[self setNeedsLayout];
}

#pragma mark Registration and reuse

- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier
{
	if (identifier == nil)
		return;
	if (cellClass == Nil)
		[_cellClasses removeObjectForKey:identifier];
	else
		[_cellClasses setObject:cellClass forKey:identifier];
}

- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier
{
	if (identifier == nil)
		return;
	if (nib == nil)
		[_cellClasses removeObjectForKey:identifier];
	else
		[_cellClasses setObject:nib forKey:identifier];
}

- (void)registerClass:(Class)viewClass forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier
{
	NSString *key = [NSString stringWithFormat:@"%@/%@", kind, identifier];
	if (viewClass == Nil)
		[_supplementaryClasses removeObjectForKey:key];
	else
		[_supplementaryClasses setObject:viewClass forKey:key];
}

- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier
{
	NSString *key = [NSString stringWithFormat:@"%@/%@", kind, identifier];
	if (nib == nil)
		[_supplementaryClasses removeObjectForKey:key];
	else
		[_supplementaryClasses setObject:nib forKey:key];
}

/* A view class, or the nib its views come from. */
- (UICollectionReusableView *)uikitDequeue:(NSString *)queue class:(id)viewClass identifier:(NSString *)identifier
{
	NSMutableArray *reusable = [_reuseQueues objectForKey:queue];
	UICollectionReusableView *view = [reusable lastObject];
	if (view != nil) {
		[reusable removeLastObject];
		[view setHidden:NO];
		[view prepareForReuse];
		return view;
	}
	if ([viewClass isKindOfClass:[UINib class]]) {
		for (id object in [(UINib *)viewClass instantiateWithOwner:nil options:nil]) {
			if ([object isKindOfClass:[UICollectionReusableView class]]) {
				view = object;
				break;
			}
		}
		if (view == nil)
			view = [[UICollectionViewCell alloc] initWithFrame:CGRectZero];
	} else {
		view = [[viewClass alloc] initWithFrame:CGRectZero];
	}
	[view uikitSetReuseIdentifier:identifier];
	return view;
}

- (UICollectionViewCell *)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath
{
	id cellClass = identifier != nil ? [_cellClasses objectForKey:identifier] : nil;
	if (cellClass == nil) {
		NSLog(@"UICollectionView: no cell class is registered for %@", identifier);
		cellClass = [UICollectionViewCell class];
	}
	return (UICollectionViewCell *)[self uikitDequeue:[@"cell/" stringByAppendingString:identifier ?: @""] class:cellClass identifier:identifier];
}

- (UICollectionReusableView *)dequeueReusableSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath
{
	NSString *key = [NSString stringWithFormat:@"%@/%@", kind, identifier];
	id viewClass = [_supplementaryClasses objectForKey:key];
	if (viewClass == nil) {
		NSLog(@"UICollectionView: no %@ view class is registered for %@", kind, identifier);
		viewClass = [UICollectionReusableView class];
	}
	return [self uikitDequeue:key class:viewClass identifier:identifier];
}

- (void)uikitEnqueue:(UICollectionReusableView *)view queue:(NSString *)queue
{
	[view setHidden:YES];
	[view removeFromSuperview];
	NSMutableArray *reusable = [_reuseQueues objectForKey:queue];
	if (reusable == nil) {
		reusable = [NSMutableArray array];
		[_reuseQueues setObject:reusable forKey:queue];
	}
	[reusable addObject:view];
}

- (NSString *)uikitQueueForCell:(UICollectionViewCell *)cell
{
	return [@"cell/" stringByAppendingString:[cell reuseIdentifier] ?: @""];
}

- (NSString *)uikitQueueForSupplementary:(UICollectionReusableView *)view kind:(NSString *)kind
{
	return [NSString stringWithFormat:@"%@/%@", kind, [view reuseIdentifier]];
}

#pragma mark Data

- (void)reloadData
{
	_needsReload = YES;
	_layoutValid = NO;
	[self setNeedsLayout];
}

- (void)uikitReloadIfNeeded
{
	if (!_needsReload)
		return;
	_needsReload = NO;
	id<UICollectionViewDelegate> delegate = [self delegate];
	for (NSIndexPath *path in [_visibleCells allKeys]) {
		UICollectionViewCell *cell = [_visibleCells objectForKey:path];
		if ([delegate respondsToSelector:@selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:)])
			[delegate collectionView:self didEndDisplayingCell:cell forItemAtIndexPath:path];
		[self uikitEnqueue:cell queue:[self uikitQueueForCell:cell]];
	}
	[_visibleCells removeAllObjects];
	for (NSString *key in [_visibleSupplementary allKeys]) {
		UICollectionReusableView *view = [_visibleSupplementary objectForKey:key];
		NSString *kind = [[key componentsSeparatedByString:@"|"] firstObject];
		[self uikitEnqueue:view queue:[self uikitQueueForSupplementary:view kind:kind]];
	}
	[_visibleSupplementary removeAllObjects];
	[_selected removeAllObjects];
	[_itemCounts removeAllObjects];
	id<UICollectionViewDataSource> dataSource = _dataSource;
	NSInteger sections = 0;
	if (dataSource != nil)
		sections = [dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)] ? MAX(0, [dataSource numberOfSectionsInCollectionView:self]) : 1;
	for (NSInteger s = 0; s < sections; s++)
		[_itemCounts addObject:@(MAX(0, [dataSource collectionView:self numberOfItemsInSection:s]))];
}

- (NSInteger)numberOfSections
{
	[self uikitReloadIfNeeded];
	return [_itemCounts count];
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
	[self uikitReloadIfNeeded];
	return section >= 0 && section < (NSInteger)[_itemCounts count] ? [[_itemCounts objectAtIndex:section] integerValue] : 0;
}

- (void)uikitPrepareLayoutIfNeeded
{
	[self uikitReloadIfNeeded];
	if (_layoutValid)
		return;
	_layoutValid = YES;
	[_layout prepareLayout];
	[self setContentSize:[_layout collectionViewContentSize]];
}

#pragma mark Tiling

- (void)layoutSubviews
{
	[super layoutSubviews];
	if ([_layout shouldInvalidateLayoutForBoundsChange:NSRectToCGRect([self bounds])])
		_layoutValid = NO;
	[self uikitPrepareLayoutIfNeeded];
	[self uikitTile];
}

- (void)setFrameSize:(NSSize)size
{
	NSSize old = [self frame].size;
	[super setFrameSize:size];
	if (old.width != size.width || old.height != size.height)
		[self setNeedsLayout];
}

- (void)uikitDidScroll
{
	[super uikitDidScroll];
	if (_layoutValid)
		[self uikitTile];
}

- (void)uikitApply:(UICollectionViewLayoutAttributes *)attributes toView:(UICollectionReusableView *)view
{
	[view applyLayoutAttributes:attributes];
	[view setFrame:NSRectFromCGRect([attributes frame])];
	[view setHidden:[attributes isHidden]];
	[view setAlpha:[attributes alpha]];
	if ([view superview] != self)
		[self addSubview:view];
}

- (void)uikitTile
{
	if (_tiling || _layout == nil)
		return;
	_tiling = YES;
	CGRect visible = NSRectToCGRect([self bounds]);
	if (_backgroundView != nil) {
		[_backgroundView setFrame:NSRectFromCGRect(visible)];
		if ([[self subviews] firstObject] != _backgroundView)
			[self insertSubview:_backgroundView atIndex:0];
	}
	id<UICollectionViewDataSource> dataSource = _dataSource;
	id<UICollectionViewDelegate> delegate = [self delegate];
	NSMutableSet *cellPaths = [NSMutableSet set];
	NSMutableSet *supplementaryKeys = [NSMutableSet set];
	NSArray *elements = [[_layout layoutAttributesForElementsInRect:visible] sortedArrayUsingComparator:^NSComparisonResult(UICollectionViewLayoutAttributes *a, UICollectionViewLayoutAttributes *b) {
		return [@([a zIndex]) compare:@([b zIndex])];
	}];
	for (UICollectionViewLayoutAttributes *attributes in elements) {
		NSIndexPath *path = [attributes indexPath];
		if ([attributes representedElementCategory] == UICollectionElementCategoryCell) {
			if ([path section] >= [self numberOfSections] || [path item] >= [self numberOfItemsInSection:[path section]])
				continue;
			[cellPaths addObject:path];
			UICollectionViewCell *cell = [_visibleCells objectForKey:path];
			BOOL appearing = cell == nil;
			if (appearing) {
				cell = [dataSource collectionView:self cellForItemAtIndexPath:path];
				if (cell == nil)
					continue;
				[_visibleCells setObject:cell forKey:path];
				[cell setSelected:[_selected containsObject:path]];
			}
			[self uikitApply:attributes toView:cell];
			if (appearing && [delegate respondsToSelector:@selector(collectionView:willDisplayCell:forItemAtIndexPath:)])
				[delegate collectionView:self willDisplayCell:cell forItemAtIndexPath:path];
		} else if ([attributes representedElementCategory] == UICollectionElementCategorySupplementaryView) {
			NSString *kind = [attributes representedElementKind];
			NSString *key = UIKitSupplementaryKey(kind, path);
			[supplementaryKeys addObject:key];
			UICollectionReusableView *view = [_visibleSupplementary objectForKey:key];
			if (view == nil) {
				if (![dataSource respondsToSelector:@selector(collectionView:viewForSupplementaryElementOfKind:atIndexPath:)])
					continue;
				view = [dataSource collectionView:self viewForSupplementaryElementOfKind:kind atIndexPath:path];
				if (view == nil)
					continue;
				[_visibleSupplementary setObject:view forKey:key];
			}
			[self uikitApply:attributes toView:view];
		}
	}
	for (NSIndexPath *path in [_visibleCells allKeys]) {
		if ([cellPaths containsObject:path])
			continue;
		UICollectionViewCell *cell = [_visibleCells objectForKey:path];
		[_visibleCells removeObjectForKey:path];
		if ([delegate respondsToSelector:@selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:)])
			[delegate collectionView:self didEndDisplayingCell:cell forItemAtIndexPath:path];
		[self uikitEnqueue:cell queue:[self uikitQueueForCell:cell]];
	}
	for (NSString *key in [_visibleSupplementary allKeys]) {
		if ([supplementaryKeys containsObject:key])
			continue;
		UICollectionReusableView *view = [_visibleSupplementary objectForKey:key];
		[_visibleSupplementary removeObjectForKey:key];
		[self uikitEnqueue:view queue:[self uikitQueueForSupplementary:view kind:[[key componentsSeparatedByString:@"|"] firstObject]]];
	}
	[self setNeedsDisplay:YES];
	_tiling = NO;
}

#pragma mark Queries

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
	[self uikitPrepareLayoutIfNeeded];
	return [_layout layoutAttributesForItemAtIndexPath:indexPath];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	[self uikitPrepareLayoutIfNeeded];
	return [_layout layoutAttributesForSupplementaryViewOfKind:kind atIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point
{
	[self uikitPrepareLayoutIfNeeded];
	for (UICollectionViewLayoutAttributes *attributes in [_layout layoutAttributesForElementsInRect:CGRectMake(point.x, point.y, 1, 1)])
		if ([attributes representedElementCategory] == UICollectionElementCategoryCell && !CGRectIsEmpty([attributes frame])
		    && CGRectContainsPoint([attributes frame], point))
			return [attributes indexPath];
	return nil;
}

- (NSIndexPath *)indexPathForCell:(UICollectionViewCell *)cell
{
	for (NSIndexPath *path in _visibleCells)
		if ([_visibleCells objectForKey:path] == cell)
			return path;
	return nil;
}

- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	return indexPath != nil ? [_visibleCells objectForKey:[NSIndexPath indexPathForItem:[indexPath item] inSection:[indexPath section]]] : nil;
}

- (NSArray *)visibleCells { return [_visibleCells allValues]; }
- (NSArray *)indexPathsForVisibleItems { return [_visibleCells allKeys]; }

- (UICollectionReusableView *)supplementaryViewForElementKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	return [_visibleSupplementary objectForKey:UIKitSupplementaryKey(kind, indexPath)];
}

- (NSArray *)visibleSupplementaryViewsOfKind:(NSString *)kind
{
	NSMutableArray *views = [NSMutableArray array];
	NSString *prefix = [kind stringByAppendingString:@"|"];
	for (NSString *key in _visibleSupplementary)
		if ([key hasPrefix:prefix])
			[views addObject:[_visibleSupplementary objectForKey:key]];
	return views;
}

#pragma mark Selection

- (NSArray *)indexPathsForSelectedItems { return [_selected allObjects]; }

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition
{
	if (!_allowsMultipleSelection)
		for (NSIndexPath *path in [_selected allObjects])
			[self deselectItemAtIndexPath:path animated:NO];
	if (indexPath == nil)
		return;
	[_selected addObject:indexPath];
	[[self cellForItemAtIndexPath:indexPath] setSelected:YES];
	if (scrollPosition != UICollectionViewScrollPositionNone)
		[self scrollToItemAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
	if (indexPath == nil)
		return;
	[_selected removeObject:indexPath];
	[[self cellForItemAtIndexPath:indexPath] setSelected:NO];
}

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)position animated:(BOOL)animated
{
	CGRect frame = [[self layoutAttributesForItemAtIndexPath:indexPath] frame];
	if (CGRectIsEmpty(frame))
		return;
	NSSize size = [self bounds].size;
	CGPoint offset = [self contentOffset];
	if (position & UICollectionViewScrollPositionTop)
		offset.y = frame.origin.y;
	else if (position & UICollectionViewScrollPositionCenteredVertically)
		offset.y = CGRectGetMidY(frame) - size.height / 2;
	else if (position & UICollectionViewScrollPositionBottom)
		offset.y = CGRectGetMaxY(frame) - size.height;
	if (position & UICollectionViewScrollPositionLeft)
		offset.x = frame.origin.x;
	else if (position & UICollectionViewScrollPositionCenteredHorizontally)
		offset.x = CGRectGetMidX(frame) - size.width / 2;
	else if (position & UICollectionViewScrollPositionRight)
		offset.x = CGRectGetMaxX(frame) - size.width;
	if (position == UICollectionViewScrollPositionNone) {
		[self scrollRectToVisible:frame animated:animated];
		return;
	}
	CGSize content = [self contentSize];
	offset.x = MAX(0, MIN(offset.x, content.width - size.width));
	offset.y = MAX(0, MIN(offset.y, content.height - size.height));
	[self setContentOffset:offset animated:animated];
}

- (NSIndexPath *)uikitPathForTouches:(NSSet *)touches
{
	return [self indexPathForItemAtPoint:[[touches anyObject] locationInView:self]];
}

- (void)uikitUnhighlight
{
	NSIndexPath *path = _highlighted;
	if (path == nil)
		return;
	_highlighted = nil;
	[[self cellForItemAtIndexPath:path] setHighlighted:NO];
	id<UICollectionViewDelegate> delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(collectionView:didUnhighlightItemAtIndexPath:)])
		[delegate collectionView:self didUnhighlightItemAtIndexPath:path];
}

- (void)uikitTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!_allowsSelection)
		return;
	NSIndexPath *path = [self uikitPathForTouches:touches];
	if (path == nil)
		return;
	id<UICollectionViewDelegate> delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(collectionView:shouldHighlightItemAtIndexPath:)]
	    && ![delegate collectionView:self shouldHighlightItemAtIndexPath:path])
		return;
	_highlighted = path;
	[[self cellForItemAtIndexPath:path] setHighlighted:YES];
	if ([delegate respondsToSelector:@selector(collectionView:didHighlightItemAtIndexPath:)])
		[delegate collectionView:self didHighlightItemAtIndexPath:path];
}

- (void)uikitTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self uikitUnhighlight];
}

- (void)uikitTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSIndexPath *path = _highlighted;
	[self uikitUnhighlight];
	if (path == nil || ![path isEqual:[self uikitPathForTouches:touches]])
		return;
	id<UICollectionViewDelegate> delegate = [self delegate];
	if ([_selected containsObject:path] && _allowsMultipleSelection) {
		if ([delegate respondsToSelector:@selector(collectionView:shouldDeselectItemAtIndexPath:)]
		    && ![delegate collectionView:self shouldDeselectItemAtIndexPath:path])
			return;
		[self deselectItemAtIndexPath:path animated:YES];
		if ([delegate respondsToSelector:@selector(collectionView:didDeselectItemAtIndexPath:)])
			[delegate collectionView:self didDeselectItemAtIndexPath:path];
		return;
	}
	if ([delegate respondsToSelector:@selector(collectionView:shouldSelectItemAtIndexPath:)]
	    && ![delegate collectionView:self shouldSelectItemAtIndexPath:path])
		return;
	if (!_allowsMultipleSelection)
		for (NSIndexPath *previous in [_selected allObjects]) {
			if ([previous isEqual:path])
				continue;
			[self deselectItemAtIndexPath:previous animated:NO];
			if ([delegate respondsToSelector:@selector(collectionView:didDeselectItemAtIndexPath:)])
				[delegate collectionView:self didDeselectItemAtIndexPath:previous];
		}
	[_selected addObject:path];
	[[self cellForItemAtIndexPath:path] setSelected:YES];
	if ([delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)])
		[delegate collectionView:self didSelectItemAtIndexPath:path];
}

#pragma mark Updates

/* Changes are not animated: any of them reloads everything. */
- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion
{
	if (updates != nil)
		updates();
	[self reloadData];
	[self layoutIfNeeded];
	if (completion != nil)
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(YES);
		});
}

- (void)insertSections:(NSIndexSet *)sections { [self reloadData]; }
- (void)deleteSections:(NSIndexSet *)sections { [self reloadData]; }
- (void)reloadSections:(NSIndexSet *)sections { [self reloadData]; }
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection { [self reloadData]; }
- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths { [self reloadData]; }
- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths { [self reloadData]; }
- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths { [self reloadData]; }
- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath { [self reloadData]; }

@end

#pragma mark - UICollectionViewController

@implementation UICollectionViewController {
	UICollectionView *_collectionView;
	UICollectionViewLayout *_initialLayout;
	BOOL _reloadedOnce;
}

@synthesize clearsSelectionOnViewWillAppear = _clearsSelectionOnViewWillAppear;
@synthesize installsStandardGestureForInteractiveMovement = _installsStandardGestureForInteractiveMovement;
@synthesize useLayoutToLayoutNavigationTransitions = _useLayoutToLayoutNavigationTransitions;

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		_initialLayout = layout;
		_clearsSelectionOnViewWillAppear = YES;
	}
	return self;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
	if ((self = [super initWithNibName:nibName bundle:bundle]))
		_clearsSelectionOnViewWillAppear = YES;
	return self;
}

- (void)loadView
{
	if (_collectionView == nil && [self uikitLoadViewFromNib])
		return;
	if (_collectionView == nil) {
		UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]
		                                                      collectionViewLayout:_initialLayout ?: [[UICollectionViewFlowLayout alloc] init]];
		[collectionView setDataSource:self];
		[collectionView setDelegate:self];
		_collectionView = collectionView;
	}
	[_collectionView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[super setView:_collectionView];
}

- (void)setView:(UIView *)view
{
	[super setView:view];
	if ([view isKindOfClass:[UICollectionView class]])
		_collectionView = (UICollectionView *)view;
}

- (UICollectionView *)collectionView
{
	[self view];
	return _collectionView;
}

- (void)setCollectionView:(UICollectionView *)collectionView
{
	_collectionView = collectionView;
	[super setView:collectionView];
}

- (UICollectionViewLayout *)collectionViewLayout
{
	return _collectionView != nil ? [_collectionView collectionViewLayout] : _initialLayout;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	if (!_reloadedOnce) {
		_reloadedOnce = YES;
		[_collectionView reloadData];
	}
	if (_clearsSelectionOnViewWillAppear)
		for (NSIndexPath *path in [_collectionView indexPathsForSelectedItems])
			[_collectionView deselectItemAtIndexPath:path animated:animated];
}

/* Subclasses provide the items; these keep one that does not from crashing. */
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	return [[UICollectionViewCell alloc] initWithFrame:CGRectZero];
}

@end
