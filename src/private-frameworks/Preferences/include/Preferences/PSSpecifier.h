/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef PREFERENCES_PSSPECIFIER_H
#define PREFERENCES_PSSPECIFIER_H

#import <UIKit/UIKit.h>

/*
 * One row (or group heading) of a settings list: what it shows, the cell
 * that shows it, and where its value is read and written. Tweaks reach into
 * the public ivars below directly, as they do on iOS.
 */

typedef NS_ENUM(NSInteger, PSCellType) {
	PSGroupCell,
	PSLinkCell,
	PSLinkListCell,
	PSListItemCell,
	PSTitleValueCell,
	PSSliderCell,
	PSSwitchCell,
	PSStaticTextCell,
	PSEditTextCell,
	PSSegmentCell,
	PSGiantIconCell,
	PSGiantCell,
	PSSecureEditTextCell,
	PSButtonCell,
	PSEditTextViewCell,
	PSSpinnerCell,
};

typedef NS_ENUM(NSInteger, PSTextFieldType) {
	PSTextFieldTypeDefault,
	PSTextFieldTypeSecure,
};

@interface PSSpecifier : NSObject {
@public
	__weak id target;
	SEL getter;
	SEL setter;
	SEL action;
	SEL cancel;
	Class detailControllerClass;
	PSCellType cellType;
	Class editPaneClass;
	UIKeyboardType keyboardType;
	UITextAutocapitalizationType autoCapsType;
	UITextAutocorrectionType autoCorrectionType;
	unsigned int textFieldType;
@protected
	NSString *_name;
	NSArray *_values;
	NSDictionary *_titleDict;
	NSDictionary *_shortTitleDict;
	id _userInfo;
	NSMutableDictionary *_properties;
}

+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(PSCellType)cell edit:(Class)edit;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
+ (instancetype)groupSpecifierWithHeader:(NSString *)header footer:(NSString *)footer;
+ (instancetype)emptyGroupSpecifier;
+ (instancetype)groupSpecifierWithID:(NSString *)identifier;
+ (instancetype)groupSpecifierWithID:(NSString *)identifier name:(NSString *)name;
+ (instancetype)deleteButtonSpecifierWithName:(NSString *)name target:(id)target action:(SEL)action;
+ (PSCellType)cellTypeFromString:(NSString *)string;

@property (nonatomic, weak) id target;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic) PSCellType cellType;
@property (nonatomic) Class detailControllerClass;
@property (nonatomic) Class editPaneClass;
@property (nonatomic, strong) NSMutableDictionary *properties;
@property (nonatomic, strong) NSDictionary *titleDictionary;
@property (nonatomic, strong) NSDictionary *shortTitleDictionary;
@property (nonatomic, strong) NSArray *values;
@property (nonatomic, strong) id userInfo;
@property (nonatomic) SEL buttonAction;
@property (nonatomic) SEL confirmationAction;
@property (nonatomic) SEL controllerLoadAction;

- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)property forKey:(NSString *)key;
- (void)removePropertyForKey:(NSString *)key;
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;
- (void)setValues:(NSArray *)values titles:(NSArray *)titles shortTitles:(NSArray *)shortTitles;
- (void)setValues:(NSArray *)values titles:(NSArray *)titles shortTitles:(NSArray *)shortTitles usingLocalizedTitleSorting:(BOOL)sort;
- (void)loadValuesAndTitlesFromDataSource;
- (void)setupIconImageWithBundle:(NSBundle *)bundle;
- (void)setupIconImageWithPath:(NSString *)path;
- (void)setKeyboardType:(UIKeyboardType)type autoCaps:(UITextAutocapitalizationType)autoCaps autoCorrection:(UITextAutocorrectionType)autoCorrection;
- (id)performGetter;
- (void)performSetterWithValue:(id)value;
- (void)performButtonAction;
@end

/* A text field's specifier, with its placeholder. */
@interface PSTextFieldSpecifier : PSSpecifier
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(PSCellType)cell edit:(Class)edit;
@property (nonatomic, copy) NSString *placeholder;
@end

#endif /* PREFERENCES_PSSPECIFIER_H */
