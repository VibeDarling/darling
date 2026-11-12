/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIKit.h>

@implementation UIFontMetrics

+ (UIFontMetrics *)defaultMetrics
{
	return [[self alloc] initForTextStyle:UIFontTextStyleBody];
}

+ (instancetype)metricsForTextStyle:(UIFontTextStyle)textStyle
{
	return [[self alloc] initForTextStyle:textStyle];
}

- (instancetype)initForTextStyle:(UIFontTextStyle)textStyle
{
	return [super init];
}

- (UIFont *)scaledFontForFont:(UIFont *)font
{
	return font;
}

- (UIFont *)scaledFontForFont:(UIFont *)font maximumPointSize:(CGFloat)maximumPointSize
{
	if (maximumPointSize > 0 && [font pointSize] > maximumPointSize)
		return [font fontWithSize:maximumPointSize];
	return font;
}

- (UIFont *)scaledFontForFont:(UIFont *)font compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
	return [self scaledFontForFont:font];
}

- (UIFont *)scaledFontForFont:(UIFont *)font maximumPointSize:(CGFloat)maximumPointSize compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
	return [self scaledFontForFont:font maximumPointSize:maximumPointSize];
}

- (CGFloat)scaledValueForValue:(CGFloat)value
{
	return value;
}

- (CGFloat)scaledValueForValue:(CGFloat)value compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
	return value;
}

@end
