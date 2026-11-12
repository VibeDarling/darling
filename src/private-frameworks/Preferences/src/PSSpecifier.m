/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <Preferences/PSSpecifier.h>
#import <Preferences/PSConstants.h>
#import <objc/message.h>

NSString *const PSIDKey = @"id";
NSString *const PSCellClassKey = @"cell";
NSString *const PSTableCellClassKey = @"cellClass";
NSString *const PSTableCellKey = @"cellObject";
NSString *const PSTableCellHeightKey = @"height";
NSString *const PSTableCellUseEtchedAppearanceKey = @"useEtched";
NSString *const PSTitleKey = @"label";
NSString *const PSDefaultsKey = @"defaults";
NSString *const PSKeyNameKey = @"key";
NSString *const PSDefaultValueKey = @"default";
NSString *const PSValueKey = @"value";
NSString *const PSValidValuesKey = @"validValues";
NSString *const PSValidTitlesKey = @"validTitles";
NSString *const PSShortTitlesKey = @"shortTitles";
NSString *const PSValuesDataSourceKey = @"valuesDataSource";
NSString *const PSTitlesDataSourceKey = @"titlesDataSource";
NSString *const PSControlMinimumKey = @"min";
NSString *const PSControlMaximumKey = @"max";
NSString *const PSControlIsLoadingKey = @"loading";
NSString *const PSControlKey = @"control";
NSString *const PSSliderShowValueKey = @"showValue";
NSString *const PSSliderIsSegmented = @"isSegmented";
NSString *const PSSliderSegmentCount = @"segmentCount";
NSString *const PSValueChangedNotificationKey = @"PostNotification";
NSString *const PSButtonActionKey = @"action";
NSString *const PSActionKey = @"action";
NSString *const PSConfirmationKey = @"confirmation";
NSString *const PSFooterTextGroupKey = @"footerText";
NSString *const PSFooterAlignmentGroupKey = @"footerAlignment";
NSString *const PSFooterCellClassGroupKey = @"footerCellClass";
NSString *const PSHeaderCellClassGroupKey = @"headerCellClass";
NSString *const PSIsRadioGroupKey = @"isRadioGroup";
NSString *const PSRadioGroupCheckedSpecifierKey = @"radioGroupCheckedSpecifier";
NSString *const PSEnabledKey = @"enabled";
NSString *const PSIconImageKey = @"iconImage";
NSString *const PSIconImageShouldFlipForRightToLeftKey = @"iconImageShouldFlipForRightToLeft";
NSString *const PSLazyIconLoading = @"useLazyIcons";
NSString *const PSSetterKey = @"set";
NSString *const PSGetterKey = @"get";
NSString *const PSDetailControllerClassKey = @"detail";
NSString *const PSEditPaneClassKey = @"pane";
NSString *const PSLazilyLoadedBundleKey = @"lazy-bundle";
NSString *const PSBundlePathKey = @"bundle";
NSString *const PSBundleIsControllerKey = @"isController";
NSString *const PSBundleHasIconKey = @"hasIcon";
NSString *const PSKeyboardTypeKey = @"keyboard";
NSString *const PSAutoCapsKey = @"autoCaps";
NSString *const PSNoAutoCorrectKey = @"noAutoCorrect";
NSString *const PSIsSecureKey = @"isSecure";
NSString *const PSPlaceholderKey = @"placeholder";
NSString *const PSAlignmentKey = @"alignment";
NSString *const PSCopyableCellKey = @"isCopyable";
NSString *const PSStaticTextMessageKey = @"staticTextMessage";
NSString *const PSPrioritizeValueTextDisplayKey = @"prioritizeValueTextDisplay";
NSString *const PSTextViewBottomMarginKey = @"textViewBottomMargin";
NSString *const PSSpecifiersKey = @"items";
NSString *const PSTitleTableKey = @"title";

static NSArray *cellTypeNames(void)
{
	static NSArray *names;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		// In PSCellType's order.
		names = @[ @"PSGroupCell", @"PSLinkCell", @"PSLinkListCell", @"PSListItemCell",
			@"PSTitleValueCell", @"PSSliderCell", @"PSSwitchCell", @"PSStaticTextCell",
			@"PSEditTextCell", @"PSSegmentCell", @"PSGiantIconCell", @"PSGiantCell",
			@"PSSecureEditTextCell", @"PSButtonCell", @"PSEditTextViewCell", @"PSSpinnerCell" ];
	});
	return names;
}

NSString *PSStringFromCellType(PSCellType type)
{
	NSArray *names = cellTypeNames();
	return type >= 0 && (NSUInteger) type < names.count ? names[type] : nil;
}

@implementation PSSpecifier

+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)aTarget set:(SEL)set get:(SEL)get detail:(Class)detail cell:(PSCellType)cell edit:(Class)edit
{
	PSSpecifier *specifier = [[self alloc] init];
	specifier->_name = [name copy];
	specifier->target = aTarget;
	specifier->setter = set;
	specifier->getter = get;
	specifier->detailControllerClass = detail;
	specifier->cellType = cell;
	specifier->editPaneClass = edit;
	return specifier;
}

+ (instancetype)groupSpecifierWithName:(NSString *)name
{
	return [self preferenceSpecifierNamed:name target:nil set:NULL get:NULL detail:Nil cell:PSGroupCell edit:Nil];
}

+ (instancetype)groupSpecifierWithHeader:(NSString *)header footer:(NSString *)footer
{
	PSSpecifier *specifier = [self groupSpecifierWithName:header];
	if (footer)
		[specifier setProperty:footer forKey:PSFooterTextGroupKey];
	return specifier;
}

+ (instancetype)emptyGroupSpecifier
{
	return [self groupSpecifierWithName:nil];
}

+ (instancetype)groupSpecifierWithID:(NSString *)identifier
{
	return [self groupSpecifierWithID:identifier name:nil];
}

+ (instancetype)groupSpecifierWithID:(NSString *)identifier name:(NSString *)name
{
	PSSpecifier *specifier = [self groupSpecifierWithName:name];
	specifier.identifier = identifier;
	return specifier;
}

+ (instancetype)deleteButtonSpecifierWithName:(NSString *)name target:(id)aTarget action:(SEL)anAction
{
	PSSpecifier *specifier = [self preferenceSpecifierNamed:name target:aTarget set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
	specifier->action = anAction;
	[specifier setProperty:@YES forKey:@"isDestructive"];
	return specifier;
}

+ (PSCellType)cellTypeFromString:(NSString *)string
{
	if (![string isKindOfClass:[NSString class]])
		return [string respondsToSelector:@selector(integerValue)] ? [(id) string integerValue] : PSGroupCell;
	NSUInteger index = [cellTypeNames() indexOfObject:string];
	if (index != NSNotFound)
		return (PSCellType) index;
	// "PSSwitchTableCell" and the like name the class as the type.
	if ([string hasSuffix:@"TableCell"]) {
		NSString *cell = [[string substringToIndex:string.length - 9] stringByAppendingString:@"Cell"];
		index = [cellTypeNames() indexOfObject:cell];
		if (index != NSNotFound)
			return (PSCellType) index;
	}
	return string.length && [string characterAtIndex:0] >= '0' && [string characterAtIndex:0] <= '9' ? string.integerValue : PSLinkCell;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_properties = [NSMutableDictionary dictionary];
		autoCorrectionType = UITextAutocorrectionTypeDefault;
	}
	return self;
}

- (id)target { return target; }
- (void)setTarget:(id)aTarget { target = aTarget; }
- (NSString *)name { return _name; }
- (void)setName:(NSString *)name { _name = [name copy]; }
- (PSCellType)cellType { return cellType; }
- (void)setCellType:(PSCellType)type { cellType = type; }
- (Class)detailControllerClass { return detailControllerClass; }
- (void)setDetailControllerClass:(Class)cls { detailControllerClass = cls; }
- (Class)editPaneClass { return editPaneClass; }
- (void)setEditPaneClass:(Class)cls { editPaneClass = cls; }
- (NSMutableDictionary *)properties { return _properties; }
- (void)setProperties:(NSMutableDictionary *)properties { _properties = [properties mutableCopy] ?: [NSMutableDictionary dictionary]; }
- (NSDictionary *)titleDictionary { return _titleDict; }
- (void)setTitleDictionary:(NSDictionary *)titles { _titleDict = titles; }
- (NSDictionary *)shortTitleDictionary { return _shortTitleDict; }
- (void)setShortTitleDictionary:(NSDictionary *)titles { _shortTitleDict = titles; }
- (NSArray *)values { return _values; }
- (void)setValues:(NSArray *)values { _values = values; }
- (id)userInfo { return _userInfo; }
- (void)setUserInfo:(id)userInfo { _userInfo = userInfo; }
- (SEL)buttonAction { return action; }
- (void)setButtonAction:(SEL)anAction { action = anAction; }
- (SEL)confirmationAction { return NSSelectorFromString([self propertyForKey:@"confirmationAction"]); }
- (void)setConfirmationAction:(SEL)anAction { [self setProperty:anAction ? NSStringFromSelector(anAction) : nil forKey:@"confirmationAction"]; }
- (SEL)controllerLoadAction { return NSSelectorFromString([self propertyForKey:@"controllerLoadAction"]); }
- (void)setControllerLoadAction:(SEL)anAction { [self setProperty:anAction ? NSStringFromSelector(anAction) : nil forKey:@"controllerLoadAction"]; }

- (NSString *)identifier
{
	NSString *identifier = _properties[PSIDKey];
	return identifier ?: _name;
}

- (void)setIdentifier:(NSString *)identifier
{
	[self setProperty:identifier forKey:PSIDKey];
}

- (id)propertyForKey:(NSString *)key
{
	return key ? _properties[key] : nil;
}

- (void)setProperty:(id)property forKey:(NSString *)key
{
	if (!key)
		return;
	if (property)
		_properties[key] = property;
	else
		[_properties removeObjectForKey:key];
}

- (void)removePropertyForKey:(NSString *)key
{
	if (key)
		[_properties removeObjectForKey:key];
}

static NSDictionary *titlesFor(NSArray *values, NSArray *titles)
{
	if (!titles)
		return nil;
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	NSUInteger count = MIN(values.count, titles.count);
	for (NSUInteger i = 0; i < count; i++)
		dictionary[values[i]] = titles[i];
	return dictionary;
}

- (void)setValues:(NSArray *)values titles:(NSArray *)titles
{
	[self setValues:values titles:titles shortTitles:nil];
}

- (void)setValues:(NSArray *)values titles:(NSArray *)titles shortTitles:(NSArray *)shortTitles
{
	_values = [values copy];
	_titleDict = titlesFor(values, titles);
	_shortTitleDict = titlesFor(values, shortTitles);
}

- (void)setValues:(NSArray *)values titles:(NSArray *)titles shortTitles:(NSArray *)shortTitles usingLocalizedTitleSorting:(BOOL)sort
{
	if (sort && titles.count == values.count) {
		NSArray *order = [titles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
		NSMutableArray *sortedValues = [NSMutableArray array], *sortedShort = shortTitles ? [NSMutableArray array] : nil;
		for (NSString *title in order) {
			NSUInteger i = [titles indexOfObject:title];
			[sortedValues addObject:values[i]];
			if (sortedShort && i < shortTitles.count)
				[sortedShort addObject:shortTitles[i]];
		}
		values = sortedValues;
		titles = order;
		shortTitles = sortedShort;
	}
	[self setValues:values titles:titles shortTitles:shortTitles];
}

static id askTarget(id aTarget, NSString *selectorName, PSSpecifier *specifier)
{
	if (!aTarget || !selectorName.length)
		return nil;
	SEL selector = NSSelectorFromString(selectorName);
	if (![aTarget respondsToSelector:selector])
		return nil;
	if ([selectorName hasSuffix:@":"])
		return ((id (*)(id, SEL, id)) objc_msgSend)(aTarget, selector, specifier);
	return ((id (*)(id, SEL)) objc_msgSend)(aTarget, selector);
}

- (void)loadValuesAndTitlesFromDataSource
{
	id aTarget = target;
	NSArray *values = askTarget(aTarget, _properties[PSValuesDataSourceKey], self);
	NSArray *titles = askTarget(aTarget, _properties[PSTitlesDataSourceKey], self);
	if (values)
		[self setValues:values titles:titles ?: values];
}

- (void)setupIconImageWithBundle:(NSBundle *)bundle
{
	NSString *name = _properties[@"icon"];
	if (!name)
		return;
	NSString *path = [bundle pathForResource:name ofType:nil];
	if (!path)
		path = [bundle pathForResource:[[name stringByDeletingPathExtension] stringByAppendingString:@"@2x"] ofType:name.pathExtension.length ? name.pathExtension : @"png"];
	if (!path)
		path = [bundle pathForResource:name ofType:@"png"];
	if (path)
		[self setupIconImageWithPath:path];
}

- (void)setupIconImageWithPath:(NSString *)path
{
	UIImage *image = [UIImage imageWithContentsOfFile:path];
	if (image)
		[self setProperty:image forKey:PSIconImageKey];
}

- (void)setKeyboardType:(UIKeyboardType)type autoCaps:(UITextAutocapitalizationType)autoCaps autoCorrection:(UITextAutocorrectionType)autoCorrection
{
	keyboardType = type;
	autoCapsType = autoCaps;
	autoCorrectionType = autoCorrection;
}

- (id)performGetter
{
	id aTarget = target;
	if (!aTarget || !getter || ![aTarget respondsToSelector:getter])
		return nil;
	return ((id (*)(id, SEL, id)) objc_msgSend)(aTarget, getter, self);
}

- (void)performSetterWithValue:(id)value
{
	id aTarget = target;
	if (!aTarget || !setter || ![aTarget respondsToSelector:setter])
		return;
	((void (*)(id, SEL, id, id)) objc_msgSend)(aTarget, setter, value, self);
}

- (void)performButtonAction
{
	id aTarget = target;
	if (!aTarget || !action || ![aTarget respondsToSelector:action])
		return;
	if ([[aTarget methodSignatureForSelector:action] numberOfArguments] > 2)
		((void (*)(id, SEL, id)) objc_msgSend)(aTarget, action, self);
	else
		((void (*)(id, SEL)) objc_msgSend)(aTarget, action);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p: ID %@, Name '%@' target %@>", [self class], self, self.identifier, _name, target];
}

@end

@implementation PSTextFieldSpecifier

+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)aTarget set:(SEL)set get:(SEL)get detail:(Class)detail cell:(PSCellType)cell edit:(Class)edit
{
	return [super preferenceSpecifierNamed:name target:aTarget set:set get:get detail:detail cell:cell edit:edit];
}

- (NSString *)placeholder
{
	return [self propertyForKey:PSPlaceholderKey];
}

- (void)setPlaceholder:(NSString *)placeholder
{
	[self setProperty:[placeholder copy] forKey:PSPlaceholderKey];
}

@end
