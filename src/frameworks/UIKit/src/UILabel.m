/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UILabel.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSMutableParagraphStyle.h>
#import <AppKit/NSStringDrawing.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import "UIKitPrivate.h"

@implementation UILabel {
	NSLineBreakMode _lineBreakMode;
	NSInteger _numberOfLines;
	UIColor *_highlightedTextColor;
	BOOL _highlighted;
	BOOL _disabled;
	NSAttributedString *_attributedText;
}

@synthesize adjustsFontSizeToFitWidth = _adjustsFontSizeToFitWidth;
@synthesize minimumFontSize = _minimumFontSize;
@synthesize minimumScaleFactor = _minimumScaleFactor;
@synthesize shadowColor = _shadowColor;
@synthesize preferredMaxLayoutWidth = _preferredMaxLayoutWidth;
@synthesize shadowOffset = _shadowOffset;

- (NSLineBreakMode)lineBreakMode { return _lineBreakMode; }
- (void)setLineBreakMode:(NSLineBreakMode)mode { _lineBreakMode = mode; [self setNeedsDisplay:YES]; }
- (NSInteger)numberOfLines { return _numberOfLines; }
- (void)setNumberOfLines:(NSInteger)lines { _numberOfLines = lines; [self setNeedsDisplay:YES]; }
- (UIColor *)highlightedTextColor { return _highlightedTextColor; }
- (void)setHighlightedTextColor:(UIColor *)color { _highlightedTextColor = color; [self setNeedsDisplay:YES]; }
- (BOOL)isHighlighted { return _highlighted; }
- (void)setHighlighted:(BOOL)highlighted { _highlighted = highlighted; [self setNeedsDisplay:YES]; }
- (BOOL)isEnabled { return !_disabled; }
- (void)setEnabled:(BOOL)enabled { _disabled = !enabled; [self setNeedsDisplay:YES]; }

/* Labels do not take touches, as on iOS. */
- (NSView *)hitTest:(NSPoint)point
{
	return nil;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil) {
		_textColor = [UIColor blackColor];
		_font = [UIFont systemFontOfSize:17];
		_textAlignment = NSTextAlignmentLeft;
		_lineBreakMode = NSLineBreakByTruncatingTail;
		_numberOfLines = 1;
		_shadowOffset = CGSizeMake(0, -1);
	}
	return self;
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	if ([coder containsValueForKey:@"UIAttributedText"])
		[self setAttributedText:[coder decodeObjectForKey:@"UIAttributedText"]];
	else if ([coder containsValueForKey:@"UIText"])
		[self setText:[coder decodeObjectForKey:@"UIText"]];
	if ([coder containsValueForKey:@"UIFont"])
		[self setFont:[coder decodeObjectForKey:@"UIFont"]];
	if ([coder containsValueForKey:@"UITextColor"])
		[self setTextColor:[coder decodeObjectForKey:@"UITextColor"]];
	if ([coder containsValueForKey:@"UIHighlightedColor"])
		[self setHighlightedTextColor:[coder decodeObjectForKey:@"UIHighlightedColor"]];
	if ([coder containsValueForKey:@"UIShadowColor"])
		[self setShadowColor:[coder decodeObjectForKey:@"UIShadowColor"]];
	if ([coder containsValueForKey:@"UIShadowOffset"])
		[self setShadowOffset:[coder decodeCGSizeForKey:@"UIShadowOffset"]];
	[self setTextAlignment:[coder decodeIntegerForKey:@"UITextAlignment"]];
	if ([coder containsValueForKey:@"UINumberOfLines"])
		[self setNumberOfLines:[coder decodeIntegerForKey:@"UINumberOfLines"]];
	if ([coder containsValueForKey:@"UILineBreakMode"])
		[self setLineBreakMode:[coder decodeIntegerForKey:@"UILineBreakMode"]];
	[self setAdjustsFontSizeToFitWidth:[coder decodeBoolForKey:@"UIAdjustsFontSizeToFit"]];
	if ([coder containsValueForKey:@"UIMinimumScaleFactor"])
		[self setMinimumScaleFactor:[coder decodeDoubleForKey:@"UIMinimumScaleFactor"]];
	if ([coder containsValueForKey:@"UIMinimumFontSize"])
		[self setMinimumFontSize:[coder decodeDoubleForKey:@"UIMinimumFontSize"]];
	if ([coder containsValueForKey:@"UIPreferredMaxLayoutWidth"])
		[self setPreferredMaxLayoutWidth:[coder decodeDoubleForKey:@"UIPreferredMaxLayoutWidth"]];
	[self setHighlighted:[coder decodeBoolForKey:@"UIHighlighted"]];
	[self setEnabled:![coder decodeBoolForKey:@"UIDisabled"]];
}

- (NSString *)text
{
	return _text;
}

- (void)setText:(NSString *)text
{
	_text = [text copy];
	_attributedText = nil;
	[self setNeedsDisplay:YES];
}

- (NSAttributedString *)attributedText
{
	if (_attributedText != nil)
		return _attributedText;
	return _text != nil ? [[NSAttributedString alloc] initWithString:_text attributes:[self textAttributes]] : nil;
}

- (void)setAttributedText:(NSAttributedString *)text
{
	_attributedText = [text copy];
	_text = [[text string] copy];
	[self setNeedsDisplay:YES];
}

/*
 * The attributed text as AppKit draws it: iOS apps put UIFonts and UIColors in
 * their attributes, and ranges without them use the label's own.
 */
- (NSAttributedString *)uikitDrawnText:(NSColor *)forcedColor
{
	if (_attributedText == nil)
		return nil;
	NSDictionary *defaults = [self textAttributes];
	NSMutableAttributedString *text = [_attributedText mutableCopy];
	NSRange all = NSMakeRange(0, [text length]);
	[text enumerateAttributesInRange:all options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
		NSMutableDictionary *converted = [NSMutableDictionary dictionaryWithCapacity:[attributes count] + 3];
		[attributes enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop2) {
			if ([value isKindOfClass:[UIFont class]])
				value = [(UIFont *)value nsFont];
			else if ([value isKindOfClass:[UIColor class]])
				value = [(UIColor *)value nsColor];
			[converted setObject:value forKey:key];
		}];
		for (NSString *key in @[ NSFontAttributeName, NSForegroundColorAttributeName, NSParagraphStyleAttributeName ])
			if ([converted objectForKey:key] == nil && [defaults objectForKey:key] != nil)
				[converted setObject:[defaults objectForKey:key] forKey:key];
		if (forcedColor != nil)
			[converted setObject:forcedColor forKey:NSForegroundColorAttributeName];
		[text setAttributes:converted range:range];
	}];
	return text;
}

- (UIColor *)textColor
{
	return _textColor;
}

- (void)setTextColor:(UIColor *)color
{
	_textColor = color;
	[self setNeedsDisplay:YES];
}

- (UIFont *)font
{
	return _font;
}

- (void)setFont:(UIFont *)font
{
	_font = font;
	[self setNeedsDisplay:YES];
}

- (NSTextAlignment)textAlignment
{
	return _textAlignment;
}

- (void)setTextAlignment:(NSTextAlignment)alignment
{
	_textAlignment = alignment;
	[self setNeedsDisplay:YES];
}

- (NSDictionary *)textAttributes
{
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	if (_font != nil)
		[attributes setObject:[_font nsFont] forKey:NSFontAttributeName];
	UIColor *color = _highlighted && _highlightedTextColor != nil ? _highlightedTextColor : _textColor;
	if (_disabled)
		color = [UIColor colorWithWhite:0.6 alpha:1];
	if (color != nil)
		[attributes setObject:[color nsColor] forKey:NSForegroundColorAttributeName];
	NSMutableParagraphStyle *paragraph = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paragraph setAlignment:_textAlignment];
	[paragraph setLineBreakMode:_numberOfLines == 1 ? NSLineBreakByClipping : NSLineBreakByWordWrapping];
	[attributes setObject:paragraph forKey:NSParagraphStyleAttributeName];
	return attributes;
}

/*
 * A line drawn at a point is placed by the label (-uikitLineOrigin:width:);
 * a centred or right-aligned paragraph would also be aligned by AppKit, in
 * its very wide container, and land far off to the right.
 */
static NSDictionary *UILabelLeftAlignedAttributes(NSDictionary *attributes)
{
	NSParagraphStyle *style = [attributes objectForKey:NSParagraphStyleAttributeName];
	if (style == nil || [style alignment] == NSTextAlignmentLeft)
		return attributes;
	NSMutableParagraphStyle *left = [style mutableCopy];
	[left setAlignment:NSTextAlignmentLeft];
	NSMutableDictionary *result = [attributes mutableCopy];
	[result setObject:left forKey:NSParagraphStyleAttributeName];
	return result;
}

static NSAttributedString *UILabelLeftAligned(NSAttributedString *text)
{
	NSMutableAttributedString *result = [text mutableCopy];
	[text enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(0, [text length]) options:0 usingBlock:^(id style, NSRange range, BOOL *stop) {
		if (style != nil && [(NSParagraphStyle *)style alignment] != NSTextAlignmentLeft) {
			NSMutableParagraphStyle *left = [style mutableCopy];
			[left setAlignment:NSTextAlignmentLeft];
			[result addAttribute:NSParagraphStyleAttributeName value:left range:range];
		}
	}];
	return result;
}

/* The rect the text takes, centred vertically in the bounds as UIKit does. */
static NSRect UILabelTextRect(NSRect bounds, CGFloat textHeight)
{
	if (textHeight < bounds.size.height) {
		bounds.origin.y += (bounds.size.height - textHeight) / 2;
		bounds.size.height = textHeight;
	}
	return bounds;
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	if ([_text length] == 0)
		return;

	NSColor *shadow = _shadowColor != nil ? [_shadowColor nsColor] : nil;
	if (_attributedText != nil) {
		NSAttributedString *text = [self uikitDrawnText:nil];
		NSSize size = [text size];
		NSRect bounds = UILabelTextRect([self bounds], size.height);
		if (_numberOfLines == 1) {
			NSPoint at = [self uikitLineOrigin:bounds width:size.width];
			if (shadow != nil)
				[UILabelLeftAligned([self uikitDrawnText:shadow]) drawAtPoint:NSMakePoint(at.x + _shadowOffset.width, at.y + _shadowOffset.height)];
			[UILabelLeftAligned(text) drawAtPoint:at];
			return;
		}
		if (shadow != nil)
			[[self uikitDrawnText:shadow] drawInRect:NSOffsetRect(bounds, _shadowOffset.width, _shadowOffset.height)];
		[text drawInRect:bounds];
		return;
	}

	NSDictionary *attributes = [self textAttributes];
	NSRect bounds = UILabelTextRect([self bounds], [_text sizeWithAttributes:attributes].height);
	NSString *text = _text;
	/* One line: cut it to the width with an ellipsis. */
	if (_numberOfLines == 1 && [text sizeWithAttributes:attributes].width > bounds.size.width && _lineBreakMode != NSLineBreakByClipping) {
		NSUInteger length = [text length];
		while (length > 0 && [[[text substringToIndex:length] stringByAppendingString:@"\u2026"] sizeWithAttributes:attributes].width > bounds.size.width)
			length--;
		text = [[text substringToIndex:length] stringByAppendingString:@"\u2026"];
	}
	NSMutableDictionary *shadowed = nil;
	if (shadow != nil) {
		shadowed = [attributes mutableCopy];
		[shadowed setObject:shadow forKey:NSForegroundColorAttributeName];
	}
	if (_numberOfLines == 1) {
		NSPoint at = [self uikitLineOrigin:bounds width:[text sizeWithAttributes:attributes].width];
		if (shadowed != nil)
			[text drawAtPoint:NSMakePoint(at.x + _shadowOffset.width, at.y + _shadowOffset.height) withAttributes:UILabelLeftAlignedAttributes(shadowed)];
		[text drawAtPoint:at withAttributes:UILabelLeftAlignedAttributes(attributes)];
		return;
	}
	if (shadowed != nil)
		[text drawInRect:NSOffsetRect(bounds, _shadowOffset.width, _shadowOffset.height) withAttributes:shadowed];
	[text drawInRect:bounds withAttributes:attributes];
}

/*
 * Where one line of text starts.  One line is drawn at a point, not into the
 * rect: AppKit pads a text container, so a line exactly as wide as the label
 * (as a button sizes its title) would wrap out of sight.
 */
- (NSPoint)uikitLineOrigin:(NSRect)bounds width:(CGFloat)width
{
	CGFloat x = bounds.origin.x;
	if (width < bounds.size.width) {
		if (_textAlignment == NSTextAlignmentCenter)
			x += (bounds.size.width - width) / 2;
		else if (_textAlignment == NSTextAlignmentRight)
			x += bounds.size.width - width;
	}
	return NSMakePoint(x, bounds.origin.y);
}

- (CGSize)sizeThatFits:(CGSize)size
{
	if ([_text length] == 0)
		return CGSizeMake(0, 0);
	NSSize measured = _attributedText != nil ? [[self uikitDrawnText:nil] size] : [_text sizeWithAttributes:[self textAttributes]];
	return CGSizeMake(measured.width, measured.height);
}

@end
