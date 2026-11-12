/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIDIFFABLEDATASOURCE_H
#define UIKIT_UIDIFFABLEDATASOURCE_H

#import <UIKit/UITableView.h>
#import <UIKit/UICollectionView.h>

/* Sections and their items, by identifier; each identifier once. */
@interface NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> : NSObject <NSCopying>
@property (nonatomic, readonly) NSInteger numberOfItems;
@property (nonatomic, readonly) NSInteger numberOfSections;
@property (nonatomic, readonly) NSArray<SectionIdentifierType> *sectionIdentifiers;
@property (nonatomic, readonly) NSArray<ItemIdentifierType> *itemIdentifiers;
@property (nonatomic, readonly) NSArray<ItemIdentifierType> *reloadedItemIdentifiers;
@property (nonatomic, readonly) NSArray<ItemIdentifierType> *reconfiguredItemIdentifiers;
@property (nonatomic, readonly) NSArray<SectionIdentifierType> *reloadedSectionIdentifiers;
- (NSInteger)numberOfItemsInSection:(SectionIdentifierType)sectionIdentifier;
- (NSArray<ItemIdentifierType> *)itemIdentifiersInSectionWithIdentifier:(SectionIdentifierType)sectionIdentifier;
- (SectionIdentifierType)sectionIdentifierForSectionContainingItemIdentifier:(ItemIdentifierType)itemIdentifier;
- (NSInteger)indexOfItemIdentifier:(ItemIdentifierType)itemIdentifier;
- (NSInteger)indexOfSectionIdentifier:(SectionIdentifierType)sectionIdentifier;
- (void)appendItemsWithIdentifiers:(NSArray<ItemIdentifierType> *)identifiers;
- (void)appendItemsWithIdentifiers:(NSArray<ItemIdentifierType> *)identifiers intoSectionWithIdentifier:(SectionIdentifierType)sectionIdentifier;
- (void)insertItemsWithIdentifiers:(NSArray<ItemIdentifierType> *)identifiers beforeItemWithIdentifier:(ItemIdentifierType)itemIdentifier;
- (void)insertItemsWithIdentifiers:(NSArray<ItemIdentifierType> *)identifiers afterItemWithIdentifier:(ItemIdentifierType)itemIdentifier;
- (void)deleteItemsWithIdentifiers:(NSArray<ItemIdentifierType> *)identifiers;
- (void)deleteAllItems;
- (void)moveItemWithIdentifier:(ItemIdentifierType)fromIdentifier beforeItemWithIdentifier:(ItemIdentifierType)toIdentifier;
- (void)moveItemWithIdentifier:(ItemIdentifierType)fromIdentifier afterItemWithIdentifier:(ItemIdentifierType)toIdentifier;
- (void)reloadItemsWithIdentifiers:(NSArray<ItemIdentifierType> *)identifiers;
- (void)reconfigureItemsWithIdentifiers:(NSArray<ItemIdentifierType> *)identifiers;
- (void)appendSectionsWithIdentifiers:(NSArray<SectionIdentifierType> *)sectionIdentifiers;
- (void)insertSectionsWithIdentifiers:(NSArray<SectionIdentifierType> *)sectionIdentifiers beforeSectionWithIdentifier:(SectionIdentifierType)toSectionIdentifier;
- (void)insertSectionsWithIdentifiers:(NSArray<SectionIdentifierType> *)sectionIdentifiers afterSectionWithIdentifier:(SectionIdentifierType)toSectionIdentifier;
- (void)deleteSectionsWithIdentifiers:(NSArray<SectionIdentifierType> *)sectionIdentifiers;
- (void)moveSectionWithIdentifier:(SectionIdentifierType)fromSectionIdentifier beforeSectionWithIdentifier:(SectionIdentifierType)toSectionIdentifier;
- (void)moveSectionWithIdentifier:(SectionIdentifierType)fromSectionIdentifier afterSectionWithIdentifier:(SectionIdentifierType)toSectionIdentifier;
- (void)reloadSectionsWithIdentifiers:(NSArray<SectionIdentifierType> *)sectionIdentifiers;
- (void)reconfigureSectionsWithIdentifiers:(NSArray<SectionIdentifierType> *)sectionIdentifiers;
@end

typedef UITableViewCell *(^UITableViewDiffableDataSourceCellProvider)(UITableView *tableView, NSIndexPath *indexPath, id itemIdentifier);

/*
 * A table's data source made from snapshots. Applying one reloads the
 * table: nothing is animated.
 */
@interface UITableViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType> : NSObject <UITableViewDataSource>
- (instancetype)initWithTableView:(UITableView *)tableView cellProvider:(UITableViewDiffableDataSourceCellProvider)cellProvider;
- (NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot;
- (void)applySnapshot:(NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot animatingDifferences:(BOOL)animatingDifferences;
- (void)applySnapshot:(NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot animatingDifferences:(BOOL)animatingDifferences completion:(void (^)(void))completion;
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot;
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot completion:(void (^)(void))completion;
- (ItemIdentifierType)itemIdentifierForIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForItemIdentifier:(ItemIdentifierType)identifier;
- (SectionIdentifierType)sectionIdentifierForIndex:(NSInteger)index;
- (NSInteger)indexForSectionIdentifier:(SectionIdentifierType)identifier;
@property (nonatomic) UITableViewRowAnimation defaultRowAnimation;
@end

typedef UICollectionViewCell *(^UICollectionViewDiffableDataSourceCellProvider)(UICollectionView *collectionView, NSIndexPath *indexPath, id itemIdentifier);
typedef UICollectionReusableView *(^UICollectionViewDiffableDataSourceSupplementaryViewProvider)(UICollectionView *collectionView, NSString *elementKind, NSIndexPath *indexPath);

@interface UICollectionViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType> : NSObject <UICollectionViewDataSource>
- (instancetype)initWithCollectionView:(UICollectionView *)collectionView cellProvider:(UICollectionViewDiffableDataSourceCellProvider)cellProvider;
@property (nonatomic, copy) UICollectionViewDiffableDataSourceSupplementaryViewProvider supplementaryViewProvider;
- (NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot;
- (void)applySnapshot:(NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot animatingDifferences:(BOOL)animatingDifferences;
- (void)applySnapshot:(NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot animatingDifferences:(BOOL)animatingDifferences completion:(void (^)(void))completion;
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot;
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> *)snapshot completion:(void (^)(void))completion;
- (ItemIdentifierType)itemIdentifierForIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForItemIdentifier:(ItemIdentifierType)identifier;
- (SectionIdentifierType)sectionIdentifierForIndex:(NSInteger)index;
- (NSInteger)indexForSectionIdentifier:(SectionIdentifierType)identifier;
@end

#endif /* UIKIT_UIDIFFABLEDATASOURCE_H */
