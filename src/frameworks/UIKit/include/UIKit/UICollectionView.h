/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UICOLLECTIONVIEW_H
#define UIKIT_UICOLLECTIONVIEW_H

#import <Foundation/Foundation.h>
#import <UIKit/UIScrollView.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UITableView.h>

@class UICollectionView, UICollectionViewLayout, UICollectionViewCell, UICollectionReusableView, UINib;

extern NSString *const UICollectionElementKindSectionHeader;
extern NSString *const UICollectionElementKindSectionFooter;

typedef NS_ENUM(NSUInteger, UICollectionElementCategory) {
	UICollectionElementCategoryCell,
	UICollectionElementCategorySupplementaryView,
	UICollectionElementCategoryDecorationView,
};

typedef NS_OPTIONS(NSUInteger, UICollectionViewScrollPosition) {
	UICollectionViewScrollPositionNone = 0,
	UICollectionViewScrollPositionTop = 1 << 0,
	UICollectionViewScrollPositionCenteredVertically = 1 << 1,
	UICollectionViewScrollPositionBottom = 1 << 2,
	UICollectionViewScrollPositionLeft = 1 << 3,
	UICollectionViewScrollPositionCenteredHorizontally = 1 << 4,
	UICollectionViewScrollPositionRight = 1 << 5,
};

typedef NS_ENUM(NSInteger, UICollectionViewScrollDirection) {
	UICollectionViewScrollDirectionVertical,
	UICollectionViewScrollDirectionHorizontal,
};

@interface UICollectionViewLayoutAttributes : NSObject <NSCopying>
+ (instancetype)layoutAttributesForCellWithIndexPath:(NSIndexPath *)indexPath;
+ (instancetype)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind withIndexPath:(NSIndexPath *)indexPath;
+ (instancetype)layoutAttributesForDecorationViewOfKind:(NSString *)decorationViewKind withIndexPath:(NSIndexPath *)indexPath;
@property (nonatomic) CGRect frame;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGPoint center;
@property (nonatomic) CGSize size;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic) CGFloat alpha;
@property (nonatomic) NSInteger zIndex;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, readonly) UICollectionElementCategory representedElementCategory;
@property (nonatomic, readonly) NSString *representedElementKind;
@end

@interface UICollectionViewLayout : NSObject <NSCoding>
@property (nonatomic, readonly, weak) UICollectionView *collectionView;
+ (Class)layoutAttributesClass;
- (void)prepareLayout;
- (CGSize)collectionViewContentSize;
- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect;
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds;
- (void)invalidateLayout;
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset;
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity;
- (void)registerClass:(Class)viewClass forDecorationViewOfKind:(NSString *)elementKind;
- (void)prepareForCollectionViewUpdates:(NSArray *)updateItems;
- (void)finalizeCollectionViewUpdates;
- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath;
- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)itemIndexPath;
@end

extern const CGSize UICollectionViewFlowLayoutAutomaticSize;

@interface UICollectionViewFlowLayout : UICollectionViewLayout
@property (nonatomic) CGFloat minimumLineSpacing;
@property (nonatomic) CGFloat minimumInteritemSpacing;
@property (nonatomic) CGSize itemSize;
@property (nonatomic) CGSize estimatedItemSize;
@property (nonatomic) UICollectionViewScrollDirection scrollDirection;
@property (nonatomic) CGSize headerReferenceSize;
@property (nonatomic) CGSize footerReferenceSize;
@property (nonatomic) UIEdgeInsets sectionInset;
@property (nonatomic) NSInteger sectionInsetReference;
@property (nonatomic) BOOL sectionHeadersPinToVisibleBounds;
@property (nonatomic) BOOL sectionFootersPinToVisibleBounds;
@end

@protocol UICollectionViewDataSource <NSObject>
@required
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
@optional
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView;
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;
@end

@protocol UICollectionViewDelegate <UIScrollViewDelegate>
@optional
- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;
@end

@protocol UICollectionViewDelegateFlowLayout <UICollectionViewDelegate>
@optional
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath;
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout insetForSectionAtIndex:(NSInteger)section;
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section;
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout referenceSizeForFooterInSection:(NSInteger)section;
@end

@interface UICollectionReusableView : UIView
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
- (void)prepareForReuse;
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes;
- (void)willTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout;
- (void)didTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout;
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes;
@end

@interface UICollectionViewCell : UICollectionReusableView
@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *selectedBackgroundView;
@end

@interface UICollectionView : UIScrollView
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout;
@property (nonatomic, strong) UICollectionViewLayout *collectionViewLayout;
@property (nonatomic, weak) id<UICollectionViewDelegate> delegate;
@property (nonatomic, weak) id<UICollectionViewDataSource> dataSource;
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic) BOOL allowsSelection;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic, getter=isPrefetchingEnabled) BOOL prefetchingEnabled;
- (void)setCollectionViewLayout:(UICollectionViewLayout *)layout animated:(BOOL)animated;
- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier;
- (void)registerClass:(Class)viewClass forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier;
- (__kindof UICollectionViewCell *)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
- (__kindof UICollectionReusableView *)dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
- (void)reloadData;
- (NSInteger)numberOfSections;
- (NSInteger)numberOfItemsInSection:(NSInteger)section;
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point;
- (NSIndexPath *)indexPathForCell:(UICollectionViewCell *)cell;
- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath;
- (NSArray<__kindof UICollectionViewCell *> *)visibleCells;
- (NSArray<NSIndexPath *> *)indexPathsForVisibleItems;
- (UICollectionReusableView *)supplementaryViewForElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
- (NSArray<UICollectionReusableView *> *)visibleSupplementaryViewsOfKind:(NSString *)elementKind;
- (NSArray<NSIndexPath *> *)indexPathsForSelectedItems;
- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition;
- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated;
- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion;
- (void)insertSections:(NSIndexSet *)sections;
- (void)deleteSections:(NSIndexSet *)sections;
- (void)reloadSections:(NSIndexSet *)sections;
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;
- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)deleteItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)reloadItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;
@end

@interface UICollectionViewController : UIViewController <UICollectionViewDelegate, UICollectionViewDataSource>
- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, readonly) UICollectionViewLayout *collectionViewLayout;
@property (nonatomic) BOOL clearsSelectionOnViewWillAppear;
@property (nonatomic) BOOL installsStandardGestureForInteractiveMovement;
@property (nonatomic) BOOL useLayoutToLayoutNavigationTransitions;
@end

#endif /* UIKIT_UICOLLECTIONVIEW_H */
