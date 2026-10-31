/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <Preferences/PSConstants.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface PSListController ()
- (void)_specifiersChanged;
@end

/* Where preference bundles are: the system's, then tweaks' (rootful, then rootless). */
static NSArray *preferenceBundleDirectories(void)
{
	return @[ @"/System/Library/PreferenceBundles", @"/Library/PreferenceBundles", @"/var/jb/Library/PreferenceBundles" ];
}

static NSBundle *preferenceBundleNamed(NSString *name, NSBundle *relativeTo)
{
	if (name.isAbsolutePath)
		return [NSBundle bundleWithPath:name];
	NSString *file = [name.pathExtension length] ? name : [name stringByAppendingPathExtension:@"bundle"];
	NSString *inside = [relativeTo.bundlePath stringByAppendingPathComponent:file];
	if (inside && [[NSFileManager defaultManager] fileExistsAtPath:inside])
		return [NSBundle bundleWithPath:inside];
	for (NSString *directory in preferenceBundleDirectories()) {
		NSString *path = [directory stringByAppendingPathComponent:file];
		if ([[NSFileManager defaultManager] fileExistsAtPath:path])
			return [NSBundle bundleWithPath:path];
	}
	return nil;
}

static NSString *localized(NSBundle *bundle, NSString *table, NSString *string)
{
	if (![string isKindOfClass:[NSString class]] || !bundle)
		return string;
	return [bundle localizedStringForKey:string value:string table:table];
}

static NSArray *localizedArray(NSBundle *bundle, NSString *table, NSArray *strings)
{
	if (![strings isKindOfClass:[NSArray class]])
		return nil;
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:strings.count];
	for (id string in strings)
		[result addObject:localized(bundle, table, string)];
	return result;
}

static UIKeyboardType keyboardTypeFromString(NSString *string)
{
	if (![string isKindOfClass:[NSString class]])
		return [(id) string respondsToSelector:@selector(integerValue)] ? [(id) string integerValue] : UIKeyboardTypeDefault;
	NSDictionary *types = @{ @"numbers": @(UIKeyboardTypeNumbersAndPunctuation), @"phone": @(UIKeyboardTypePhonePad),
		@"url": @(UIKeyboardTypeURL), @"email": @(UIKeyboardTypeEmailAddress), @"number": @(UIKeyboardTypeNumberPad),
		@"decimal": @(UIKeyboardTypeDecimalPad), @"ascii": @(UIKeyboardTypeASCIICapable) };
	return [types[string.lowercaseString] integerValue];
}

static UITextAutocapitalizationType autoCapsFromString(NSString *string)
{
	if (![string isKindOfClass:[NSString class]])
		return [(id) string respondsToSelector:@selector(integerValue)] ? [(id) string integerValue] : UITextAutocapitalizationTypeNone;
	NSDictionary *types = @{ @"words": @(UITextAutocapitalizationTypeWords), @"sentences": @(UITextAutocapitalizationTypeSentences),
		@"all": @(UITextAutocapitalizationTypeAllCharacters), @"allcharacters": @(UITextAutocapitalizationTypeAllCharacters) };
	return [types[string.lowercaseString] integerValue];
}

static PSSpecifier *specifierFromItem(NSDictionary *item, id target, NSString *table, NSBundle *bundle)
{
	PSCellType type = [PSSpecifier cellTypeFromString:item[PSCellClassKey]];
	NSString *label = localized(bundle, table, item[PSTitleKey]);
	NSString *set = item[PSSetterKey], *get = item[PSGetterKey];
	Class detail = NSClassFromString(item[PSDetailControllerClassKey]);
	if (!detail && type == PSLinkListCell)
		detail = [PSListItemsController class];
	Class specifierClass = (type == PSEditTextCell || type == PSSecureEditTextCell) ? [PSTextFieldSpecifier class] : [PSSpecifier class];
	PSSpecifier *specifier = [specifierClass preferenceSpecifierNamed:label target:target
		set:set ? NSSelectorFromString(set) : @selector(setPreferenceValue:specifier:)
		get:get ? NSSelectorFromString(get) : @selector(readPreferenceValue:)
		detail:detail cell:type edit:NSClassFromString(item[PSEditPaneClassKey])];

	[item enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
		[specifier setProperty:value forKey:key];
	}];
	NSString *cellClass = item[PSTableCellClassKey];
	if ([cellClass isKindOfClass:[NSString class]])
		[specifier setProperty:NSClassFromString(cellClass) forKey:PSTableCellClassKey];
	if (item[PSButtonActionKey])
		specifier->action = NSSelectorFromString(item[PSButtonActionKey]);
	if (item[PSFooterTextGroupKey])
		[specifier setProperty:localized(bundle, table, item[PSFooterTextGroupKey]) forKey:PSFooterTextGroupKey];
	if (item[PSPlaceholderKey])
		[specifier setProperty:localized(bundle, table, item[PSPlaceholderKey]) forKey:PSPlaceholderKey];
	if (item[PSStaticTextMessageKey])
		[specifier setProperty:localized(bundle, table, item[PSStaticTextMessageKey]) forKey:PSStaticTextMessageKey];

	NSArray *values = item[PSValidValuesKey];
	if ([values isKindOfClass:[NSArray class]])
		[specifier setValues:values titles:localizedArray(bundle, table, item[PSValidTitlesKey]) ?: values
			shortTitles:localizedArray(bundle, table, item[PSShortTitlesKey])];
	else if (item[PSValuesDataSourceKey])
		[specifier loadValuesAndTitlesFromDataSource];

	[specifier setKeyboardType:keyboardTypeFromString(item[PSKeyboardTypeKey])
		autoCaps:autoCapsFromString(item[PSAutoCapsKey])
		autoCorrection:[item[PSNoAutoCorrectKey] boolValue] ? UITextAutocorrectionTypeNo : UITextAutocorrectionTypeDefault];
	if ([item[PSIsSecureKey] boolValue])
		specifier->textFieldType = PSTextFieldTypeSecure;

	if (item[@"icon"])
		[specifier setupIconImageWithBundle:bundle];

	// A link to another bundle's page, loaded when it is opened.
	NSString *bundleName = item[PSBundlePathKey];
	if ([bundleName isKindOfClass:[NSString class]]) {
		NSBundle *linked = preferenceBundleNamed(bundleName, bundle);
		if (linked) {
			[specifier setProperty:linked.bundlePath forKey:PSLazilyLoadedBundleKey];
			if (item[@"icon"] && ![specifier propertyForKey:PSIconImageKey])
				[specifier setupIconImageWithBundle:linked];
		}
		if (type == PSGroupCell)
			specifier.cellType = PSLinkCell;
	}
	return specifier;
}

NSArray *SpecifiersFromPlist(NSDictionary *plist, PSSpecifier *previous, id target, NSString *plistName, NSBundle *bundle, NSString **title, NSString **specifierID, PSListController *callerList, NSMutableArray **bundleControllers)
{
	NSMutableArray *specifiers = [NSMutableArray array];
	if (title)
		*title = localized(bundle, plistName, plist[PSTitleTableKey]);
	if (specifierID)
		*specifierID = plist[PSIDKey];
	for (NSDictionary *item in plist[PSSpecifiersKey]) {
		if (![item isKindOfClass:[NSDictionary class]])
			continue;
		PSSpecifier *specifier = specifierFromItem(item, target, plistName, bundle);
		if (specifier)
			[specifiers addObject:specifier];
	}
	return specifiers;
}

@protocol PSContentSizeInitializing
- (instancetype)initForContentSize:(CGSize)size;
@end

@implementation PSListController

@synthesize specifierID = _specifierID, forceSynchronousIconLoadForCreatedCells = _forceSynchronousIconLoadForCreatedCells;

/* Each specifier's cell: the cells hold the controls, so they are not reused. */
- (NSMapTable *)_cellMap
{
	if (!_cells)
		_cells = [NSMapTable strongToStrongObjectsMapTable];
	return _cells;
}

- (instancetype)initForContentSize:(CGSize)size
{
	return [self init];
}

- (Class)tableViewClass
{
	return [UITableView class];
}

- (UITableViewStyle)tableViewStyle
{
	return UITableViewStyleGrouped;
}

- (void)loadView
{
	CGRect frame = [UIScreen mainScreen].bounds;
	_table = [[[self tableViewClass] alloc] initWithFrame:frame style:[self tableViewStyle]];
	_table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_table.dataSource = self;
	_table.delegate = self;
	self.view = _table;
}

- (UITableView *)table
{
	return _table;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	// Values may have changed on a page this one opened.
	[self _refreshCachedCells];
	[_table reloadData];
}

- (NSBundle *)bundle
{
	return [NSBundle bundleForClass:[self class]];
}

- (NSString *)localizedStringForKey:(NSString *)key
{
	return localized(self.bundle, nil, key);
}

#pragma mark Specifiers

- (NSArray *)specifiers
{
	return _specifiers;
}

- (void)setSpecifiers:(NSArray *)specifiers
{
	_specifiers = [specifiers mutableCopy];
	[self _specifiersChanged];
}

- (NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target
{
	return [self loadSpecifiersFromPlistName:name target:target bundle:self.bundle];
}

- (NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target bundle:(NSBundle *)bundle
{
	NSString *path = [bundle pathForResource:name ofType:@"plist"];
	NSDictionary *plist = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
	if (!plist) {
		NSLog(@"Preferences: no %@.plist in %@", name, bundle.bundlePath);
		return [NSMutableArray array];
	}
	NSString *title = nil, *identifier = nil;
	NSArray *specifiers = SpecifiersFromPlist(plist, self.specifier, target, name, bundle, &title, &identifier, self, NULL);
	if (title)
		self.title = title;
	if (identifier)
		_specifierID = identifier;
	return [specifiers mutableCopy];
}

- (NSArray *)_allSpecifiers
{
	return [self specifiers] ?: @[];
}

/* The index in the specifiers of each group's first entry: its group specifier, or 0 for rows before any. */
- (NSArray *)_groupStarts
{
	if (_groups)
		return _groups;
	NSArray *specifiers = [self _allSpecifiers];
	_groups = [NSMutableArray array];
	for (NSUInteger i = 0; i < specifiers.count; i++)
		if (i == 0 || [specifiers[i] cellType] == PSGroupCell)
			[_groups addObject:@(i)];
	return _groups;
}

- (void)_specifiersChanged
{
	_groups = nil;
	if (!_reloading)
		[_table reloadData];
}

- (BOOL)_groupHasHeader:(NSInteger)group
{
	NSArray *starts = [self _groupStarts];
	if (group < 0 || (NSUInteger) group >= starts.count)
		return NO;
	return [[self _allSpecifiers][[starts[group] integerValue]] cellType] == PSGroupCell;
}

- (NSInteger)numberOfGroups
{
	return [self _groupStarts].count;
}

- (NSInteger)indexOfGroup:(NSInteger)group
{
	NSArray *starts = [self _groupStarts];
	if (group < 0 || (NSUInteger) group >= starts.count)
		return NSNotFound;
	return [starts[group] integerValue];
}

- (NSInteger)_firstRowIndexOfGroup:(NSInteger)group
{
	NSInteger start = [self indexOfGroup:group];
	return start == NSNotFound ? NSNotFound : start + ([self _groupHasHeader:group] ? 1 : 0);
}

- (NSInteger)rowsForGroup:(NSInteger)group
{
	NSArray *starts = [self _groupStarts];
	if (group < 0 || (NSUInteger) group >= starts.count)
		return 0;
	NSInteger end = (NSUInteger) group + 1 < starts.count ? [starts[group + 1] integerValue] : (NSInteger) [self _allSpecifiers].count;
	return end - [self _firstRowIndexOfGroup:group];
}

- (NSArray *)specifiersInGroup:(NSInteger)group
{
	NSInteger first = [self _firstRowIndexOfGroup:group];
	if (first == NSNotFound)
		return @[];
	return [[self _allSpecifiers] subarrayWithRange:NSMakeRange(first, [self rowsForGroup:group])];
}

- (NSInteger)indexForIndexPath:(NSIndexPath *)indexPath
{
	NSInteger first = [self _firstRowIndexOfGroup:indexPath.section];
	if (first == NSNotFound || indexPath.row >= [self rowsForGroup:indexPath.section])
		return NSNotFound;
	return first + indexPath.row;
}

- (BOOL)getGroup:(NSInteger *)group row:(NSInteger *)row ofSpecifierAtIndex:(NSInteger)index
{
	NSArray *starts = [self _groupStarts];
	if (index < 0 || (NSUInteger) index >= [self _allSpecifiers].count)
		return NO;
	NSInteger found = 0;
	for (NSUInteger g = 0; g < starts.count; g++)
		if ([starts[g] integerValue] <= index)
			found = g;
	NSInteger first = [self _firstRowIndexOfGroup:found];
	if (group)
		*group = found;
	if (row)
		*row = index - first; // -1 for the group specifier itself
	return YES;
}

- (BOOL)getGroup:(NSInteger *)group row:(NSInteger *)row ofSpecifier:(PSSpecifier *)specifier
{
	return [self getGroup:group row:row ofSpecifierAtIndex:[self indexOfSpecifier:specifier]];
}

- (BOOL)getGroup:(NSInteger *)group row:(NSInteger *)row ofSpecifierID:(NSString *)identifier
{
	return [self getGroup:group row:row ofSpecifierAtIndex:[self indexOfSpecifierID:identifier]];
}

- (NSIndexPath *)indexPathForIndex:(NSInteger)index
{
	NSInteger group, row;
	if (![self getGroup:&group row:&row ofSpecifierAtIndex:index] || row < 0)
		return nil;
	return [NSIndexPath indexPathForRow:row inSection:group];
}

- (NSIndexPath *)indexPathForSpecifier:(PSSpecifier *)specifier
{
	return [self indexPathForIndex:[self indexOfSpecifier:specifier]];
}

- (PSSpecifier *)specifierAtIndex:(NSInteger)index
{
	NSArray *specifiers = [self _allSpecifiers];
	return index >= 0 && (NSUInteger) index < specifiers.count ? specifiers[index] : nil;
}

- (PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath
{
	return [self specifierAtIndex:[self indexForIndexPath:indexPath]];
}

- (NSInteger)indexOfSpecifier:(PSSpecifier *)specifier
{
	NSUInteger index = specifier ? [[self _allSpecifiers] indexOfObjectIdenticalTo:specifier] : NSNotFound;
	return index == NSNotFound ? NSNotFound : (NSInteger) index;
}

- (PSSpecifier *)specifierForID:(NSString *)identifier
{
	if (!identifier)
		return nil;
	for (PSSpecifier *specifier in [self _allSpecifiers])
		if ([specifier.identifier isEqual:identifier])
			return specifier;
	return nil;
}

- (NSInteger)indexOfSpecifierID:(NSString *)identifier
{
	return [self indexOfSpecifier:[self specifierForID:identifier]];
}

- (BOOL)containsSpecifier:(PSSpecifier *)specifier
{
	return [self indexOfSpecifier:specifier] != NSNotFound;
}

#pragma mark Changing the specifiers

- (NSMutableArray *)_mutableSpecifiers
{
	NSArray *specifiers = [self _allSpecifiers];
	if (![specifiers isKindOfClass:[NSMutableArray class]])
		_specifiers = specifiers = [specifiers mutableCopy];
	else
		_specifiers = specifiers;
	return (NSMutableArray *) specifiers;
}

- (void)insertContiguousSpecifiers:(NSArray *)specifiers atIndex:(NSInteger)index animated:(BOOL)animated
{
	NSMutableArray *all = [self _mutableSpecifiers];
	if (index < 0 || (NSUInteger) index > all.count)
		index = all.count;
	[all insertObjects:specifiers atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index, specifiers.count)]];
	[self _specifiersChanged];
}

- (void)insertContiguousSpecifiers:(NSArray *)specifiers atIndex:(NSInteger)index
{
	[self insertContiguousSpecifiers:specifiers atIndex:index animated:NO];
}

- (void)insertContiguousSpecifiers:(NSArray *)specifiers afterSpecifier:(PSSpecifier *)other animated:(BOOL)animated
{
	NSInteger index = [self indexOfSpecifier:other];
	[self insertContiguousSpecifiers:specifiers atIndex:index == NSNotFound ? -1 : index + 1 animated:animated];
}

- (void)insertContiguousSpecifiers:(NSArray *)specifiers afterSpecifier:(PSSpecifier *)other
{
	[self insertContiguousSpecifiers:specifiers afterSpecifier:other animated:NO];
}

- (void)insertContiguousSpecifiers:(NSArray *)specifiers afterSpecifierID:(NSString *)identifier animated:(BOOL)animated
{
	[self insertContiguousSpecifiers:specifiers afterSpecifier:[self specifierForID:identifier] animated:animated];
}

- (void)insertContiguousSpecifiers:(NSArray *)specifiers afterSpecifierID:(NSString *)identifier
{
	[self insertContiguousSpecifiers:specifiers afterSpecifierID:identifier animated:NO];
}

- (void)insertSpecifier:(PSSpecifier *)specifier atIndex:(NSInteger)index animated:(BOOL)animated
{
	if (specifier)
		[self insertContiguousSpecifiers:@[ specifier ] atIndex:index animated:animated];
}

- (void)insertSpecifier:(PSSpecifier *)specifier atIndex:(NSInteger)index
{
	[self insertSpecifier:specifier atIndex:index animated:NO];
}

- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifier:(PSSpecifier *)other animated:(BOOL)animated
{
	if (specifier)
		[self insertContiguousSpecifiers:@[ specifier ] afterSpecifier:other animated:animated];
}

- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifier:(PSSpecifier *)other
{
	[self insertSpecifier:specifier afterSpecifier:other animated:NO];
}

- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifierID:(NSString *)identifier animated:(BOOL)animated
{
	[self insertSpecifier:specifier afterSpecifier:[self specifierForID:identifier] animated:animated];
}

- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifierID:(NSString *)identifier
{
	[self insertSpecifier:specifier afterSpecifierID:identifier animated:NO];
}

- (void)insertSpecifier:(PSSpecifier *)specifier atEndOfGroup:(NSInteger)group animated:(BOOL)animated
{
	NSInteger first = [self _firstRowIndexOfGroup:group];
	NSInteger index = first == NSNotFound ? -1 : first + [self rowsForGroup:group];
	[self insertSpecifier:specifier atIndex:index animated:animated];
}

- (void)insertSpecifier:(PSSpecifier *)specifier atEndOfGroup:(NSInteger)group
{
	[self insertSpecifier:specifier atEndOfGroup:group animated:NO];
}

- (void)addSpecifiersFromArray:(NSArray *)specifiers animated:(BOOL)animated
{
	[self insertContiguousSpecifiers:specifiers atIndex:-1 animated:animated];
}

- (void)addSpecifiersFromArray:(NSArray *)specifiers
{
	[self addSpecifiersFromArray:specifiers animated:NO];
}

- (void)addSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated
{
	if (specifier)
		[self addSpecifiersFromArray:@[ specifier ] animated:animated];
}

- (void)addSpecifier:(PSSpecifier *)specifier
{
	[self addSpecifier:specifier animated:NO];
}

- (void)removeContiguousSpecifiers:(NSArray *)specifiers animated:(BOOL)animated
{
	NSMutableArray *all = [self _mutableSpecifiers];
	for (PSSpecifier *specifier in specifiers) {
		NSUInteger index = [all indexOfObjectIdenticalTo:specifier];
		if (index != NSNotFound)
			[all removeObjectAtIndex:index];
		[[self _cellMap] removeObjectForKey:specifier];
	}
	[self _specifiersChanged];
}

- (void)removeContiguousSpecifiers:(NSArray *)specifiers
{
	[self removeContiguousSpecifiers:specifiers animated:NO];
}

- (void)removeSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated
{
	if (specifier)
		[self removeContiguousSpecifiers:@[ specifier ] animated:animated];
}

- (void)removeSpecifier:(PSSpecifier *)specifier
{
	[self removeSpecifier:specifier animated:NO];
}

- (void)removeSpecifierID:(NSString *)identifier animated:(BOOL)animated
{
	[self removeSpecifier:[self specifierForID:identifier] animated:animated];
}

- (void)removeSpecifierID:(NSString *)identifier
{
	[self removeSpecifierID:identifier animated:NO];
}

- (void)removeSpecifierAtIndex:(NSInteger)index animated:(BOOL)animated
{
	[self removeSpecifier:[self specifierAtIndex:index] animated:animated];
}

- (void)removeSpecifierAtIndex:(NSInteger)index
{
	[self removeSpecifierAtIndex:index animated:NO];
}

- (void)removeLastSpecifierAnimated:(BOOL)animated
{
	[self removeSpecifier:[[self _allSpecifiers] lastObject] animated:animated];
}

- (void)removeLastSpecifier
{
	[self removeLastSpecifierAnimated:NO];
}

- (void)replaceContiguousSpecifiers:(NSArray *)specifiers withSpecifiers:(NSArray *)replacements animated:(BOOL)animated
{
	NSInteger index = [self indexOfSpecifier:specifiers.firstObject];
	BOOL reloading = _reloading;
	_reloading = YES;
	[self removeContiguousSpecifiers:specifiers animated:NO];
	[self insertContiguousSpecifiers:replacements atIndex:index == NSNotFound ? -1 : index animated:NO];
	_reloading = reloading;
	[self _specifiersChanged];
}

- (void)replaceContiguousSpecifiers:(NSArray *)specifiers withSpecifiers:(NSArray *)replacements
{
	[self replaceContiguousSpecifiers:specifiers withSpecifiers:replacements animated:NO];
}

- (void)updateSpecifiers:(NSArray *)old withSpecifiers:(NSArray *)specifiers
{
	[self replaceContiguousSpecifiers:old withSpecifiers:specifiers];
}

#pragma mark Reloading

- (void)clearCache
{
	[[self _cellMap] removeAllObjects];
}

- (void)setCachesCells:(BOOL)caches
{
	_cachesCells = caches;
}

- (PSTableCell *)cachedCellForSpecifier:(PSSpecifier *)specifier
{
	return specifier ? [[self _cellMap] objectForKey:specifier] : nil;
}

- (PSTableCell *)cachedCellForSpecifierID:(NSString *)identifier
{
	return [self cachedCellForSpecifier:[self specifierForID:identifier]];
}

- (void)reloadSpecifiers
{
	[self clearCache];
	_groups = nil;
	_reloading = YES;
	[self specifiers];
	_reloading = NO;
	[self _specifiersChanged];
}

- (void)reload
{
	[self reloadSpecifiers];
}

- (void)reloadSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated
{
	if (!specifier)
		return;
	PSTableCell *cell = [self cachedCellForSpecifier:specifier];
	if (cell) {
		[cell refreshCellContentsWithSpecifier:specifier];
		[self _loadValueOfCell:cell];
	}
	[_table reloadData];
}

- (void)reloadSpecifier:(PSSpecifier *)specifier
{
	[self reloadSpecifier:specifier animated:NO];
}

- (void)reloadSpecifierID:(NSString *)identifier animated:(BOOL)animated
{
	[self reloadSpecifier:[self specifierForID:identifier] animated:animated];
}

- (void)reloadSpecifierID:(NSString *)identifier
{
	[self reloadSpecifierID:identifier animated:NO];
}

- (void)reloadSpecifierAtIndex:(NSInteger)index animated:(BOOL)animated
{
	[self reloadSpecifier:[self specifierAtIndex:index] animated:animated];
}

- (void)reloadSpecifierAtIndex:(NSInteger)index
{
	[self reloadSpecifierAtIndex:index animated:NO];
}

#pragma mark Cells

static BOOL showsValue(PSCellType type)
{
	switch (type) {
	case PSLinkListCell:
	case PSTitleValueCell:
	case PSSliderCell:
	case PSSwitchCell:
	case PSEditTextCell:
	case PSSecureEditTextCell:
	case PSSegmentCell:
	case PSEditTextViewCell:
		return YES;
	default:
		return NO;
	}
}

static Class cellClassForType(PSCellType type)
{
	switch (type) {
	case PSSwitchCell: return [PSSwitchTableCell class];
	case PSSliderCell: return [PSSliderTableCell class];
	case PSSegmentCell: return [PSSegmentTableCell class];
	case PSEditTextCell:
	case PSSecureEditTextCell:
	case PSEditTextViewCell:
		return [PSEditableTableCell class];
	default: return [PSTableCell class];
	}
}

/* The group specifier of a radio group the specifier is a row of, if it is one. */
- (PSSpecifier *)_radioGroupOfSpecifier:(PSSpecifier *)specifier
{
	NSInteger group, row;
	if (![self getGroup:&group row:&row ofSpecifier:specifier] || row < 0 || ![self _groupHasHeader:group])
		return nil;
	PSSpecifier *header = [self specifierAtIndex:[self indexOfGroup:group]];
	return [[header propertyForKey:PSIsRadioGroupKey] boolValue] ? header : nil;
}

- (void)_loadValueOfCell:(PSTableCell *)cell
{
	PSSpecifier *specifier = cell.specifier;
	if (showsValue(specifier.cellType))
		cell.value = [specifier performGetter];
	PSSpecifier *radio = [self _radioGroupOfSpecifier:specifier];
	if (radio) {
		id current = [radio performGetter];
		id value = [specifier propertyForKey:PSValueKey];
		cell.checked = current ? [current isEqual:value] : [radio propertyForKey:PSRadioGroupCheckedSpecifierKey] == specifier;
	}
}

- (void)_refreshCachedCells
{
	for (PSTableCell *cell in [[[self _cellMap] objectEnumerator] allObjects])
		[self _loadValueOfCell:cell];
}

- (PSTableCell *)_cellForSpecifier:(PSSpecifier *)specifier
{
	PSTableCell *cell = [self cachedCellForSpecifier:specifier];
	if (cell)
		return cell;
	Class cls = [specifier propertyForKey:PSTableCellClassKey];
	if (cls && !class_isMetaClass(object_getClass(cls)))
		cls = NSClassFromString((NSString *) cls);
	if (!cls)
		cls = cellClassForType(specifier.cellType);
	UITableViewCellStyle style = [cls respondsToSelector:@selector(cellStyle)] ? [cls cellStyle] : UITableViewCellStyleValue1;
	NSString *reuse = [cls respondsToSelector:@selector(reuseIdentifierForSpecifier:)] ? [cls reuseIdentifierForSpecifier:specifier] : NSStringFromClass(cls);
	cell = [[cls alloc] initWithStyle:style reuseIdentifier:reuse specifier:specifier];
	if (!cell)
		return nil;
	[specifier setProperty:cell forKey:PSTableCellKey];
	[self _loadValueOfCell:cell];
	[[self _cellMap] setObject:cell forKey:specifier];
	return cell;
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [self numberOfGroups];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self rowsForGroup:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
	UITableViewCell *cell = specifier ? [self _cellForSpecifier:specifier] : nil;
	return cell ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (![self _groupHasHeader:section])
		return nil;
	NSString *name = [self specifierAtIndex:[self indexOfGroup:section]].name;
	return name.length ? name : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if (![self _groupHasHeader:section])
		return nil;
	return [[self specifierAtIndex:[self indexOfGroup:section]] propertyForKey:PSFooterTextGroupKey];
}

#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
	NSNumber *height = [specifier propertyForKey:PSTableCellHeightKey];
	if (height)
		return height.doubleValue;
	if (specifier.cellType == PSGiantCell || specifier.cellType == PSGiantIconCell)
		return 64;
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (!specifier)
		return;
	id enabled = [specifier propertyForKey:PSEnabledKey];
	if (enabled && ![enabled boolValue])
		return;

	PSSpecifier *radio = [self _radioGroupOfSpecifier:specifier];
	if (radio) {
		[radio setProperty:specifier forKey:PSRadioGroupCheckedSpecifierKey];
		id value = [specifier propertyForKey:PSValueKey];
		if (value)
			[radio performSetterWithValue:value];
		for (PSSpecifier *row in [self specifiersInGroup:indexPath.section])
			[self cachedCellForSpecifier:row].checked = row == specifier;
		return;
	}

	switch (specifier.cellType) {
	case PSLinkCell:
	case PSLinkListCell: {
		UIViewController *controller = [self controllerForSpecifier:specifier];
		if (controller)
			[self pushController:controller animate:YES];
		else if (specifier->action)
			[specifier performButtonAction];
		break;
	}
	case PSButtonCell:
		if ([specifier propertyForKey:PSConfirmationKey])
			[self showConfirmationViewForSpecifier:specifier];
		else
			[specifier performButtonAction];
		break;
	case PSEditTextCell:
	case PSSecureEditTextCell:
		[[(PSEditableTableCell *) [self cachedCellForSpecifier:specifier] textField] becomeFirstResponder];
		break;
	default:
		if (specifier->action)
			[specifier performButtonAction];
		break;
	}
}

#pragma mark Opening pages

- (void)lazyLoadBundle:(PSSpecifier *)specifier
{
	NSString *path = [specifier propertyForKey:PSLazilyLoadedBundleKey];
	if (!path)
		return;
	NSBundle *bundle = [NSBundle bundleWithPath:path];
	NSError *error = nil;
	if (![bundle loadAndReturnError:&error]) {
		NSLog(@"Preferences: cannot load %@: %@", path, error);
		return;
	}
	Class principal = bundle.principalClass;
	if (principal)
		specifier.detailControllerClass = principal;
	[specifier removePropertyForKey:PSLazilyLoadedBundleKey];
}

- (UIViewController *)controllerForSpecifier:(PSSpecifier *)specifier
{
	if ([specifier propertyForKey:PSLazilyLoadedBundleKey])
		[self lazyLoadBundle:specifier];
	Class cls = specifier.detailControllerClass;
	if (!cls)
		return nil;
	/* iOS's Preferences made a pane for its size: older ones (WinterBoard's
	   theme list) build their views there rather than in -loadView. */
	UIViewController *controller;
	if ([cls instancesRespondToSelector:@selector(initForContentSize:)])
		controller = [(id<PSContentSizeInitializing>)[cls alloc] initForContentSize:self.view.bounds.size];
	else
		controller = [[cls alloc] init];
	if ([controller respondsToSelector:@selector(setRootController:)])
		[(id) controller setRootController:self.rootController];
	if ([controller respondsToSelector:@selector(setParentController:)])
		[(id) controller setParentController:self];
	if ([controller respondsToSelector:@selector(setSpecifier:)])
		[(id) controller setSpecifier:specifier];
	SEL load = specifier.controllerLoadAction;
	if (load && [controller respondsToSelector:load])
		((void (*)(id, SEL, id)) objc_msgSend)(controller, load, specifier);
	if (!controller.title.length)
		controller.title = specifier.name;
	return controller;
}

- (void)showConfirmationViewForSpecifier:(PSSpecifier *)specifier
{
	// There is no action sheet to ask with yet: going ahead is the confirmation.
	[self confirmationViewAcceptedForSpecifier:specifier];
}

- (void)confirmationViewAcceptedForSpecifier:(PSSpecifier *)specifier
{
	SEL confirmation = specifier.confirmationAction;
	id target = specifier.target;
	if (confirmation && [target respondsToSelector:confirmation])
		((void (*)(id, SEL, id)) objc_msgSend)(target, confirmation, specifier);
	else
		[specifier performButtonAction];
}

- (void)confirmationViewCancelledForSpecifier:(PSSpecifier *)specifier
{
}

- (void)returnPressedAtEnd
{
	[self.view endEditing:YES];
}

@end

@implementation PSListItemsController

- (NSArray *)itemsFromParent
{
	PSSpecifier *parent = self.specifier;
	if (!parent.values && [parent propertyForKey:PSValuesDataSourceKey])
		[parent loadValuesAndTitlesFromDataSource];
	NSMutableArray *items = [NSMutableArray array];
	PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
	NSString *footer = [parent propertyForKey:PSStaticTextMessageKey];
	if (footer)
		[group setProperty:footer forKey:PSFooterTextGroupKey];
	[items addObject:group];
	for (id value in parent.values) {
		NSString *title = parent.titleDictionary[value] ?: ([value isKindOfClass:[NSString class]] ? value : [value description]);
		PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:title target:self set:NULL get:NULL detail:Nil cell:PSListItemCell edit:Nil];
		[item setProperty:value forKey:PSValueKey];
		[items addObject:item];
	}
	return items;
}

- (NSArray *)specifiers
{
	if (!_specifiers)
		_specifiers = [[self itemsFromParent] mutableCopy];
	return _specifiers;
}

- (void)setSpecifier:(PSSpecifier *)specifier
{
	[super setSpecifier:specifier];
	_specifiers = nil;
	[self _specifiersChanged];
	if (!self.title.length)
		self.title = specifier.name;
}

- (void)_markChecked
{
	id current = [self.specifier performGetter];
	for (PSSpecifier *item in [self specifiers])
		if (item.cellType == PSListItemCell)
			[self cachedCellForSpecifier:item].checked = current && [current isEqual:[item propertyForKey:PSValueKey]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	PSSpecifier *item = [self specifierAtIndexPath:indexPath];
	if ([cell isKindOfClass:[PSTableCell class]]) {
		id current = [self.specifier performGetter];
		((PSTableCell *) cell).checked = current && [current isEqual:[item propertyForKey:PSValueKey]];
	}
	return cell;
}

- (void)setValueForSpecifier:(PSSpecifier *)specifier defaultValue:(id)value
{
	[self.specifier performSetterWithValue:value];
}

- (void)listItemSelected:(NSIndexPath *)indexPath
{
	PSSpecifier *item = [self specifierAtIndexPath:indexPath];
	id value = [item propertyForKey:PSValueKey];
	if (!value)
		return;
	[self setValueForSpecifier:self.specifier defaultValue:value];
	[self _markChecked];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self listItemSelected:indexPath];
}

@end
