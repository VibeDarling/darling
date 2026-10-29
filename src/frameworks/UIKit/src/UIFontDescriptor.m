/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIFontDescriptor.h>
#import <UIKit/UIMotionEffect.h>
#import <UIKit/UIKit.h>
#import "UIKitPrivate.h"
#import <objc/runtime.h>

#pragma mark - UIFontDescriptor

UIFontDescriptorAttributeName const UIFontDescriptorTraitsAttribute = @"NSCTFontTraitsAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorTextStyleAttribute = @"NSCTFontUIUsageAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorFixedAdvanceAttribute = @"NSCTFontFixedAdvanceAttribute";
UIFontDescriptorTraitKey const UIFontSymbolicTrait = @"NSCTFontSymbolicTrait";
UIFontDescriptorTraitKey const UIFontWeightTrait = @"NSCTFontWeightTrait";

/* The point sizes iOS gives text styles at the default text size. */
static CGFloat UIKitTextStyleSize(NSString *style, BOOL *bold)
{
	static NSDictionary *sizes;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		sizes = @{
			UIFontTextStyleTitle1: @28, UIFontTextStyleTitle2: @22, UIFontTextStyleTitle3: @20,
			UIFontTextStyleHeadline: @17, UIFontTextStyleSubheadline: @15, UIFontTextStyleBody: @17,
			UIFontTextStyleCallout: @16, UIFontTextStyleFootnote: @13,
			UIFontTextStyleCaption1: @12, UIFontTextStyleCaption2: @11,
		};
	});
	if (bold != NULL)
		*bold = [style isEqualToString:UIFontTextStyleHeadline];
	NSNumber *size = style != nil ? [sizes objectForKey:style] : nil;
	return size != nil ? [size doubleValue] : 17;
}

@implementation UIFontDescriptor {
	NSDictionary *_attributes;
}

+ (BOOL)supportsSecureCoding { return YES; }

+ (UIFontDescriptor *)fontDescriptorWithFontAttributes:(NSDictionary *)attributes
{
	return [[self alloc] initWithFontAttributes:attributes];
}

+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)fontName size:(CGFloat)size
{
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	if (fontName != nil)
		[attributes setObject:fontName forKey:UIFontDescriptorNameAttribute];
	if (size > 0)
		[attributes setObject:@(size) forKey:UIFontDescriptorSizeAttribute];
	return [self fontDescriptorWithFontAttributes:attributes];
}

+ (UIFontDescriptor *)preferredFontDescriptorWithTextStyle:(UIFontTextStyle)style
{
	BOOL bold;
	CGFloat size = UIKitTextStyleSize(style, &bold);
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:@{
		UIFontDescriptorSizeAttribute: @(size),
		UIFontDescriptorTextStyleAttribute: style ?: UIFontTextStyleBody,
	}];
	if (bold)
		[attributes setObject:@{ UIFontSymbolicTrait: @(UIFontDescriptorTraitBold) } forKey:UIFontDescriptorTraitsAttribute];
	return [self fontDescriptorWithFontAttributes:attributes];
}

- (instancetype)initWithFontAttributes:(NSDictionary *)attributes
{
	if ((self = [super init]))
		_attributes = [attributes copy] ?: @{};
	return self;
}

- (instancetype)init
{
	return [self initWithFontAttributes:nil];
}

- (id)copyWithZone:(NSZone *)zone { return self; }

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_attributes forKey:@"UIFontDescriptorAttributes"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	return [self initWithFontAttributes:[coder decodeObjectForKey:@"UIFontDescriptorAttributes"]];
}

- (NSDictionary *)fontAttributes { return _attributes; }
- (id)objectForKey:(UIFontDescriptorAttributeName)attribute { return [_attributes objectForKey:attribute]; }
- (NSString *)postscriptName { return [_attributes objectForKey:UIFontDescriptorNameAttribute]; }
- (CGFloat)pointSize { return [[_attributes objectForKey:UIFontDescriptorSizeAttribute] doubleValue]; }
- (CGAffineTransform)matrix { return CGAffineTransformIdentity; }

- (UIFontDescriptorSymbolicTraits)symbolicTraits
{
	return (UIFontDescriptorSymbolicTraits)[[[_attributes objectForKey:UIFontDescriptorTraitsAttribute] objectForKey:UIFontSymbolicTrait] unsignedIntValue];
}

- (UIFontDescriptor *)fontDescriptorByAddingAttributes:(NSDictionary *)attributes
{
	NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:_attributes];
	[merged addEntriesFromDictionary:attributes];
	return [UIFontDescriptor fontDescriptorWithFontAttributes:merged];
}

- (UIFontDescriptor *)fontDescriptorWithSize:(CGFloat)size
{
	return [self fontDescriptorByAddingAttributes:@{ UIFontDescriptorSizeAttribute: @(size) }];
}

- (UIFontDescriptor *)fontDescriptorWithSymbolicTraits:(UIFontDescriptorSymbolicTraits)traits
{
	NSMutableDictionary *traitsDictionary = [NSMutableDictionary dictionaryWithDictionary:[_attributes objectForKey:UIFontDescriptorTraitsAttribute] ?: @{}];
	[traitsDictionary setObject:@(traits) forKey:UIFontSymbolicTrait];
	return [self fontDescriptorByAddingAttributes:@{ UIFontDescriptorTraitsAttribute: traitsDictionary }];
}

- (UIFontDescriptor *)fontDescriptorWithFamily:(NSString *)family
{
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:_attributes];
	[attributes removeObjectForKey:UIFontDescriptorNameAttribute];
	if (family != nil)
		[attributes setObject:family forKey:UIFontDescriptorFamilyAttribute];
	return [UIFontDescriptor fontDescriptorWithFontAttributes:attributes];
}

- (UIFontDescriptor *)fontDescriptorWithFace:(NSString *)face
{
	return face != nil ? [self fontDescriptorByAddingAttributes:@{ UIFontDescriptorFaceAttribute: face }] : self;
}

- (NSArray *)matchingFontDescriptorsWithMandatoryKeys:(NSSet *)keys
{
	return @[ self ];
}

- (BOOL)isEqual:(id)other
{
	return [other isKindOfClass:[UIFontDescriptor class]] && [_attributes isEqual:[other fontAttributes]];
}

- (NSUInteger)hash { return [_attributes hash]; }

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@", [super description], _attributes];
}

@end

@implementation UIFont (UIFontDescriptor)

+ (UIFont *)fontWithDescriptor:(UIFontDescriptor *)descriptor size:(CGFloat)size
{
	if (size <= 0)
		size = [descriptor pointSize] > 0 ? [descriptor pointSize] : [UIFont systemFontSize];
	UIFontDescriptorSymbolicTraits traits = [descriptor symbolicTraits];
	NSString *name = [descriptor postscriptName] ?: [descriptor objectForKey:UIFontDescriptorFamilyAttribute];
	if (name != nil) {
		UIFont *font = [UIFont fontWithName:name size:size];
		if (font != nil)
			return font;
	}
	if (traits & UIFontDescriptorTraitBold)
		return [UIFont boldSystemFontOfSize:size];
	if (traits & UIFontDescriptorTraitItalic)
		return [UIFont italicSystemFontOfSize:size];
	return [UIFont systemFontOfSize:size];
}

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style
{
	return [self fontWithDescriptor:[UIFontDescriptor preferredFontDescriptorWithTextStyle:style] size:0];
}

- (UIFontDescriptor *)fontDescriptor
{
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:@{ UIFontDescriptorSizeAttribute: @([self pointSize]) }];
	if ([self fontName] != nil)
		[attributes setObject:[self fontName] forKey:UIFontDescriptorNameAttribute];
	if ([self familyName] != nil)
		[attributes setObject:[self familyName] forKey:UIFontDescriptorFamilyAttribute];
	return [UIFontDescriptor fontDescriptorWithFontAttributes:attributes];
}

@end

#pragma mark - Motion effects

@implementation UIMotionEffect

- (id)copyWithZone:(NSZone *)zone { return self; }
- (void)encodeWithCoder:(NSCoder *)coder { }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (NSDictionary *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)viewerOffset { return nil; }

@end

@implementation UIInterpolatingMotionEffect {
	NSString *_keyPath;
	UIInterpolatingMotionEffectType _type;
}

@synthesize minimumRelativeValue = _minimumRelativeValue;
@synthesize maximumRelativeValue = _maximumRelativeValue;

- (instancetype)initWithKeyPath:(NSString *)keyPath type:(UIInterpolatingMotionEffectType)type
{
	if ((self = [super init])) {
		_keyPath = [keyPath copy];
		_type = type;
	}
	return self;
}

- (NSString *)keyPath { return _keyPath; }
- (UIInterpolatingMotionEffectType)type { return _type; }

@end

@implementation UIMotionEffectGroup

@synthesize motionEffects = _motionEffects;

@end

static char UIKitMotionEffectsKey;

@implementation UIView (UIMotionEffects)

- (NSArray *)motionEffects
{
	return [objc_getAssociatedObject(self, &UIKitMotionEffectsKey) copy] ?: @[];
}

- (void)setMotionEffects:(NSArray *)effects
{
	objc_setAssociatedObject(self, &UIKitMotionEffectsKey, [effects mutableCopy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)addMotionEffect:(UIMotionEffect *)effect
{
	if (effect == nil)
		return;
	NSMutableArray *effects = objc_getAssociatedObject(self, &UIKitMotionEffectsKey);
	if (effects == nil) {
		effects = [NSMutableArray array];
		objc_setAssociatedObject(self, &UIKitMotionEffectsKey, effects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	[effects addObject:effect];
}

- (void)removeMotionEffect:(UIMotionEffect *)effect
{
	[objc_getAssociatedObject(self, &UIKitMotionEffectsKey) removeObject:effect];
}

@end
