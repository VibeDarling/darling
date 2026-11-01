/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIFONT_H
#define UIKIT_UIFONT_H

#import <Foundation/NSObject.h>
#import <CoreGraphics/CGGeometry.h>

@class NSString;

typedef CGFloat UIFontWeight;
extern const UIFontWeight UIFontWeightUltraLight;
extern const UIFontWeight UIFontWeightThin;
extern const UIFontWeight UIFontWeightLight;
extern const UIFontWeight UIFontWeightRegular;
extern const UIFontWeight UIFontWeightMedium;
extern const UIFontWeight UIFontWeightSemibold;
extern const UIFontWeight UIFontWeightBold;
extern const UIFontWeight UIFontWeightHeavy;
extern const UIFontWeight UIFontWeightBlack;

typedef CGFloat UIFontWidth;
extern const UIFontWidth UIFontWidthCompressed;
extern const UIFontWidth UIFontWidthCondensed;
extern const UIFontWidth UIFontWidthStandard;
extern const UIFontWidth UIFontWidthExpanded;

@interface UIFont : NSObject {
@private
	CGFloat _pointSize;
	NSString *_fontName;
	BOOL _bold;
}

+ (UIFont *)systemFontOfSize:(CGFloat)size;
+ (UIFont *)boldSystemFontOfSize:(CGFloat)size;
+ (UIFont *)fontWithName:(NSString *)name size:(CGFloat)size;

+ (UIFont *)italicSystemFontOfSize:(CGFloat)size;
/* The system font has a regular and a bold face: weights from semibold up
   are bold. Its digits are all one width already. */
+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight width:(UIFontWidth)width;
+ (UIFont *)monospacedDigitSystemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
+ (CGFloat)systemFontSize;
+ (CGFloat)smallSystemFontSize;
+ (CGFloat)labelFontSize;
+ (CGFloat)buttonFontSize;
- (UIFont *)fontWithSize:(CGFloat)size;
@property (nonatomic, readonly) CGFloat lineHeight;
@property (nonatomic, readonly) CGFloat leading;
@property (nonatomic, readonly) CGFloat capHeight;
@property (nonatomic, readonly) CGFloat xHeight;
@property (nonatomic, readonly) NSString *familyName;
@property (nonatomic, readonly) CGFloat pointSize;
@property (nonatomic, readonly) NSString *fontName;
@property (nonatomic, readonly) CGFloat ascender;
@property (nonatomic, readonly) CGFloat descender;

@end

#endif /* UIKIT_UIFONT_H */
