/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIFONTDESCRIPTOR_H
#define UIKIT_UIFONTDESCRIPTOR_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIFont.h>
/* The feature type and selector numbers (kNumberSpacingType, ...) that feature settings take. */
#import <CoreText/SFNTLayoutTypes.h>

typedef NSString *UIFontDescriptorAttributeName NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *UIFontDescriptorTraitKey NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *UIFontDescriptorFeatureKey NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *UIFontTextStyle;

typedef NS_OPTIONS(uint32_t, UIFontDescriptorSymbolicTraits) {
	UIFontDescriptorTraitItalic = 1u << 0,
	UIFontDescriptorTraitBold = 1u << 1,
	UIFontDescriptorTraitExpanded = 1u << 5,
	UIFontDescriptorTraitCondensed = 1u << 6,
	UIFontDescriptorTraitMonoSpace = 1u << 10,
	UIFontDescriptorTraitVertical = 1u << 11,
	UIFontDescriptorTraitUIOptimized = 1u << 12,
	UIFontDescriptorTraitTightLeading = 1u << 15,
	UIFontDescriptorTraitLooseLeading = 1u << 16,
};

extern UIFontDescriptorAttributeName const UIFontDescriptorFamilyAttribute;
extern UIFontDescriptorAttributeName const UIFontDescriptorNameAttribute;
extern UIFontDescriptorAttributeName const UIFontDescriptorFaceAttribute;
extern UIFontDescriptorAttributeName const UIFontDescriptorSizeAttribute;
extern UIFontDescriptorAttributeName const UIFontDescriptorTraitsAttribute;
extern UIFontDescriptorAttributeName const UIFontDescriptorTextStyleAttribute;
extern UIFontDescriptorAttributeName const UIFontDescriptorFixedAdvanceAttribute;
/* An array of dictionaries, each a feature type and selector. Recorded, not yet applied to drawing. */
extern UIFontDescriptorAttributeName const UIFontDescriptorFeatureSettingsAttribute;
extern UIFontDescriptorFeatureKey const UIFontFeatureTypeIdentifierKey;
extern UIFontDescriptorFeatureKey const UIFontFeatureSelectorIdentifierKey;
extern UIFontDescriptorTraitKey const UIFontSymbolicTrait;
extern UIFontDescriptorTraitKey const UIFontWeightTrait;

@interface UIFontDescriptor : NSObject <NSCopying, NSSecureCoding>
+ (UIFontDescriptor *)fontDescriptorWithFontAttributes:(NSDictionary<UIFontDescriptorAttributeName, id> *)attributes;
+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)fontName size:(CGFloat)size;
+ (UIFontDescriptor *)preferredFontDescriptorWithTextStyle:(UIFontTextStyle)style;
- (instancetype)initWithFontAttributes:(NSDictionary<UIFontDescriptorAttributeName, id> *)attributes;
@property (nonatomic, readonly) NSString *postscriptName;
@property (nonatomic, readonly) CGFloat pointSize;
@property (nonatomic, readonly) CGAffineTransform matrix;
@property (nonatomic, readonly) UIFontDescriptorSymbolicTraits symbolicTraits;
@property (nonatomic, readonly) NSDictionary<UIFontDescriptorAttributeName, id> *fontAttributes;
- (id)objectForKey:(UIFontDescriptorAttributeName)attribute;
- (UIFontDescriptor *)fontDescriptorByAddingAttributes:(NSDictionary<UIFontDescriptorAttributeName, id> *)attributes;
- (UIFontDescriptor *)fontDescriptorWithSize:(CGFloat)size;
- (UIFontDescriptor *)fontDescriptorWithSymbolicTraits:(UIFontDescriptorSymbolicTraits)traits;
- (UIFontDescriptor *)fontDescriptorWithFamily:(NSString *)family;
- (UIFontDescriptor *)fontDescriptorWithFace:(NSString *)face;
- (NSArray<UIFontDescriptor *> *)matchingFontDescriptorsWithMandatoryKeys:(NSSet *)keys;
@end

@interface UIFont (UIFontDescriptor)
+ (UIFont *)fontWithDescriptor:(UIFontDescriptor *)descriptor size:(CGFloat)size;
+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style;
@property (nonatomic, readonly) UIFontDescriptor *fontDescriptor;
@end

#endif /* UIKIT_UIFONTDESCRIPTOR_H */
