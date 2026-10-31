/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <Preferences/PSTableCell.h>
#import <Preferences/PSConstants.h>
#import <objc/message.h>

extern NSString *PSStringFromCellType(PSCellType type);

static BOOL isEnabled(PSSpecifier *specifier)
{
	id enabled = [specifier propertyForKey:PSEnabledKey];
	return !enabled || [enabled boolValue];
}

/* The title of a value of a list of choices, short if it has one. */
static NSString *titleForValue(PSSpecifier *specifier, id value)
{
	if (!value)
		return nil;
	NSString *title = specifier.shortTitleDictionary[value] ?: specifier.titleDictionary[value];
	if (title)
		return title;
	return [value isKindOfClass:[NSString class]] ? value : [value description];
}

@implementation PSTableCell

@synthesize specifier = _specifier, type = _type, cellTarget = _cellTarget, cellAction = _cellAction;

+ (PSCellType)cellTypeFromString:(NSString *)string
{
	return [PSSpecifier cellTypeFromString:string];
}

+ (NSString *)stringFromCellType:(PSCellType)type
{
	return PSStringFromCellType(type);
}

+ (UITableViewCellStyle)cellStyle
{
	return UITableViewCellStyleValue1;
}

+ (NSString *)reuseIdentifierForSpecifier:(PSSpecifier *)specifier
{
	return [NSString stringWithFormat:@"%@-%@", NSStringFromClass(self), PSStringFromCellType(specifier.cellType)];
}

+ (NSString *)reuseIdentifierForClassAndType:(PSCellType)type
{
	return [NSString stringWithFormat:@"%@-%@", NSStringFromClass(self), PSStringFromCellType(type)];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier
{
	if ((self = [super initWithStyle:style reuseIdentifier:identifier])) {
		_cellEnabled = YES;
		_specifier = specifier;
		_type = specifier.cellType;
		[self refreshCellContentsWithSpecifier:specifier];
	}
	return self;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier
{
	return [self initWithStyle:style reuseIdentifier:identifier specifier:nil];
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier
{
	_specifier = specifier;
	if (!specifier)
		return;
	_type = specifier.cellType;
	self.textLabel.text = specifier.name;
	self.imageView.image = [specifier propertyForKey:PSIconImageKey];

	switch (_type) {
	case PSLinkCell:
	case PSLinkListCell:
		self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		self.selectionStyle = UITableViewCellSelectionStyleDefault;
		break;
	case PSButtonCell:
		self.accessoryType = UITableViewCellAccessoryNone;
		self.selectionStyle = UITableViewCellSelectionStyleDefault;
		self.textLabel.textColor = [[specifier propertyForKey:@"isDestructive"] boolValue] ? [UIColor redColor]
			: [UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
		break;
	case PSListItemCell:
		self.selectionStyle = UITableViewCellSelectionStyleDefault;
		break;
	default:
		self.accessoryType = UITableViewCellAccessoryNone;
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		break;
	}
	if (_type == PSStaticTextCell || _type == PSTitleValueCell) {
		NSNumber *alignment = [specifier propertyForKey:PSAlignmentKey];
		if (alignment)
			self.textLabel.textAlignment = alignment.integerValue;
	}
	[self setCellEnabled:isEnabled(specifier)];
}

- (void)reloadWithSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated
{
	[self refreshCellContentsWithSpecifier:specifier];
}

- (BOOL)canReload
{
	return YES;
}

- (id)value
{
	return _value;
}

- (void)setValue:(id)value
{
	_value = value;
	if (_type == PSLinkListCell || _type == PSTitleValueCell)
		self.detailTextLabel.text = titleForValue(_specifier, value);
}

- (BOOL)isChecked
{
	return _checked;
}

- (void)setChecked:(BOOL)checked
{
	_checked = checked;
	self.accessoryType = checked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (BOOL)cellEnabled
{
	return _cellEnabled;
}

- (void)setCellEnabled:(BOOL)enabled
{
	_cellEnabled = enabled;
	self.userInteractionEnabled = enabled;
	self.textLabel.alpha = enabled ? 1 : 0.5;
	self.detailTextLabel.alpha = enabled ? 1 : 0.5;
}

- (UILabel *)titleLabel
{
	return self.textLabel;
}

- (UILabel *)valueLabel
{
	return self.detailTextLabel;
}

- (void)setTitle:(NSString *)title
{
	self.textLabel.text = title;
}

- (NSString *)title
{
	return self.textLabel.text;
}

- (void)setIcon:(UIImage *)icon
{
	self.imageView.image = icon;
	[self setNeedsLayout];
}

- (UIImage *)icon
{
	return self.imageView.image;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
	NSNumber *height = [_specifier propertyForKey:PSTableCellHeightKey];
	return height ? height.doubleValue : 44;
}

@end

@implementation PSControlTableCell

@synthesize control = _control;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier
{
	if ((self = [super initWithStyle:style reuseIdentifier:identifier specifier:specifier])) {
		self.control = [self newControl];
		[specifier setProperty:_control forKey:PSControlKey];
	}
	return self;
}

- (UIControl *)newControl
{
	return nil;
}

- (void)setControl:(UIControl *)control
{
	[_control removeTarget:self action:@selector(controlChanged:) forControlEvents:UIControlEventValueChanged];
	_control = control;
	[_control addTarget:self action:@selector(controlChanged:) forControlEvents:UIControlEventValueChanged];
	_control.enabled = _cellEnabled;
}

- (id)controlValue
{
	return nil;
}

- (void)controlChanged:(UIControl *)control
{
	_value = [self controlValue];
	id target = _cellTarget;
	if (target && _cellAction && [target respondsToSelector:_cellAction])
		((void (*)(id, SEL, id)) objc_msgSend)(target, _cellAction, self);
	else
		[_specifier performSetterWithValue:_value];
}

- (void)setCellEnabled:(BOOL)enabled
{
	[super setCellEnabled:enabled];
	_control.enabled = enabled;
}

@end

@implementation PSSwitchTableCell

- (UIControl *)newControl
{
	UISwitch *control = [[UISwitch alloc] initWithFrame:CGRectZero];
	[control sizeToFit];
	self.accessoryView = control;
	return control;
}

- (id)controlValue
{
	return @(((UISwitch *) _control).on);
}

- (void)setValue:(id)value
{
	[super setValue:value];
	((UISwitch *) _control).on = [value boolValue];
}

@end

@implementation PSSliderTableCell

- (UIControl *)newControl
{
	UISlider *slider = [[UISlider alloc] initWithFrame:CGRectZero];
	NSNumber *min = [_specifier propertyForKey:PSControlMinimumKey], *max = [_specifier propertyForKey:PSControlMaximumKey];
	slider.minimumValue = min ? min.floatValue : 0;
	slider.maximumValue = max ? max.floatValue : 1;
	slider.continuous = YES;
	[self.contentView addSubview:slider];
	return slider;
}

- (id)controlValue
{
	return @(((UISlider *) _control).value);
}

- (void)setValue:(id)value
{
	[super setValue:value];
	((UISlider *) _control).value = [value floatValue];
	if ([[_specifier propertyForKey:PSSliderShowValueKey] boolValue])
		self.detailTextLabel.text = [NSString stringWithFormat:@"%.2f", [value floatValue]];
}

- (void)controlChanged:(UIControl *)control
{
	[super controlChanged:control];
	if ([[_specifier propertyForKey:PSSliderShowValueKey] boolValue])
		self.detailTextLabel.text = [NSString stringWithFormat:@"%.2f", [_value floatValue]];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	CGFloat left = 15, right = 15;
	if (self.textLabel.text.length)
		left = CGRectGetMaxX(self.textLabel.frame) + 10;
	if (self.detailTextLabel.text.length)
		right = bounds.size.width - CGRectGetMinX(self.detailTextLabel.frame) + 10;
	_control.frame = CGRectMake(left, (bounds.size.height - 30) / 2, MAX(bounds.size.width - left - right, 40), 30);
}

@end

@implementation PSSegmentTableCell

- (UIControl *)newControl
{
	NSMutableArray *titles = [NSMutableArray array];
	for (id value in _specifier.values)
		[titles addObject:titleForValue(_specifier, value) ?: @""];
	UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:titles];
	[self.contentView addSubview:control];
	return control;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier
{
	[super refreshCellContentsWithSpecifier:specifier];
	// The segments are the row.
	self.textLabel.text = nil;
}

- (id)controlValue
{
	NSInteger index = ((UISegmentedControl *) _control).selectedSegmentIndex;
	NSArray *values = _specifier.values;
	return index >= 0 && (NSUInteger) index < values.count ? values[index] : nil;
}

- (void)setValue:(id)value
{
	[super setValue:value];
	NSUInteger index = value ? [_specifier.values indexOfObject:value] : NSNotFound;
	((UISegmentedControl *) _control).selectedSegmentIndex = index == NSNotFound ? UISegmentedControlNoSegment : (NSInteger) index;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	_control.frame = CGRectMake(15, (bounds.size.height - 30) / 2, bounds.size.width - 30, 30);
}

@end

@implementation PSEditableTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier
{
	if ((self = [super initWithStyle:style reuseIdentifier:identifier specifier:specifier])) {
		_textField = [[UITextField alloc] initWithFrame:CGRectZero];
		_textField.delegate = self;
		_textField.borderStyle = UITextBorderStyleNone;
		_textField.font = [UIFont systemFontOfSize:17];
		[self.contentView addSubview:_textField];
		[self refreshCellContentsWithSpecifier:specifier];
	}
	return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier
{
	[super refreshCellContentsWithSpecifier:specifier];
	if (!_textField || !specifier)
		return;
	_textField.placeholder = [specifier propertyForKey:PSPlaceholderKey];
	_textField.secureTextEntry = specifier.cellType == PSSecureEditTextCell
		|| [[specifier propertyForKey:PSIsSecureKey] boolValue];
	_textField.keyboardType = specifier->keyboardType;
	_textField.autocapitalizationType = specifier->autoCapsType;
	_textField.autocorrectionType = specifier->autoCorrectionType;
	_textField.enabled = _cellEnabled;
}

- (UITextField *)textField
{
	return _textField;
}

- (UITextField *)editableTextField
{
	return _textField;
}

- (void)setPlaceholderText:(NSString *)text
{
	_textField.placeholder = text;
}

- (void)setValue:(id)value
{
	[super setValue:value];
	_textField.text = value ? ([value isKindOfClass:[NSString class]] ? value : [value description]) : nil;
}

- (BOOL)isEditing
{
	return _textField.isEditing;
}

- (void)setCellEnabled:(BOOL)enabled
{
	[super setCellEnabled:enabled];
	_textField.enabled = enabled;
}

- (void)endEditingAndSave
{
	NSString *text = _textField.text ?: @"";
	if ([text isEqual:_value])
		return;
	_value = text;
	id target = _cellTarget;
	if (target && _cellAction && [target respondsToSelector:_cellAction])
		((void (*)(id, SEL, id)) objc_msgSend)(target, _cellAction, self);
	else
		[_specifier performSetterWithValue:text];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	[self endEditingAndSave];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self endEditingAndSave];
	[textField resignFirstResponder];
	return YES;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	CGFloat left = 15;
	if (self.textLabel.text.length) {
		CGSize size = [self.textLabel sizeThatFits:bounds.size];
		left = MAX(CGRectGetMinX(self.textLabel.frame), 15) + MAX(size.width, 90) + 10;
	}
	_textField.frame = CGRectMake(left, (bounds.size.height - 30) / 2, MAX(bounds.size.width - left - 15, 40), 30);
}

@end
