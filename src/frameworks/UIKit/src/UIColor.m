/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIColor.h>
#import <AppKit/NSColor.h>

#import "UIKitPrivate.h"
#import <objc/message.h>

@implementation UIColor

+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
	UIColor *color = [[UIColor alloc] init];
	color->_red = red;
	color->_green = green;
	color->_blue = blue;
	color->_alpha = alpha;
	return color;
}

+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha
{
	return [self colorWithRed:white green:white blue:white alpha:alpha];
}

+ (UIColor *)blackColor { return [self colorWithWhite:0 alpha:1]; }
+ (UIColor *)whiteColor { return [self colorWithWhite:1 alpha:1]; }
+ (UIColor *)clearColor { return [self colorWithWhite:0 alpha:0]; }
+ (UIColor *)redColor { return [self colorWithRed:1 green:0 blue:0 alpha:1]; }
+ (UIColor *)greenColor { return [self colorWithRed:0 green:1 blue:0 alpha:1]; }
+ (UIColor *)blueColor { return [self colorWithRed:0 green:0 blue:1 alpha:1]; }

- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha
{
	return [UIColor colorWithRed:_red green:_green blue:_blue alpha:alpha];
}

- (CGFloat)redComponent { return _red; }
- (CGFloat)greenComponent { return _green; }
- (CGFloat)blueComponent { return _blue; }
- (CGFloat)alphaComponent { return _alpha; }

- (NSColor *)nsColor
{
	return [NSColor colorWithCalibratedRed:_red green:_green blue:_blue alpha:_alpha];
}

- (void)set
{
	UIKitSetDrawColor(_red, _green, _blue, _alpha);
	[[self nsColor] set];
}

- (void)setFill
{
	UIKitSetDrawColor(_red, _green, _blue, _alpha);
	[[self nsColor] setFill];
}

- (void)setStroke
{
	[[self nsColor] setStroke];
}

+ (UIColor *)colorWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha
{
	NSColor *color = [[NSColor colorWithCalibratedHue:hue saturation:saturation brightness:brightness alpha:alpha]
		colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	return [self colorWithRed:[color redComponent] green:[color greenComponent] blue:[color blueComponent] alpha:alpha];
}

+ (UIColor *)colorWithCGColor:(CGColorRef)cgColor
{
	const CGFloat *c = cgColor != NULL ? CGColorGetComponents(cgColor) : NULL;
	size_t count = cgColor != NULL ? CGColorGetNumberOfComponents(cgColor) : 0;
	if (count >= 4)
		return [self colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
	if (count == 2)
		return [self colorWithWhite:c[0] alpha:c[1]];
	return [self blackColor];
}

/* Patterns are not drawn; the color is the image's rough average gray. */
+ (UIColor *)colorWithPatternImage:(id)image
{
	return [self colorWithWhite:0.9 alpha:1];
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
	if ((self = [super init])) {
		_red = red;
		_green = green;
		_blue = blue;
		_alpha = alpha;
	}
	return self;
}

- (instancetype)initWithWhite:(CGFloat)white alpha:(CGFloat)alpha
{
	return [self initWithRed:white green:white blue:white alpha:alpha];
}

/* A nib's color: a named system color or pattern, else its components. */
- (instancetype)initWithCoder:(NSCoder *)coder
{
	NSString *name = [coder decodeObjectForKey:@"UISystemColorName"] ?: [coder decodeObjectForKey:@"UIPatternSelector"];
	SEL selector = [name isKindOfClass:[NSString class]] ? NSSelectorFromString(name) : NULL;
	if (selector != NULL && [UIColor respondsToSelector:selector]) {
		UIColor *system = ((id (*)(id, SEL))objc_msgSend)([UIColor class], selector);
		if ([system isKindOfClass:[UIColor class]])
			return system;
	}
	CGFloat alpha = [coder containsValueForKey:@"UIAlpha"] ? [coder decodeDoubleForKey:@"UIAlpha"] : 1;
	if ([coder decodeIntegerForKey:@"UIColorComponentCount"] == 2 || ([coder containsValueForKey:@"UIWhite"] && ![coder containsValueForKey:@"UIRed"]))
		return [self initWithWhite:[coder decodeDoubleForKey:@"UIWhite"] alpha:alpha];
	CGFloat red = [coder containsValueForKey:@"UIRed-Double"] ? [coder decodeDoubleForKey:@"UIRed-Double"] : [coder decodeDoubleForKey:@"UIRed"];
	CGFloat green = [coder containsValueForKey:@"UIGreen-Double"] ? [coder decodeDoubleForKey:@"UIGreen-Double"] : [coder decodeDoubleForKey:@"UIGreen"];
	CGFloat blue = [coder containsValueForKey:@"UIBlue-Double"] ? [coder decodeDoubleForKey:@"UIBlue-Double"] : [coder decodeDoubleForKey:@"UIBlue"];
	return [self initWithRed:red green:green blue:blue alpha:alpha];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:4 forKey:@"UIColorComponentCount"];
	[coder encodeDouble:_red forKey:@"UIRed"];
	[coder encodeDouble:_green forKey:@"UIGreen"];
	[coder encodeDouble:_blue forKey:@"UIBlue"];
	[coder encodeDouble:_alpha forKey:@"UIAlpha"];
}

+ (UIColor *)darkGrayColor { return [self colorWithWhite:1.0 / 3 alpha:1]; }
+ (UIColor *)lightGrayColor { return [self colorWithWhite:2.0 / 3 alpha:1]; }
+ (UIColor *)grayColor { return [self colorWithWhite:0.5 alpha:1]; }
+ (UIColor *)cyanColor { return [self colorWithRed:0 green:1 blue:1 alpha:1]; }
+ (UIColor *)yellowColor { return [self colorWithRed:1 green:1 blue:0 alpha:1]; }
+ (UIColor *)magentaColor { return [self colorWithRed:1 green:0 blue:1 alpha:1]; }
+ (UIColor *)orangeColor { return [self colorWithRed:1 green:0.5 blue:0 alpha:1]; }
+ (UIColor *)purpleColor { return [self colorWithRed:0.5 green:0 blue:0.5 alpha:1]; }
+ (UIColor *)brownColor { return [self colorWithRed:0.6 green:0.4 blue:0.2 alpha:1]; }
/* iOS 7's grouped table background and system tint. */
+ (UIColor *)groupTableViewBackgroundColor { return [self colorWithRed:0.937 green:0.937 blue:0.957 alpha:1]; }
+ (UIColor *)systemBlueColor { return [self colorWithRed:0 green:0.478 blue:1 alpha:1]; }

/* iOS 13's semantic and system colors, in their light appearance. */
+ (UIColor *)labelColor { return [self blackColor]; }
+ (UIColor *)secondaryLabelColor { return [self colorWithRed:0.235 green:0.235 blue:0.263 alpha:0.6]; }
+ (UIColor *)tertiaryLabelColor { return [self colorWithRed:0.235 green:0.235 blue:0.263 alpha:0.3]; }
+ (UIColor *)quaternaryLabelColor { return [self colorWithRed:0.235 green:0.235 blue:0.263 alpha:0.18]; }
+ (UIColor *)placeholderTextColor { return [self tertiaryLabelColor]; }
+ (UIColor *)linkColor { return [self systemBlueColor]; }
+ (UIColor *)separatorColor { return [self colorWithRed:0.235 green:0.235 blue:0.263 alpha:0.29]; }
+ (UIColor *)opaqueSeparatorColor { return [self colorWithRed:0.776 green:0.776 blue:0.784 alpha:1]; }
+ (UIColor *)systemBackgroundColor { return [self whiteColor]; }
+ (UIColor *)secondarySystemBackgroundColor { return [self colorWithRed:0.949 green:0.949 blue:0.969 alpha:1]; }
+ (UIColor *)tertiarySystemBackgroundColor { return [self whiteColor]; }
+ (UIColor *)systemGroupedBackgroundColor { return [self colorWithRed:0.949 green:0.949 blue:0.969 alpha:1]; }
+ (UIColor *)secondarySystemGroupedBackgroundColor { return [self whiteColor]; }
+ (UIColor *)tertiarySystemGroupedBackgroundColor { return [self colorWithRed:0.949 green:0.949 blue:0.969 alpha:1]; }
+ (UIColor *)systemFillColor { return [self colorWithRed:0.471 green:0.471 blue:0.502 alpha:0.2]; }
+ (UIColor *)secondarySystemFillColor { return [self colorWithRed:0.471 green:0.471 blue:0.502 alpha:0.16]; }
+ (UIColor *)tertiarySystemFillColor { return [self colorWithRed:0.463 green:0.463 blue:0.502 alpha:0.12]; }
+ (UIColor *)quaternarySystemFillColor { return [self colorWithRed:0.455 green:0.455 blue:0.502 alpha:0.08]; }
+ (UIColor *)systemRedColor { return [self colorWithRed:1 green:0.231 blue:0.188 alpha:1]; }
+ (UIColor *)systemGreenColor { return [self colorWithRed:0.204 green:0.78 blue:0.349 alpha:1]; }
+ (UIColor *)systemOrangeColor { return [self colorWithRed:1 green:0.584 blue:0 alpha:1]; }
+ (UIColor *)systemYellowColor { return [self colorWithRed:1 green:0.8 blue:0 alpha:1]; }
+ (UIColor *)systemPinkColor { return [self colorWithRed:1 green:0.176 blue:0.333 alpha:1]; }
+ (UIColor *)systemPurpleColor { return [self colorWithRed:0.686 green:0.322 blue:0.871 alpha:1]; }
+ (UIColor *)systemTealColor { return [self colorWithRed:0.353 green:0.784 blue:0.98 alpha:1]; }
+ (UIColor *)systemIndigoColor { return [self colorWithRed:0.345 green:0.337 blue:0.839 alpha:1]; }
+ (UIColor *)systemGrayColor { return [self colorWithRed:0.557 green:0.557 blue:0.576 alpha:1]; }
+ (UIColor *)systemGray2Color { return [self colorWithRed:0.682 green:0.682 blue:0.698 alpha:1]; }
+ (UIColor *)systemGray3Color { return [self colorWithRed:0.78 green:0.78 blue:0.8 alpha:1]; }
+ (UIColor *)systemGray4Color { return [self colorWithRed:0.82 green:0.82 blue:0.839 alpha:1]; }
+ (UIColor *)systemGray5Color { return [self colorWithRed:0.898 green:0.898 blue:0.918 alpha:1]; }
+ (UIColor *)systemGray6Color { return [self colorWithRed:0.949 green:0.949 blue:0.969 alpha:1]; }

/* A color of an asset catalog. */
+ (UIColor *)colorNamed:(NSString *)name
{
	return UIKitAssetColor(name, nil);
}

+ (UIColor *)colorNamed:(NSString *)name inBundle:(NSBundle *)bundle compatibleWithTraitCollection:(id)traitCollection
{
	return UIKitAssetColor(name, bundle);
}

/* A dynamic color is its light appearance: there is no dark mode here. */
+ (UIColor *)colorWithDynamicProvider:(UIColor *(^)(id traitCollection))provider
{
	/* Resolved now, for the current traits (light, see UITraitCollection.h). */
	return provider != nil ? provider([UITraitCollection currentTraitCollection]) ?: [self clearColor] : [self clearColor];
}

- (instancetype)initWithDynamicProvider:(UIColor *(^)(id traitCollection))provider
{
	return [[self class] colorWithDynamicProvider:provider];
}

- (UIColor *)resolvedColorWithTraitCollection:(id)traitCollection { return self; }
+ (UIColor *)pinStripeColor { return [self groupTableViewBackgroundColor]; }
+ (UIColor *)tableCellBlueTextColor { return [self colorWithRed:0.22 green:0.33 blue:0.53 alpha:1]; }
+ (UIColor *)viewFlipsideBackgroundColor { return [self colorWithWhite:0.12 alpha:1]; }
+ (UIColor *)scrollViewTexturedBackgroundColor { return [self colorWithWhite:0.44 alpha:1]; }

- (CGColorRef)CGColor
{
	CGColorRef color = CGColorCreateGenericRGB(_red, _green, _blue, _alpha);
	/* Lives as long as the autorelease pool, as a property result would. */
	CFAutorelease(color);
	return color;
}

- (BOOL)getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha
{
	if (red) *red = _red;
	if (green) *green = _green;
	if (blue) *blue = _blue;
	if (alpha) *alpha = _alpha;
	return YES;
}

- (BOOL)getWhite:(CGFloat *)white alpha:(CGFloat *)alpha
{
	if (white) *white = (_red + _green + _blue) / 3;
	if (alpha) *alpha = _alpha;
	return YES;
}

- (BOOL)isEqual:(id)other
{
	if (![other isKindOfClass:[UIColor class]])
		return NO;
	UIColor *color = other;
	return color->_red == _red && color->_green == _green && color->_blue == _blue && color->_alpha == _alpha;
}

- (NSUInteger)hash
{
	return (NSUInteger)(_red * 255) << 24 | (NSUInteger)(_green * 255) << 16 | (NSUInteger)(_blue * 255) << 8 | (NSUInteger)(_alpha * 255);
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

@end
