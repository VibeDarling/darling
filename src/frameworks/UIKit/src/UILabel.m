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
}

@synthesize adjustsFontSizeToFitWidth = _adjustsFontSizeToFitWidth;
@synthesize minimumFontSize = _minimumFontSize;
@synthesize minimumScaleFactor = _minimumScaleFactor;
@synthesize shadowColor = _shadowColor;
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

- (NSString *)text
{
	return _text;
}

- (void)setText:(NSString *)text
{
	_text = [text copy];
	[self setNeedsDisplay:YES];
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

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	if ([_text length] == 0)
		return;

	/* UIKit centres a label's text vertically in its bounds. */
	NSDictionary *attributes = [self textAttributes];
	NSRect bounds = [self bounds];
	CGFloat textHeight = [_text sizeWithAttributes:attributes].height;
	if (textHeight < bounds.size.height) {
		bounds.origin.y += (bounds.size.height - textHeight) / 2;
		bounds.size.height = textHeight;
	}
	NSString *text = _text;
	/* One line: cut it to the width with an ellipsis. */
	if (_numberOfLines == 1 && [text sizeWithAttributes:attributes].width > bounds.size.width && _lineBreakMode != NSLineBreakByClipping) {
		NSUInteger length = [text length];
		while (length > 0 && [[[text substringToIndex:length] stringByAppendingString:@"\u2026"] sizeWithAttributes:attributes].width > bounds.size.width)
			length--;
		text = [[text substringToIndex:length] stringByAppendingString:@"\u2026"];
	}
	[text drawInRect:bounds withAttributes:attributes];
}

- (CGSize)sizeThatFits:(CGSize)size
{
	if ([_text length] == 0)
		return CGSizeMake(0, 0);
	NSSize measured = [_text sizeWithAttributes:[self textAttributes]];
	return CGSizeMake(measured.width, measured.height);
}

@end
