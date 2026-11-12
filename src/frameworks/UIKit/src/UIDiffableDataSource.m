/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIDiffableDataSource.h>
#import "UIKitPrivate.h"

@implementation NSDiffableDataSourceSnapshot {
	NSMutableArray *_sections;
	/* Each section's items, and which section each item is in. */
	NSMutableDictionary<id, NSMutableArray *> *_items;
	NSMutableDictionary *_sectionOfItem;
	NSMutableArray *_reloadedItems, *_reconfiguredItems, *_reloadedSections;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_sections = [NSMutableArray array];
		_items = [NSMutableDictionary dictionary];
		_sectionOfItem = [NSMutableDictionary dictionary];
		_reloadedItems = [NSMutableArray array];
		_reconfiguredItems = [NSMutableArray array];
		_reloadedSections = [NSMutableArray array];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	NSDiffableDataSourceSnapshot *copy = [[NSDiffableDataSourceSnapshot alloc] init];
	[copy->_sections setArray:_sections];
	for (id section in _items)
		copy->_items[section] = [_items[section] mutableCopy];
	[copy->_sectionOfItem setDictionary:_sectionOfItem];
	return copy;
}

static void UIKitRaise(NSString *format, id identifier)
{
	[NSException raise:NSInternalInconsistencyException format:format, identifier];
}

- (NSInteger)numberOfSections { return [_sections count]; }
- (NSInteger)numberOfItems { return [_sectionOfItem count]; }
- (NSArray *)sectionIdentifiers { return [_sections copy]; }
- (NSArray *)reloadedItemIdentifiers { return [_reloadedItems copy]; }
- (NSArray *)reconfiguredItemIdentifiers { return [_reconfiguredItems copy]; }
- (NSArray *)reloadedSectionIdentifiers { return [_reloadedSections copy]; }

- (NSArray *)itemIdentifiers
{
	NSMutableArray *items = [NSMutableArray array];
	for (id section in _sections)
		[items addObjectsFromArray:_items[section]];
	return items;
}

- (NSInteger)numberOfItemsInSection:(id)section
{
	if (_items[section] == nil)
		UIKitRaise(@"Invalid section identifier for which to fetch the number of items: %@", section);
	return [_items[section] count];
}

- (NSArray *)itemIdentifiersInSectionWithIdentifier:(id)section
{
	if (_items[section] == nil)
		UIKitRaise(@"Invalid section identifier: %@", section);
	return [_items[section] copy];
}

- (id)sectionIdentifierForSectionContainingItemIdentifier:(id)item
{
	return item != nil ? _sectionOfItem[item] : nil;
}

- (NSInteger)indexOfItemIdentifier:(id)item
{
	if (item == nil || _sectionOfItem[item] == nil)
		return NSNotFound;
	NSInteger index = 0;
	for (id section in _sections) {
		NSUInteger inSection = [_items[section] indexOfObject:item];
		if (inSection != NSNotFound)
			return index + inSection;
		index += [_items[section] count];
	}
	return NSNotFound;
}

- (NSInteger)indexOfSectionIdentifier:(id)section
{
	return section != nil ? [_sections indexOfObject:section] : NSNotFound;
}

- (void)uikitCheckNewItems:(NSArray *)identifiers
{
	NSMutableSet *seen = [NSMutableSet set];
	for (id item in identifiers) {
		if (_sectionOfItem[item] != nil || [seen containsObject:item])
			UIKitRaise(@"Items in a snapshot must be unique; this one is already there: %@", item);
		[seen addObject:item];
	}
}

- (void)appendItemsWithIdentifiers:(NSArray *)identifiers
{
	id section = [_sections lastObject];
	if (section == nil)
		[NSException raise:NSInternalInconsistencyException format:@"There are currently no sections in the data source. Please add a section first."];
	[self appendItemsWithIdentifiers:identifiers intoSectionWithIdentifier:section];
}

- (void)appendItemsWithIdentifiers:(NSArray *)identifiers intoSectionWithIdentifier:(id)section
{
	NSMutableArray *items = _items[section];
	if (items == nil)
		UIKitRaise(@"Invalid section identifier: %@", section);
	[self uikitCheckNewItems:identifiers];
	for (id item in identifiers) {
		[items addObject:item];
		_sectionOfItem[item] = section;
	}
}

- (void)uikitInsertItems:(NSArray *)identifiers near:(id)anchor after:(BOOL)after
{
	id section = anchor != nil ? _sectionOfItem[anchor] : nil;
	if (section == nil)
		UIKitRaise(@"Invalid item identifier: %@", anchor);
	[self uikitCheckNewItems:identifiers];
	NSMutableArray *items = _items[section];
	NSUInteger index = [items indexOfObject:anchor] + (after ? 1 : 0);
	[items insertObjects:identifiers atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index, [identifiers count])]];
	for (id item in identifiers)
		_sectionOfItem[item] = section;
}

- (void)insertItemsWithIdentifiers:(NSArray *)identifiers beforeItemWithIdentifier:(id)item { [self uikitInsertItems:identifiers near:item after:NO]; }
- (void)insertItemsWithIdentifiers:(NSArray *)identifiers afterItemWithIdentifier:(id)item { [self uikitInsertItems:identifiers near:item after:YES]; }

- (void)deleteItemsWithIdentifiers:(NSArray *)identifiers
{
	for (id item in identifiers) {
		id section = _sectionOfItem[item];
		if (section == nil)
			continue;
		[_items[section] removeObject:item];
		[_sectionOfItem removeObjectForKey:item];
	}
}

- (void)deleteAllItems
{
	[_sections removeAllObjects];
	[_items removeAllObjects];
	[_sectionOfItem removeAllObjects];
}

- (void)uikitMoveItem:(id)item near:(id)anchor after:(BOOL)after
{
	if (_sectionOfItem[item] == nil)
		UIKitRaise(@"Invalid item identifier to move: %@", item);
	if ([item isEqual:anchor])
		return;
	[self deleteItemsWithIdentifiers:@[ item ]];
	[self uikitInsertItems:@[ item ] near:anchor after:after];
}

- (void)moveItemWithIdentifier:(id)item beforeItemWithIdentifier:(id)anchor { [self uikitMoveItem:item near:anchor after:NO]; }
- (void)moveItemWithIdentifier:(id)item afterItemWithIdentifier:(id)anchor { [self uikitMoveItem:item near:anchor after:YES]; }

- (void)reloadItemsWithIdentifiers:(NSArray *)identifiers { [_reloadedItems addObjectsFromArray:identifiers]; }
- (void)reconfigureItemsWithIdentifiers:(NSArray *)identifiers { [_reconfiguredItems addObjectsFromArray:identifiers]; }
- (void)reloadSectionsWithIdentifiers:(NSArray *)identifiers { [_reloadedSections addObjectsFromArray:identifiers]; }
- (void)reconfigureSectionsWithIdentifiers:(NSArray *)identifiers { [_reloadedSections addObjectsFromArray:identifiers]; }

- (void)uikitCheckNewSections:(NSArray *)identifiers
{
	NSMutableSet *seen = [NSMutableSet set];
	for (id section in identifiers) {
		if (_items[section] != nil || [seen containsObject:section])
			UIKitRaise(@"Section identifiers must be unique; this one is already there: %@", section);
		[seen addObject:section];
	}
}

- (void)appendSectionsWithIdentifiers:(NSArray *)identifiers
{
	[self uikitCheckNewSections:identifiers];
	for (id section in identifiers) {
		[_sections addObject:section];
		_items[section] = [NSMutableArray array];
	}
}

- (void)uikitInsertSections:(NSArray *)identifiers near:(id)anchor after:(BOOL)after
{
	NSUInteger index = anchor != nil ? [_sections indexOfObject:anchor] : NSNotFound;
	if (index == NSNotFound)
		UIKitRaise(@"Invalid section identifier: %@", anchor);
	[self uikitCheckNewSections:identifiers];
	[_sections insertObjects:identifiers atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index + (after ? 1 : 0), [identifiers count])]];
	for (id section in identifiers)
		_items[section] = [NSMutableArray array];
}

- (void)insertSectionsWithIdentifiers:(NSArray *)identifiers beforeSectionWithIdentifier:(id)section { [self uikitInsertSections:identifiers near:section after:NO]; }
- (void)insertSectionsWithIdentifiers:(NSArray *)identifiers afterSectionWithIdentifier:(id)section { [self uikitInsertSections:identifiers near:section after:YES]; }

- (void)deleteSectionsWithIdentifiers:(NSArray *)identifiers
{
	for (id section in identifiers) {
		for (id item in _items[section])
			[_sectionOfItem removeObjectForKey:item];
		[_items removeObjectForKey:section];
		[_sections removeObject:section];
	}
}

- (void)uikitMoveSection:(id)section near:(id)anchor after:(BOOL)after
{
	if (_items[section] == nil || _items[anchor] == nil)
		UIKitRaise(@"Invalid section identifier to move: %@", section);
	if ([section isEqual:anchor])
		return;
	[_sections removeObject:section];
	[_sections insertObject:section atIndex:[_sections indexOfObject:anchor] + (after ? 1 : 0)];
}

- (void)moveSectionWithIdentifier:(id)section beforeSectionWithIdentifier:(id)anchor { [self uikitMoveSection:section near:anchor after:NO]; }
- (void)moveSectionWithIdentifier:(id)section afterSectionWithIdentifier:(id)anchor { [self uikitMoveSection:section near:anchor after:YES]; }

- (id)uikitItemAtSection:(NSInteger)section index:(NSInteger)index
{
	if (section < 0 || section >= (NSInteger)[_sections count])
		return nil;
	NSArray *items = _items[[_sections objectAtIndex:section]];
	return index >= 0 && index < (NSInteger)[items count] ? [items objectAtIndex:index] : nil;
}

- (NSIndexPath *)uikitIndexPathOfItem:(id)item
{
	id section = item != nil ? _sectionOfItem[item] : nil;
	if (section == nil)
		return nil;
	return [NSIndexPath indexPathForRow:[_items[section] indexOfObject:item] inSection:[_sections indexOfObject:section]];
}

@end

/* What both data sources keep: the snapshot shown. */
#define UIKIT_DIFFABLE_COMMON(viewType, view) \
- (NSDiffableDataSourceSnapshot *)snapshot { return [_snapshot copy]; } \
\
- (void)applySnapshot:(NSDiffableDataSourceSnapshot *)snapshot animatingDifferences:(BOOL)animate \
{ \
	[self applySnapshot:snapshot animatingDifferences:animate completion:nil]; \
} \
\
- (void)applySnapshot:(NSDiffableDataSourceSnapshot *)snapshot animatingDifferences:(BOOL)animate completion:(void (^)(void))completion \
{ \
	[self applySnapshotUsingReloadData:snapshot completion:completion]; \
} \
\
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot \
{ \
	[self applySnapshotUsingReloadData:snapshot completion:nil]; \
} \
\
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion \
{ \
	_snapshot = [snapshot copy] ?: [[NSDiffableDataSourceSnapshot alloc] init]; \
	[view reloadData]; \
	if (completion != nil) \
		dispatch_async(dispatch_get_main_queue(), completion); \
} \
\
- (id)itemIdentifierForIndexPath:(NSIndexPath *)indexPath \
{ \
	return [_snapshot uikitItemAtSection:[indexPath section] index:[indexPath item]]; \
} \
\
- (NSIndexPath *)indexPathForItemIdentifier:(id)identifier \
{ \
	return [_snapshot uikitIndexPathOfItem:identifier]; \
} \
\
- (id)sectionIdentifierForIndex:(NSInteger)index \
{ \
	NSArray *sections = [_snapshot sectionIdentifiers]; \
	return index >= 0 && index < (NSInteger)[sections count] ? [sections objectAtIndex:index] : nil; \
} \
\
- (NSInteger)indexForSectionIdentifier:(id)identifier \
{ \
	return [_snapshot indexOfSectionIdentifier:identifier]; \
}

@implementation UITableViewDiffableDataSource {
	__weak UITableView *_tableView;
	UITableViewDiffableDataSourceCellProvider _cellProvider;
	NSDiffableDataSourceSnapshot *_snapshot;
}

@synthesize defaultRowAnimation = _defaultRowAnimation;

- (instancetype)initWithTableView:(UITableView *)tableView cellProvider:(UITableViewDiffableDataSourceCellProvider)cellProvider
{
	if ((self = [super init])) {
		_tableView = tableView;
		_cellProvider = [cellProvider copy];
		_snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
		_defaultRowAnimation = UITableViewRowAnimationAutomatic;
		[tableView setDataSource:self];
	}
	return self;
}

UIKIT_DIFFABLE_COMMON(UITableView, _tableView)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [_snapshot numberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	id identifier = [self sectionIdentifierForIndex:section];
	return identifier != nil ? [_snapshot numberOfItemsInSection:identifier] : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = _cellProvider != nil ? _cellProvider(tableView, indexPath, [self itemIdentifierForIndexPath:indexPath]) : nil;
	if (cell == nil)
		[NSException raise:NSInternalInconsistencyException format:@"UITableView dataSource returned a nil cell for row at index path: %@", indexPath];
	return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return nil; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return nil; }
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return NO; }

@end

@implementation UICollectionViewDiffableDataSource {
	__weak UICollectionView *_collectionView;
	UICollectionViewDiffableDataSourceCellProvider _cellProvider;
	NSDiffableDataSourceSnapshot *_snapshot;
}

@synthesize supplementaryViewProvider = _supplementaryViewProvider;

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView cellProvider:(UICollectionViewDiffableDataSourceCellProvider)cellProvider
{
	if ((self = [super init])) {
		_collectionView = collectionView;
		_cellProvider = [cellProvider copy];
		_snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
		[collectionView setDataSource:self];
	}
	return self;
}

UIKIT_DIFFABLE_COMMON(UICollectionView, _collectionView)

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
	return [_snapshot numberOfSections];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	id identifier = [self sectionIdentifierForIndex:section];
	return identifier != nil ? [_snapshot numberOfItemsInSection:identifier] : 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	UICollectionViewCell *cell = _cellProvider != nil ? _cellProvider(collectionView, indexPath, [self itemIdentifierForIndexPath:indexPath]) : nil;
	if (cell == nil)
		[NSException raise:NSInternalInconsistencyException format:@"UICollectionView dataSource returned a nil cell for item at index path: %@", indexPath];
	return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	return _supplementaryViewProvider != nil ? _supplementaryViewProvider(collectionView, kind, indexPath) : nil;
}

@end
