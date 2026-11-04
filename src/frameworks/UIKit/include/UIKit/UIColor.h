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

@interface UIColor : NSObject <NSCopying> {
@private
	CGFloat _red, _green, _blue, _alpha;
	BOOL _isGray;
	CGColorRef _cgColor;
}

+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
+ (UIColor *)colorWithCGColor:(CGColorRef)color;

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
- (instancetype)initWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
- (instancetype)initWithCGColor:(CGColorRef)color;

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

@property (nonatomic, readonly) CGColorRef CGColor;

- (BOOL)getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha;
- (BOOL)getWhite:(CGFloat *)white alpha:(CGFloat *)alpha;

- (void)set;
- (void)setFill;

@end

#endif /* UIKIT_UIColor_H */
