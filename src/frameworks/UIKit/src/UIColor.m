/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * Portions adapted from the Chameleon UIColor (BSD-licensed).
 *
 * Copyright (c) 2011, 2012, The Iconfactory. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of The Iconfactory nor the names of its contributors may
 *    be used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE ICONFACTORY BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIColor.h>
#import <Foundation/NSException.h>
#include <math.h>
#import <AppKit/NSColor.h>

#import "UIKitPrivate.h"

/* NaN and infinite components raise; finite values outside 0...1 are stored unclamped. */
static void UIColorRequireFinite(CGFloat value)
{
	if (!isfinite(value))
		[NSException raise:NSInvalidArgumentException format:@"UIColor components must be finite"];
}

@implementation UIColor

+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
	UIColorRequireFinite(red);
	UIColorRequireFinite(green);
	UIColorRequireFinite(blue);
	UIColorRequireFinite(alpha);
	UIColor *color = [[UIColor alloc] init];
	color->_red = red;
	color->_green = green;
	color->_blue = blue;
	color->_alpha = alpha;
	return color;
}

+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha
{
	UIColor *color = [self colorWithRed:white green:white blue:white alpha:alpha];
	color->_isGray = YES;
	return color;
}

+ (UIColor *)colorWithCGColor:(CGColorRef)color
{
	return [[self alloc] initWithCGColor:color];
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
	if (!isfinite(red) || !isfinite(green) || !isfinite(blue) || !isfinite(alpha)) {
		self = nil;
		[NSException raise:NSInvalidArgumentException format:@"UIColor components must be finite"];
	}
	if ((self = [self init])) {
		_red = red;
		_green = green;
		_blue = blue;
		_alpha = alpha;
	}
	return self;
}

- (instancetype)initWithWhite:(CGFloat)white alpha:(CGFloat)alpha
{
	if (!isfinite(white) || !isfinite(alpha)) {
		self = nil;
		[NSException raise:NSInvalidArgumentException format:@"UIColor components must be finite"];
	}
	if ((self = [self initWithRed:white green:white blue:white alpha:alpha]))
		_isGray = YES;
	return self;
}

/* Only RGB and monochrome colors are representable; other models raise rather than convert silently. */
- (instancetype)initWithCGColor:(CGColorRef)color
{
	if (color == NULL) {
		self = nil;
		[NSException raise:NSInvalidArgumentException format:@"UIColor requires a CGColor"];
	}
	CGColorSpaceModel model = CGColorSpaceGetModel(CGColorGetColorSpace(color));
	size_t count = CGColorGetNumberOfComponents(color);
	const CGFloat *c = CGColorGetComponents(color);
	if (model == kCGColorSpaceModelRGB && count == 4)
		return [self initWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
	if (model == kCGColorSpaceModelMonochrome && count == 2)
		return [self initWithWhite:c[0] alpha:c[1]];
	self = nil;
	[NSException raise:NSInvalidArgumentException format:@"UIColor supports only RGB and gray CGColors"];
	return nil;
}

- (void)dealloc
{
	CGColorRelease(_cgColor);
}

/* Created on first use and owned by the receiver; callers must retain it to outlive the UIColor. */
- (CGColorRef)CGColor
{
	@synchronized (self) {
		if (_cgColor == NULL)
			_cgColor = _isGray ? CGColorCreateGenericGray(_red, _alpha)
					   : CGColorCreateGenericRGB(_red, _green, _blue, _alpha);
	}
	return _cgColor;
}

- (BOOL)getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha
{
	if (red != NULL) *red = _red;
	if (green != NULL) *green = _green;
	if (blue != NULL) *blue = _blue;
	if (alpha != NULL) *alpha = _alpha;
	return YES;
}

- (BOOL)getWhite:(CGFloat *)white alpha:(CGFloat *)alpha
{
	if (!_isGray)
		return NO;
	if (white != NULL) *white = _red;
	if (alpha != NULL) *alpha = _alpha;
	return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

+ (UIColor *)blackColor { return [self colorWithWhite:0 alpha:1]; }
+ (UIColor *)whiteColor { return [self colorWithWhite:1 alpha:1]; }
+ (UIColor *)clearColor { return [self colorWithWhite:0 alpha:0]; }
+ (UIColor *)redColor { return [self colorWithRed:1 green:0 blue:0 alpha:1]; }
+ (UIColor *)greenColor { return [self colorWithRed:0 green:1 blue:0 alpha:1]; }
+ (UIColor *)blueColor { return [self colorWithRed:0 green:0 blue:1 alpha:1]; }

- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha
{
	UIColor *color = [UIColor colorWithRed:_red green:_green blue:_blue alpha:alpha];
	color->_isGray = _isGray;
	return color;
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
	[[self nsColor] set];
}

- (void)setFill
{
	[[self nsColor] setFill];
}

@end
