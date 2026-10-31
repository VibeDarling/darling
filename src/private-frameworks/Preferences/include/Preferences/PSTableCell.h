/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef PREFERENCES_PSTABLECELL_H
#define PREFERENCES_PSTABLECELL_H

#import <UIKit/UIKit.h>
#import <Preferences/PSSpecifier.h>

/* A settings row. Subclasses (a plist's cellClass) override -initWithStyle:reuseIdentifier:specifier: and -refreshCellContentsWithSpecifier:. */
@interface PSTableCell : UITableViewCell {
@protected
	id _value;
	PSSpecifier *_specifier;
	PSCellType _type;
	BOOL _checked;
	BOOL _cellEnabled;
	__weak id _cellTarget;
	SEL _cellAction;
}
+ (PSCellType)cellTypeFromString:(NSString *)string;
+ (NSString *)stringFromCellType:(PSCellType)type;
+ (UITableViewCellStyle)cellStyle;
+ (NSString *)reuseIdentifierForSpecifier:(PSSpecifier *)specifier;
+ (NSString *)reuseIdentifierForClassAndType:(PSCellType)type;
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier;
- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier;
- (void)reloadWithSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
@property (nonatomic, strong) PSSpecifier *specifier;
@property (nonatomic) PSCellType type;
@property (nonatomic, strong) id value;
@property (nonatomic, weak) id cellTarget;
@property (nonatomic) SEL cellAction;
@property (nonatomic, getter=isChecked) BOOL checked;
@property (nonatomic) BOOL cellEnabled;
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UILabel *valueLabel;
- (void)setTitle:(NSString *)title;
- (NSString *)title;
- (void)setIcon:(UIImage *)icon;
- (UIImage *)icon;
- (BOOL)canReload;
- (CGFloat)preferredHeightForWidth:(CGFloat)width;
@end

/* A row with a control (switch, slider, segments) whose changes are the setting. */
@interface PSControlTableCell : PSTableCell {
@protected
	UIControl *_control;
}
@property (nonatomic, strong) UIControl *control;
- (UIControl *)newControl;
- (void)controlChanged:(UIControl *)control;
- (id)controlValue;
@end

@interface PSSwitchTableCell : PSControlTableCell
@end

@interface PSSliderTableCell : PSControlTableCell
@end

@interface PSSegmentTableCell : PSControlTableCell
@end

@interface PSEditableTableCell : PSTableCell <UITextFieldDelegate> {
@protected
	UITextField *_textField;
}
@property (nonatomic, readonly) UITextField *textField;
- (UITextField *)editableTextField;
- (void)setPlaceholderText:(NSString *)text;
- (BOOL)isEditing;
- (void)endEditingAndSave;
@end

#endif /* PREFERENCES_PSTABLECELL_H */
