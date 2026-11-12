/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIVisualEffectView.h>
#import <AppKit/NSGraphics.h>
#import "UIKitPrivate.h"

@implementation UIVisualEffect
+ (BOOL)supportsSecureCoding { return YES; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (void)encodeWithCoder:(NSCoder *)coder { }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
@end

@implementation UIBlurEffect {
@public
	UIBlurEffectStyle _style;
}

+ (UIBlurEffect *)effectWithStyle:(UIBlurEffectStyle)style
{
	UIBlurEffect *effect = [[self alloc] init];
	effect->_style = style;
	return effect;
}

- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeInteger:_style forKey:@"UIBlurEffectStyle"]; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]))
		_style = [coder decodeIntegerForKey:@"UIBlurEffectStyle"];
	return self;
}

- (BOOL)isEqual:(id)object
{
	return [object isKindOfClass:[UIBlurEffect class]] && ((UIBlurEffect *)object)->_style == _style;
}

- (NSUInteger)hash { return (NSUInteger)_style; }

/* What the material looks like over white: its tint and how much shows. */
- (NSColor *)uikitTint
{
	CGFloat white, alpha;
	switch (_style) {
	case UIBlurEffectStyleExtraLight: white = 0.97; alpha = 0.9; break;
	case UIBlurEffectStyleDark: white = 0.11; alpha = 0.75; break;
	case UIBlurEffectStyleExtraDark: white = 0.07; alpha = 0.85; break;
	case UIBlurEffectStyleProminent: white = 0.92; alpha = 0.9; break;
	case UIBlurEffectStyleSystemUltraThinMaterial:
	case UIBlurEffectStyleSystemUltraThinMaterialLight: white = 0.96; alpha = 0.45; break;
	case UIBlurEffectStyleSystemThinMaterial:
	case UIBlurEffectStyleSystemThinMaterialLight: white = 0.96; alpha = 0.65; break;
	case UIBlurEffectStyleSystemThickMaterial:
	case UIBlurEffectStyleSystemThickMaterialLight: white = 0.96; alpha = 0.92; break;
	case UIBlurEffectStyleSystemChromeMaterial:
	case UIBlurEffectStyleSystemChromeMaterialLight: white = 0.97; alpha = 0.85; break;
	case UIBlurEffectStyleSystemUltraThinMaterialDark: white = 0.15; alpha = 0.45; break;
	case UIBlurEffectStyleSystemThinMaterialDark: white = 0.15; alpha = 0.65; break;
	case UIBlurEffectStyleSystemMaterialDark: white = 0.13; alpha = 0.8; break;
	case UIBlurEffectStyleSystemThickMaterialDark: white = 0.1; alpha = 0.92; break;
	case UIBlurEffectStyleSystemChromeMaterialDark: white = 0.12; alpha = 0.85; break;
	default: white = 0.97; alpha = 0.8; break;
	}
	return [NSColor colorWithCalibratedWhite:white alpha:alpha];
}

@end

@implementation UIVibrancyEffect {
	UIBlurEffect *_blur;
}

+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect
{
	UIVibrancyEffect *effect = [[self alloc] init];
	effect->_blur = blurEffect;
	return effect;
}

+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect style:(UIVibrancyEffectStyle)style
{
	return [self effectForBlurEffect:blurEffect];
}

@end

@implementation UIVisualEffectView {
	UIView *_contentView;
	UIVisualEffect *_effect;
}

- (instancetype)initWithEffect:(UIVisualEffect *)effect
{
	if ((self = [self initWithFrame:CGRectZero]))
		[self setEffect:effect];
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_contentView = [[UIView alloc] initWithFrame:[self bounds]];
		[_contentView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[super addSubview:_contentView];
	}
	return self;
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	UIView *content = [coder decodeObjectForKey:@"UIVisualEffectViewContentView"];
	if ([content isKindOfClass:[UIView class]] && content != _contentView) {
		[_contentView removeFromSuperview];
		_contentView = content;
		if ([content superview] != self)
			[super addSubview:content];
	}
	id effect = [coder decodeObjectForKey:@"UIVisualEffectViewEffect"];
	if ([effect isKindOfClass:[UIVisualEffect class]])
		[self setEffect:effect];
}

- (UIView *)contentView { return _contentView; }
- (UIVisualEffect *)effect { return _effect; }

- (void)setEffect:(UIVisualEffect *)effect
{
	_effect = [effect copy];
	[self setNeedsDisplay:YES];
}

/* Subviews belong in the content view; iOS raises, this puts them there. */
- (void)addSubview:(NSView *)view
{
	if (_contentView == nil || view == _contentView)
		[super addSubview:view];
	else
		[_contentView addSubview:view];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	if ([_effect isKindOfClass:[UIBlurEffect class]]) {
		[[(UIBlurEffect *)_effect uikitTint] setFill];
		NSRectFillUsingOperation(rect, NSCompositeSourceOver);
	}
}

@end
