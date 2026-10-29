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

@interface UIColor : NSObject {
@private
	CGFloat _red, _green, _blue, _alpha;
}

+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha;

+ (UIColor *)blackColor;
+ (UIColor *)whiteColor;
+ (UIColor *)clearColor;
+ (UIColor *)redColor;
+ (UIColor *)greenColor;
+ (UIColor *)blueColor;

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
+ (UIColor *)darkGrayColor;
+ (UIColor *)lightGrayColor;
+ (UIColor *)grayColor;
+ (UIColor *)cyanColor;
+ (UIColor *)yellowColor;
+ (UIColor *)magentaColor;
+ (UIColor *)orangeColor;
+ (UIColor *)purpleColor;
+ (UIColor *)brownColor;
+ (UIColor *)groupTableViewBackgroundColor;
+ (UIColor *)systemBlueColor;
+ (UIColor *)labelColor;
+ (UIColor *)secondaryLabelColor;
+ (UIColor *)tertiaryLabelColor;
+ (UIColor *)quaternaryLabelColor;
+ (UIColor *)placeholderTextColor;
+ (UIColor *)linkColor;
+ (UIColor *)separatorColor;
+ (UIColor *)opaqueSeparatorColor;
+ (UIColor *)systemBackgroundColor;
+ (UIColor *)secondarySystemBackgroundColor;
+ (UIColor *)tertiarySystemBackgroundColor;
+ (UIColor *)systemGroupedBackgroundColor;
+ (UIColor *)secondarySystemGroupedBackgroundColor;
+ (UIColor *)tertiarySystemGroupedBackgroundColor;
+ (UIColor *)systemFillColor;
+ (UIColor *)secondarySystemFillColor;
+ (UIColor *)tertiarySystemFillColor;
+ (UIColor *)quaternarySystemFillColor;
+ (UIColor *)systemRedColor;
+ (UIColor *)systemGreenColor;
+ (UIColor *)systemOrangeColor;
+ (UIColor *)systemYellowColor;
+ (UIColor *)systemPinkColor;
+ (UIColor *)systemPurpleColor;
+ (UIColor *)systemTealColor;
+ (UIColor *)systemIndigoColor;
+ (UIColor *)systemGrayColor;
+ (UIColor *)systemGray2Color;
+ (UIColor *)systemGray3Color;
+ (UIColor *)systemGray4Color;
+ (UIColor *)systemGray5Color;
+ (UIColor *)systemGray6Color;
+ (UIColor *)colorWithDynamicProvider:(UIColor *(^)(id traitCollection))provider;
- (instancetype)initWithDynamicProvider:(UIColor *(^)(id traitCollection))provider;
- (UIColor *)resolvedColorWithTraitCollection:(id)traitCollection;
@property (nonatomic, readonly) CGColorRef CGColor;
- (BOOL)getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha;
- (BOOL)getWhite:(CGFloat *)white alpha:(CGFloat *)alpha;
- (void)set;
- (void)setFill;
- (void)setStroke;

@end

#endif /* UIKIT_UIColor_H */
