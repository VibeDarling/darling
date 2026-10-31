/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef PREFERENCES_PSLISTCONTROLLER_H
#define PREFERENCES_PSLISTCONTROLLER_H

#import <Preferences/PSViewController.h>

@class PSSpecifier, PSTableCell;

/*
 * A page of settings: a grouped table of its specifiers, where each group
 * specifier starts a section. Subclasses override -specifiers, usually to
 * load a plist into _specifiers the first time:
 *
 *	- (NSArray *)specifiers {
 *		if (!_specifiers)
 *			_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
 *		return _specifiers;
 *	}
 */
@interface PSListController : PSViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate> {
@public
	NSArray *_specifiers;
@protected
	UITableView *_table;
	NSMutableArray *_groups; // where in _specifiers each group starts
	NSMapTable *_cells;
	NSString *_specifierID;
	BOOL _cachesCells;
	BOOL _reloading;
	BOOL _forceSynchronousIconLoadForCreatedCells;
}

@property (nonatomic, copy) NSArray *specifiers;
@property (nonatomic, readonly) UITableView *table;
@property (nonatomic, copy) NSString *specifierID;
@property (nonatomic, readonly) NSBundle *bundle;
@property (nonatomic) BOOL forceSynchronousIconLoadForCreatedCells;

- (UITableView *)table;
- (Class)tableViewClass;
- (UITableViewStyle)tableViewStyle;

- (NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target bundle:(NSBundle *)bundle;
- (NSArray *)specifiersInGroup:(NSInteger)group;

- (PSSpecifier *)specifierForID:(NSString *)identifier;
- (PSSpecifier *)specifierAtIndex:(NSInteger)index;
- (PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)indexOfSpecifier:(PSSpecifier *)specifier;
- (NSInteger)indexOfSpecifierID:(NSString *)identifier;
- (NSInteger)indexForIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForSpecifier:(PSSpecifier *)specifier;
- (NSIndexPath *)indexPathForIndex:(NSInteger)index;
- (NSInteger)indexOfGroup:(NSInteger)group;
- (NSInteger)numberOfGroups;
- (NSInteger)rowsForGroup:(NSInteger)group;
- (BOOL)getGroup:(NSInteger *)group row:(NSInteger *)row ofSpecifier:(PSSpecifier *)specifier;
- (BOOL)getGroup:(NSInteger *)group row:(NSInteger *)row ofSpecifierID:(NSString *)identifier;
- (BOOL)getGroup:(NSInteger *)group row:(NSInteger *)row ofSpecifierAtIndex:(NSInteger)index;
- (BOOL)containsSpecifier:(PSSpecifier *)specifier;

- (void)reloadSpecifiers;
- (void)reloadSpecifier:(PSSpecifier *)specifier;
- (void)reloadSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
- (void)reloadSpecifierID:(NSString *)identifier;
- (void)reloadSpecifierID:(NSString *)identifier animated:(BOOL)animated;
- (void)reloadSpecifierAtIndex:(NSInteger)index;
- (void)reloadSpecifierAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)reload;

- (void)insertSpecifier:(PSSpecifier *)specifier atIndex:(NSInteger)index;
- (void)insertSpecifier:(PSSpecifier *)specifier atIndex:(NSInteger)index animated:(BOOL)animated;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifier:(PSSpecifier *)other;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifier:(PSSpecifier *)other animated:(BOOL)animated;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifierID:(NSString *)identifier;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifierID:(NSString *)identifier animated:(BOOL)animated;
- (void)insertSpecifier:(PSSpecifier *)specifier atEndOfGroup:(NSInteger)group;
- (void)insertSpecifier:(PSSpecifier *)specifier atEndOfGroup:(NSInteger)group animated:(BOOL)animated;
- (void)insertContiguousSpecifiers:(NSArray *)specifiers atIndex:(NSInteger)index;
- (void)insertContiguousSpecifiers:(NSArray *)specifiers atIndex:(NSInteger)index animated:(BOOL)animated;
- (void)insertContiguousSpecifiers:(NSArray *)specifiers afterSpecifier:(PSSpecifier *)other;
- (void)insertContiguousSpecifiers:(NSArray *)specifiers afterSpecifier:(PSSpecifier *)other animated:(BOOL)animated;
- (void)insertContiguousSpecifiers:(NSArray *)specifiers afterSpecifierID:(NSString *)identifier;
- (void)insertContiguousSpecifiers:(NSArray *)specifiers afterSpecifierID:(NSString *)identifier animated:(BOOL)animated;
- (void)addSpecifier:(PSSpecifier *)specifier;
- (void)addSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
- (void)addSpecifiersFromArray:(NSArray *)specifiers;
- (void)addSpecifiersFromArray:(NSArray *)specifiers animated:(BOOL)animated;
- (void)removeSpecifier:(PSSpecifier *)specifier;
- (void)removeSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
- (void)removeSpecifierID:(NSString *)identifier;
- (void)removeSpecifierID:(NSString *)identifier animated:(BOOL)animated;
- (void)removeSpecifierAtIndex:(NSInteger)index;
- (void)removeSpecifierAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)removeContiguousSpecifiers:(NSArray *)specifiers;
- (void)removeContiguousSpecifiers:(NSArray *)specifiers animated:(BOOL)animated;
- (void)removeLastSpecifier;
- (void)removeLastSpecifierAnimated:(BOOL)animated;
- (void)replaceContiguousSpecifiers:(NSArray *)specifiers withSpecifiers:(NSArray *)replacements;
- (void)replaceContiguousSpecifiers:(NSArray *)specifiers withSpecifiers:(NSArray *)replacements animated:(BOOL)animated;
- (void)updateSpecifiers:(NSArray *)old withSpecifiers:(NSArray *)specifiers;

- (PSTableCell *)cachedCellForSpecifier:(PSSpecifier *)specifier;
- (PSTableCell *)cachedCellForSpecifierID:(NSString *)identifier;
- (void)clearCache;
- (void)setCachesCells:(BOOL)caches;

/* Opens the page a link specifier leads to. */
- (UIViewController *)controllerForSpecifier:(PSSpecifier *)specifier;
- (void)lazyLoadBundle:(PSSpecifier *)specifier;
- (void)showConfirmationViewForSpecifier:(PSSpecifier *)specifier;
- (void)confirmationViewAcceptedForSpecifier:(PSSpecifier *)specifier;
- (void)confirmationViewCancelledForSpecifier:(PSSpecifier *)specifier;
- (void)returnPressedAtEnd;

- (NSString *)localizedStringForKey:(NSString *)key;
@end

/* The choices of a PSLinkListCell, one checkmarked. */
@interface PSListItemsController : PSListController
- (NSArray *)itemsFromParent;
- (void)setValueForSpecifier:(PSSpecifier *)specifier defaultValue:(id)value;
@end

/* Loads a plist's specifiers. iOS exports this for PreferenceLoader. */
#ifdef __cplusplus
extern "C"
#endif
NSArray *SpecifiersFromPlist(NSDictionary *plist, PSSpecifier *previous, id target, NSString *plistName, NSBundle *bundle, NSString **title, NSString **specifierID, PSListController *callerList, NSMutableArray **bundleControllers);

#endif /* PREFERENCES_PSLISTCONTROLLER_H */
