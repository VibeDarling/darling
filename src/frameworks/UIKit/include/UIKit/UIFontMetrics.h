/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIFONTMETRICS_H
#define UIKIT_UIFONTMETRICS_H

#import <UIKit/UIFont.h>
#import <UIKit/UIFontDescriptor.h>
#import <UIKit/UITraitCollection.h>

/*
 * Dynamic Type scaling. The text size is always the default (large) one,
 * where iOS scales nothing, so fonts and values come back as they are,
 * within any maximum given.
 */
@interface UIFontMetrics : NSObject
@property (class, nonatomic, readonly) UIFontMetrics *defaultMetrics;
+ (instancetype)metricsForTextStyle:(UIFontTextStyle)textStyle;
- (instancetype)initForTextStyle:(UIFontTextStyle)textStyle;
- (UIFont *)scaledFontForFont:(UIFont *)font;
- (UIFont *)scaledFontForFont:(UIFont *)font maximumPointSize:(CGFloat)maximumPointSize;
- (UIFont *)scaledFontForFont:(UIFont *)font compatibleWithTraitCollection:(UITraitCollection *)traitCollection;
- (UIFont *)scaledFontForFont:(UIFont *)font maximumPointSize:(CGFloat)maximumPointSize compatibleWithTraitCollection:(UITraitCollection *)traitCollection;
- (CGFloat)scaledValueForValue:(CGFloat)value;
- (CGFloat)scaledValueForValue:(CGFloat)value compatibleWithTraitCollection:(UITraitCollection *)traitCollection;
@end

#endif /* UIKIT_UIFONTMETRICS_H */
