/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIColor_H
#define UIKIT_UIColor_H

#import <Foundation/NSObject.h>
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGColor.h>

@class NSBundle, NSString;

NS_ASSUME_NONNULL_BEGIN

@interface UIColor : NSObject {
@private
	CGFloat _red, _green, _blue, _alpha;
}

+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha;

@property (class, nonatomic, readonly) UIColor *blackColor;
@property (class, nonatomic, readonly) UIColor *whiteColor;
@property (class, nonatomic, readonly) UIColor *clearColor;
@property (class, nonatomic, readonly) UIColor *redColor;
@property (class, nonatomic, readonly) UIColor *greenColor;
@property (class, nonatomic, readonly) UIColor *blueColor;

- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha;

@property (nonatomic, readonly) CGFloat redComponent;
@property (nonatomic, readonly) CGFloat greenComponent;
@property (nonatomic, readonly) CGFloat blueComponent;
@property (nonatomic, readonly) CGFloat alphaComponent;

+ (UIColor *)colorWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha;
+ (UIColor *)colorWithCGColor:(CGColorRef)cgColor;
+ (UIColor *)colorWithPatternImage:(id)image;
- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
- (instancetype)initWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
@property (class, nonatomic, readonly) UIColor *darkGrayColor;
@property (class, nonatomic, readonly) UIColor *lightGrayColor;
@property (class, nonatomic, readonly) UIColor *grayColor;
@property (class, nonatomic, readonly) UIColor *cyanColor;
@property (class, nonatomic, readonly) UIColor *yellowColor;
@property (class, nonatomic, readonly) UIColor *magentaColor;
@property (class, nonatomic, readonly) UIColor *orangeColor;
@property (class, nonatomic, readonly) UIColor *purpleColor;
@property (class, nonatomic, readonly) UIColor *brownColor;
@property (class, nonatomic, readonly) UIColor *groupTableViewBackgroundColor;
@property (class, nonatomic, readonly) UIColor *systemBlueColor;
@property (class, nonatomic, readonly) UIColor *labelColor;
@property (class, nonatomic, readonly) UIColor *secondaryLabelColor;
@property (class, nonatomic, readonly) UIColor *tertiaryLabelColor;
@property (class, nonatomic, readonly) UIColor *quaternaryLabelColor;
@property (class, nonatomic, readonly) UIColor *placeholderTextColor;
@property (class, nonatomic, readonly) UIColor *linkColor;
@property (class, nonatomic, readonly) UIColor *separatorColor;
@property (class, nonatomic, readonly) UIColor *opaqueSeparatorColor;
@property (class, nonatomic, readonly) UIColor *systemBackgroundColor;
@property (class, nonatomic, readonly) UIColor *secondarySystemBackgroundColor;
@property (class, nonatomic, readonly) UIColor *tertiarySystemBackgroundColor;
@property (class, nonatomic, readonly) UIColor *systemGroupedBackgroundColor;
@property (class, nonatomic, readonly) UIColor *secondarySystemGroupedBackgroundColor;
@property (class, nonatomic, readonly) UIColor *tertiarySystemGroupedBackgroundColor;
@property (class, nonatomic, readonly) UIColor *systemFillColor;
@property (class, nonatomic, readonly) UIColor *secondarySystemFillColor;
@property (class, nonatomic, readonly) UIColor *tertiarySystemFillColor;
@property (class, nonatomic, readonly) UIColor *quaternarySystemFillColor;
@property (class, nonatomic, readonly) UIColor *systemRedColor;
@property (class, nonatomic, readonly) UIColor *systemGreenColor;
@property (class, nonatomic, readonly) UIColor *systemOrangeColor;
@property (class, nonatomic, readonly) UIColor *systemYellowColor;
@property (class, nonatomic, readonly) UIColor *systemPinkColor;
@property (class, nonatomic, readonly) UIColor *systemPurpleColor;
@property (class, nonatomic, readonly) UIColor *systemTealColor;
@property (class, nonatomic, readonly) UIColor *systemIndigoColor;
@property (class, nonatomic, readonly) UIColor *systemGrayColor;
@property (class, nonatomic, readonly) UIColor *systemGray2Color;
@property (class, nonatomic, readonly) UIColor *systemGray3Color;
@property (class, nonatomic, readonly) UIColor *systemGray4Color;
@property (class, nonatomic, readonly) UIColor *systemGray5Color;
@property (class, nonatomic, readonly) UIColor *systemGray6Color;
+ (nullable UIColor *)colorNamed:(NSString *)name;
+ (nullable UIColor *)colorNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle compatibleWithTraitCollection:(nullable id)traitCollection;
+ (UIColor *)colorWithDynamicProvider:(UIColor *(^)(id traitCollection))provider;
- (instancetype)initWithDynamicProvider:(UIColor *(^)(id traitCollection))provider;
- (UIColor *)resolvedColorWithTraitCollection:(id)traitCollection;
@property (nonatomic, readonly) CGColorRef CGColor;
- (BOOL)getRed:(nullable CGFloat *)red green:(nullable CGFloat *)green blue:(nullable CGFloat *)blue alpha:(nullable CGFloat *)alpha;
- (BOOL)getWhite:(nullable CGFloat *)white alpha:(nullable CGFloat *)alpha;
- (void)set;
- (void)setFill;
- (void)setStroke;

@end

NS_ASSUME_NONNULL_END

#endif /* UIKIT_UIColor_H */
