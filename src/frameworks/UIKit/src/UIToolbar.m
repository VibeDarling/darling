/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIToolbar.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIImage.h>
#import "UIKitPrivate.h"
#import <AppKit/NSGraphics.h>

/*
 * A row of bar button items: flexible spaces share what the others leave,
 * fixed spaces take their width, and the rest are as wide as they ask.
 */
@implementation UIToolbar {
	NSArray<UIBarButtonItem *> *_items;
	NSMutableArray<UIView *> *_itemViews;
	UIImage *_backgroundImage;
	UIImage *_shadowImage;
}

@synthesize barStyle = _barStyle;
@synthesize translucent = _translucent;
@synthesize barTintColor = _barTintColor;
@synthesize delegate = _delegate;

- (instancetype)initWithFrame:(CGRect)frame
{
	if (frame.size.height == 0)
		frame.size.height = 44;
	if ((self = [super initWithFrame:frame]) == nil)
		return nil;
	_items = @[];
	_itemViews = [NSMutableArray array];
	_translucent = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uikitItemChanged:) name:UIKitBarItemDidChangeNotification object:nil];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	_barStyle = [coder decodeIntegerForKey:@"UIBarStyle"];
	if ([coder containsValueForKey:@"UIBarTranslucence"])
		_translucent = [coder decodeIntegerForKey:@"UIBarTranslucence"] != 2;
	if ([coder containsValueForKey:@"UIBarTintColor"])
		_barTintColor = [coder decodeObjectForKey:@"UIBarTintColor"];
	NSArray *items = [coder decodeObjectForKey:@"UIItems"];
	if (items != nil)
		[self setItems:items];
}

- (NSArray *)items { return _items; }

- (void)setItems:(NSArray *)items
{
	_items = [items copy] ?: @[];
	[self uikitRebuild];
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated
{
	[self setItems:items];
}

- (void)uikitItemChanged:(NSNotification *)notification
{
	if ([_items containsObject:[notification object]])
		[self uikitRebuild];
}

- (void)uikitRebuild
{
	for (id view in _itemViews)
		if (view != [NSNull null])
			[(UIView *)view removeFromSuperview];
	[_itemViews removeAllObjects];
	for (UIBarButtonItem *item in _items) {
		UIView *view = [item uikitIsSpace] ? nil : UIKitViewForBarButtonItem(item, NO);
		[_itemViews addObject:view ?: (UIView *)[NSNull null]];
		if (view != nil)
			[self addSubview:view];
	}
	[self setNeedsLayout];
	[self setNeedsDisplay:YES];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	NSRect bounds = [self bounds];
	CGFloat used = 0;
	NSUInteger flexible = 0;
	NSUInteger count = [_items count];
	CGFloat widths[count > 0 ? count : 1];
	for (NSUInteger i = 0; i < count; i++) {
		UIBarButtonItem *item = [_items objectAtIndex:i];
		id view = [_itemViews objectAtIndex:i];
		if ([item uikitIsFlexibleSpace]) {
			widths[i] = -1;
			flexible++;
			continue;
		}
		if ([item uikitIsSpace])
			widths[i] = [item width];
		else if ([item width] > 0 && [item customView] == nil)
			widths[i] = [item width];
		else
			widths[i] = UIKitPreferredWidthOfBarView(view);
		used += widths[i];
	}
	/* Without flexible space, the items sit evenly spread. */
	CGFloat margin = 8;
	CGFloat spare = MAX(0, bounds.size.width - 2 * margin - used);
	CGFloat flexibleWidth = flexible > 0 ? floor(spare / flexible) : 0;
	CGFloat gap = flexible == 0 && count > 1 ? floor(spare / (count - 1)) : 0;
	CGFloat x = margin;
	for (NSUInteger i = 0; i < count; i++) {
		id view = [_itemViews objectAtIndex:i];
		CGFloat width = widths[i] < 0 ? flexibleWidth : widths[i];
		if (view != [NSNull null]) {
			CGFloat height = [(UIView *)view frame].size.height;
			if (height <= 0 || height > bounds.size.height || [[_items objectAtIndex:i] customView] == nil)
				height = bounds.size.height;
			[(UIView *)view setFrame:NSMakeRect(x, floor((bounds.size.height - height) / 2), width, height)];
		}
		x += width + gap;
	}
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	if (_backgroundImage != nil) {
		[_backgroundImage drawInRect:NSRectToCGRect(bounds)];
	} else {
		NSColor *fill = _barTintColor != nil ? [_barTintColor nsColor]
			: _barStyle == UIBarStyleDefault ? [NSColor colorWithCalibratedRed:0.97 green:0.97 blue:0.97 alpha:1]
			: [NSColor colorWithCalibratedWhite:0.1 alpha:1];
		[fill setFill];
		NSRectFill(bounds);
	}
	if (_shadowImage == nil) {
		[[NSColor colorWithCalibratedWhite:0.7 alpha:1] setFill];
		NSRectFill(NSMakeRect(0, 0, bounds.size.width, 0.5));
	}
}

- (CGSize)sizeThatFits:(CGSize)size
{
	return CGSizeMake(size.width, 44);
}

- (void)setBackgroundImage:(UIImage *)image forToolbarPosition:(UIBarPosition)position barMetrics:(UIBarMetrics)metrics
{
	_backgroundImage = image;
	[self setNeedsDisplay:YES];
}

- (UIImage *)backgroundImageForToolbarPosition:(UIBarPosition)position barMetrics:(UIBarMetrics)metrics { return _backgroundImage; }
- (void)setShadowImage:(UIImage *)image forToolbarPosition:(UIBarPosition)position { _shadowImage = image; [self setNeedsDisplay:YES]; }
- (UIImage *)shadowImageForToolbarPosition:(UIBarPosition)position { return _shadowImage; }

@end
