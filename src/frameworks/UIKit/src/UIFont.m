/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIFont.h>
#import <AppKit/NSFont.h>
#import <Foundation/NSString.h>

#import "UIKitPrivate.h"

@implementation UIFont

+ (UIFont *)systemFontOfSize:(CGFloat)size
{
	UIFont *font = [[UIFont alloc] init];
	font->_pointSize = size;
	font->_bold = NO;
	return font;
}

+ (UIFont *)boldSystemFontOfSize:(CGFloat)size
{
	UIFont *font = [self systemFontOfSize:size];
	font->_bold = YES;
	return font;
}

+ (UIFont *)fontWithName:(NSString *)name size:(CGFloat)size
{
	UIFont *font = [self systemFontOfSize:size];
	font->_fontName = [name copy];
	return font;
}

/* A nib's font: the system font (in its traits, 1 italic and 2 bold) or a named one. */
- (instancetype)initWithCoder:(NSCoder *)coder
{
	CGFloat size = [coder containsValueForKey:@"UIFontPointSize"] ? [coder decodeDoubleForKey:@"UIFontPointSize"] : [coder decodeDoubleForKey:@"NSSize"];
	NSString *name = [coder decodeObjectForKey:@"UIFontName"] ?: [coder decodeObjectForKey:@"NSName"];
	NSInteger traits = [coder decodeIntegerForKey:@"UIFontTraits"];
	if (size <= 0)
		size = 17;
	if ([coder decodeBoolForKey:@"UISystemFont"] || name == nil || [name hasPrefix:@"."]) {
		if (traits & 2)
			return [UIFont boldSystemFontOfSize:size];
		if (traits & 1)
			return [UIFont italicSystemFontOfSize:size];
		return [UIFont systemFontOfSize:size];
	}
	return [UIFont fontWithName:name size:size];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_fontName forKey:@"UIFontName"];
	[coder encodeDouble:_pointSize forKey:@"UIFontPointSize"];
	[coder encodeBool:_fontName == nil forKey:@"UISystemFont"];
	[coder encodeInteger:_bold ? 2 : 0 forKey:@"UIFontTraits"];
}

+ (CGFloat)systemFontSize { return 14; }
+ (CGFloat)smallSystemFontSize { return 12; }
+ (CGFloat)labelFontSize { return 17; }
+ (CGFloat)buttonFontSize { return 18; }

+ (UIFont *)italicSystemFontOfSize:(CGFloat)size
{
	return [self systemFontOfSize:size];
}

- (UIFont *)fontWithSize:(CGFloat)size
{
	UIFont *font = [UIFont systemFontOfSize:size];
	font->_bold = _bold;
	font->_fontName = _fontName;
	return font;
}

- (CGFloat)lineHeight
{
	NSFont *font = [self nsFont];
	return ceil([font ascender] - [font descender]);
}

- (CGFloat)leading
{
	return [self lineHeight];
}

- (CGFloat)capHeight
{
	return [[self nsFont] capHeight];
}

- (CGFloat)xHeight
{
	return [[self nsFont] xHeight];
}

- (NSString *)familyName
{
	return [[self nsFont] familyName];
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (CGFloat)pointSize { return _pointSize; }
- (NSString *)fontName { return _fontName; }

- (CGFloat)ascender
{
	return [[self nsFont] ascender];
}

- (CGFloat)descender
{
	return [[self nsFont] descender];
}

- (NSFont *)nsFont
{
	if (_fontName != nil) {
		NSFont *named = [NSFont fontWithName:_fontName size:_pointSize];
		if (named != nil)
			return named;
	}
	if (_bold)
		return [NSFont boldSystemFontOfSize:_pointSize];
	return [NSFont systemFontOfSize:_pointSize];
}

@end
