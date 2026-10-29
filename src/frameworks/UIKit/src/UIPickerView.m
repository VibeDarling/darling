/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIPickerView.h>
#import <UIKit/UIDatePicker.h>
#import <UIKit/UIColor.h>
#import <UIKit/UITouch.h>
#import "UIKitPrivate.h"
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSGraphics.h>

/*
 * Pickers show each component as a column: the selected row in the middle
 * band and its neighbours fading above and below. Dragging moves a column
 * a row at a time; tapping above or below the band steps by one.
 */

static void UIKitDrawPickerBand(NSRect bounds, CGFloat rowHeight)
{
	CGFloat top = floor((bounds.size.height - rowHeight) / 2);
	[[NSColor colorWithCalibratedWhite:0.8 alpha:1] setFill];
	NSRectFill(NSMakeRect(0, top, bounds.size.width, 0.5));
	NSRectFill(NSMakeRect(0, top + rowHeight, bounds.size.width, 0.5));
}

static void UIKitDrawPickerText(id text, NSRect cell, CGFloat distance)
{
	if (text == nil)
		return;
	NSAttributedString *string = text;
	if (![text isKindOfClass:[NSAttributedString class]]) {
		CGFloat alpha = distance == 0 ? 1 : MAX(0.15, 0.55 - 0.15 * distance);
		NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
		[style setAlignment:NSCenterTextAlignment];
		[style setLineBreakMode:NSLineBreakByTruncatingTail];
		string = [[NSAttributedString alloc] initWithString:text attributes:@{
			NSFontAttributeName: [NSFont systemFontOfSize:distance == 0 ? 21 : 19],
			NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0 alpha:alpha],
			NSParagraphStyleAttributeName: style,
		}];
	}
	NSSize size = [string size];
	[string drawInRect:NSMakeRect(cell.origin.x + 4, cell.origin.y + floor((cell.size.height - size.height) / 2), cell.size.width - 8, size.height)];
}

@implementation UIPickerView {
	NSMutableArray<NSNumber *> *_selected;
	NSMutableArray<NSNumber *> *_rows;
	NSMutableDictionary<NSIndexPath *, UIView *> *_rowViews;
	NSInteger _trackedComponent;
	NSInteger _trackedRow;
	CGFloat _trackStartY;
	BOOL _dragged;
}

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize showsSelectionIndicator = _showsSelectionIndicator;

- (instancetype)initWithFrame:(CGRect)frame
{
	if (frame.size.height == 0)
		frame.size.height = 216;
	if ((self = [super initWithFrame:frame]) == nil)
		return nil;
	_selected = [NSMutableArray array];
	_rows = [NSMutableArray array];
	_rowViews = [NSMutableDictionary dictionary];
	_trackedComponent = -1;
	[self setClipsToBounds:YES];
	return self;
}

- (CGSize)sizeThatFits:(CGSize)size
{
	return CGSizeMake(size.width > 0 ? size.width : 320, 216);
}

- (void)uikitReloadCounts
{
	id<UIPickerViewDataSource> dataSource = _dataSource;
	NSInteger components = dataSource != nil ? MAX(0, [dataSource numberOfComponentsInPickerView:self]) : 0;
	[_rows removeAllObjects];
	for (NSInteger c = 0; c < components; c++) {
		NSInteger rows = MAX(0, [dataSource pickerView:self numberOfRowsInComponent:c]);
		[_rows addObject:@(rows)];
		NSInteger selected = c < (NSInteger)[_selected count] ? [[_selected objectAtIndex:c] integerValue] : 0;
		selected = MIN(MAX(selected, 0), MAX(rows - 1, 0));
		if (c < (NSInteger)[_selected count])
			[_selected replaceObjectAtIndex:c withObject:@(selected)];
		else
			[_selected addObject:@(selected)];
	}
	while ((NSInteger)[_selected count] > components)
		[_selected removeLastObject];
}

- (NSInteger)numberOfComponents
{
	if ([_rows count] == 0)
		[self uikitReloadCounts];
	return [_rows count];
}

- (NSInteger)numberOfRowsInComponent:(NSInteger)component
{
	if (component < 0 || component >= [self numberOfComponents])
		return 0;
	return [[_rows objectAtIndex:component] integerValue];
}

- (CGFloat)uikitRowHeight:(NSInteger)component
{
	id<UIPickerViewDelegate> delegate = _delegate;
	if ([delegate respondsToSelector:@selector(pickerView:rowHeightForComponent:)])
		return MAX(1, [delegate pickerView:self rowHeightForComponent:component]);
	return 32;
}

/* Each column's x and width. */
- (NSRect)uikitColumn:(NSInteger)component
{
	NSInteger count = [self numberOfComponents];
	CGFloat total = [self bounds].size.width;
	id<UIPickerViewDelegate> delegate = _delegate;
	BOOL custom = [delegate respondsToSelector:@selector(pickerView:widthForComponent:)];
	CGFloat widths[count > 0 ? count : 1], sum = 0;
	for (NSInteger c = 0; c < count; c++) {
		widths[c] = custom ? [delegate pickerView:self widthForComponent:c] : total / count;
		sum += widths[c];
	}
	CGFloat x = custom ? floor((total - sum) / 2) : 0;
	for (NSInteger c = 0; c < component; c++)
		x += widths[c];
	return NSMakeRect(x, 0, component < count ? widths[component] : 0, [self bounds].size.height);
}

- (CGSize)rowSizeForComponent:(NSInteger)component
{
	return CGSizeMake([self uikitColumn:component].size.width, [self uikitRowHeight:component]);
}

- (id)uikitTitleForRow:(NSInteger)row component:(NSInteger)component
{
	id<UIPickerViewDelegate> delegate = _delegate;
	if ([delegate respondsToSelector:@selector(pickerView:attributedTitleForRow:forComponent:)]) {
		NSAttributedString *title = [delegate pickerView:self attributedTitleForRow:row forComponent:component];
		if (title != nil)
			return title;
	}
	if ([delegate respondsToSelector:@selector(pickerView:titleForRow:forComponent:)])
		return [delegate pickerView:self titleForRow:row forComponent:component];
	return nil;
}

- (BOOL)uikitUsesViews
{
	id<UIPickerViewDelegate> delegate = _delegate;
	return [delegate respondsToSelector:@selector(pickerView:viewForRow:forComponent:reusingView:)]
		&& ![delegate respondsToSelector:@selector(pickerView:titleForRow:forComponent:)]
		&& ![delegate respondsToSelector:@selector(pickerView:attributedTitleForRow:forComponent:)];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	if (![self uikitUsesViews])
		return;
	NSMutableDictionary *old = _rowViews;
	_rowViews = [NSMutableDictionary dictionary];
	NSRect bounds = [self bounds];
	for (NSInteger c = 0; c < [self numberOfComponents]; c++) {
		NSRect column = [self uikitColumn:c];
		CGFloat height = [self uikitRowHeight:c];
		NSInteger selected = [self selectedRowInComponent:c];
		NSInteger reach = (NSInteger)ceil(bounds.size.height / height / 2);
		for (NSInteger row = MAX(0, selected - reach); row <= MIN([self numberOfRowsInComponent:c] - 1, selected + reach); row++) {
			NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:c];
			UIView *reused = [old objectForKey:path];
			UIView *view = [_delegate pickerView:self viewForRow:row forComponent:c reusingView:reused];
			if (view == nil)
				continue;
			[old removeObjectForKey:path];
			CGFloat y = floor((bounds.size.height - height) / 2) + (row - selected) * height;
			[view setFrame:NSMakeRect(column.origin.x, y, column.size.width, height)];
			if ([view superview] != self)
				[self addSubview:view];
			[_rowViews setObject:view forKey:path];
		}
	}
	for (UIView *view in [old allValues])
		if (![[_rowViews allValues] containsObject:view])
			[view removeFromSuperview];
}

- (UIView *)viewForRow:(NSInteger)row forComponent:(NSInteger)component
{
	return [_rowViews objectForKey:[NSIndexPath indexPathForRow:row inSection:component]];
}

- (void)reloadAllComponents
{
	[self uikitReloadCounts];
	[self setNeedsLayout];
	[self setNeedsDisplay:YES];
}

- (void)reloadComponent:(NSInteger)component
{
	[self reloadAllComponents];
}

- (void)selectRow:(NSInteger)row inComponent:(NSInteger)component animated:(BOOL)animated
{
	if (component < 0 || component >= [self numberOfComponents])
		return;
	row = MIN(MAX(row, 0), MAX([self numberOfRowsInComponent:component] - 1, 0));
	[_selected replaceObjectAtIndex:component withObject:@(row)];
	[self setNeedsLayout];
	[self setNeedsDisplay:YES];
}

- (NSInteger)selectedRowInComponent:(NSInteger)component
{
	if (component < 0 || component >= [self numberOfComponents] || [self numberOfRowsInComponent:component] == 0)
		return -1;
	return [[_selected objectAtIndex:component] integerValue];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	NSRect bounds = [self bounds];
	BOOL views = [self uikitUsesViews];
	for (NSInteger c = 0; c < [self numberOfComponents]; c++) {
		NSRect column = [self uikitColumn:c];
		CGFloat height = [self uikitRowHeight:c];
		NSInteger selected = [self selectedRowInComponent:c];
		if (c == 0)
			UIKitDrawPickerBand(bounds, height);
		if (views || selected < 0)
			continue;
		NSInteger reach = (NSInteger)ceil(bounds.size.height / height / 2);
		for (NSInteger row = MAX(0, selected - reach); row <= MIN([self numberOfRowsInComponent:c] - 1, selected + reach); row++) {
			CGFloat y = floor((bounds.size.height - height) / 2) + (row - selected) * height;
			UIKitDrawPickerText([self uikitTitleForRow:row component:c], NSMakeRect(column.origin.x, y, column.size.width, height), labs(row - selected));
		}
	}
}

- (NSInteger)uikitComponentAt:(CGPoint)point
{
	for (NSInteger c = 0; c < [self numberOfComponents]; c++)
		if (NSPointInRect(NSMakePoint(point.x, point.y), [self uikitColumn:c]))
			return c;
	return -1;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGPoint point = [[touches anyObject] locationInView:self];
	_trackedComponent = [self uikitComponentAt:point];
	_trackedRow = [self selectedRowInComponent:_trackedComponent];
	_trackStartY = point.y;
	_dragged = NO;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (_trackedComponent < 0)
		return;
	CGFloat dy = [[touches anyObject] locationInView:self].y - _trackStartY;
	if (fabs(dy) > 5)
		_dragged = YES;
	NSInteger steps = (NSInteger)round(-dy / [self uikitRowHeight:_trackedComponent]);
	[self selectRow:_trackedRow + steps inComponent:_trackedComponent animated:NO];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSInteger component = _trackedComponent;
	_trackedComponent = -1;
	if (component < 0)
		return;
	if (!_dragged) {
		CGFloat y = [[touches anyObject] locationInView:self].y;
		CGFloat height = [self uikitRowHeight:component];
		CGFloat top = floor(([self bounds].size.height - height) / 2);
		NSInteger steps = y < top ? -(NSInteger)ceil((top - y) / height) : y > top + height ? (NSInteger)ceil((y - top - height) / height) : 0;
		[self selectRow:_trackedRow + steps inComponent:component animated:YES];
	}
	NSInteger row = [self selectedRowInComponent:component];
	if (row != _trackedRow && [_delegate respondsToSelector:@selector(pickerView:didSelectRow:inComponent:)])
		[_delegate pickerView:self didSelectRow:row inComponent:component];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	_trackedComponent = -1;
}

@end

#pragma mark - UIDatePicker

/* Shows the date as iOS would format it; tapping above the band moves it
 * one step later, below one step earlier. */
@implementation UIDatePicker {
	NSDate *_date;
}

@synthesize datePickerMode = _datePickerMode;
@synthesize minimumDate = _minimumDate;
@synthesize maximumDate = _maximumDate;
@synthesize locale = _locale;
@synthesize calendar = _calendar;
@synthesize timeZone = _timeZone;
@synthesize countDownDuration = _countDownDuration;
@synthesize minuteInterval = _minuteInterval;

- (instancetype)initWithFrame:(CGRect)frame
{
	if (frame.size.height == 0)
		frame.size.height = 216;
	if ((self = [super initWithFrame:frame]) == nil)
		return nil;
	_date = [NSDate date];
	_datePickerMode = UIDatePickerModeDateAndTime;
	_minuteInterval = 1;
	return self;
}

- (NSDate *)date { return _date; }

- (void)setDate:(NSDate *)date
{
	if (date == nil)
		return;
	if (_minimumDate != nil && [date compare:_minimumDate] == NSOrderedAscending)
		date = _minimumDate;
	if (_maximumDate != nil && [date compare:_maximumDate] == NSOrderedDescending)
		date = _maximumDate;
	_date = date;
	[self setNeedsDisplay:YES];
}

- (void)setDate:(NSDate *)date animated:(BOOL)animated { [self setDate:date]; }
- (void)setDatePickerMode:(UIDatePickerMode)mode { _datePickerMode = mode; [self setNeedsDisplay:YES]; }

- (CGSize)sizeThatFits:(CGSize)size
{
	return CGSizeMake(size.width > 0 ? size.width : 320, 216);
}

- (NSString *)uikitText
{
	if (_datePickerMode == UIDatePickerModeCountDownTimer) {
		NSInteger minutes = (NSInteger)(_countDownDuration / 60);
		return [NSString stringWithFormat:@"%ld hours %ld min", (long)(minutes / 60), (long)(minutes % 60)];
	}
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	if (_locale != nil)
		[formatter setLocale:_locale];
	if (_timeZone != nil)
		[formatter setTimeZone:_timeZone];
	[formatter setDateStyle:_datePickerMode == UIDatePickerModeTime ? NSDateFormatterNoStyle : NSDateFormatterMediumStyle];
	[formatter setTimeStyle:_datePickerMode == UIDatePickerModeDate ? NSDateFormatterNoStyle : NSDateFormatterShortStyle];
	return [formatter stringFromDate:_date];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	NSRect bounds = [self bounds];
	UIKitDrawPickerBand(bounds, 32);
	UIKitDrawPickerText([self uikitText], NSMakeRect(0, floor((bounds.size.height - 32) / 2), bounds.size.width, 32), 0);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self isTracking]) {
		CGPoint point = [[touches anyObject] locationInView:self];
		NSInteger direction = point.y < [self bounds].size.height / 2 ? 1 : -1;
		NSTimeInterval minute = 60 * MAX(_minuteInterval, 1);
		if (_datePickerMode == UIDatePickerModeCountDownTimer) {
			_countDownDuration = MAX(60, _countDownDuration + direction * minute);
			[self setNeedsDisplay:YES];
		} else {
			/* In date-and-time mode the left half moves the day, the right the time. */
			BOOL byDay = _datePickerMode == UIDatePickerModeDate
				|| (_datePickerMode == UIDatePickerModeDateAndTime && point.x < [self bounds].size.width / 2);
			[self setDate:[_date dateByAddingTimeInterval:direction * (byDay ? 86400 : minute)]];
		}
		[self sendActionsForControlEvents:UIControlEventValueChanged];
	}
	[super touchesEnded:touches withEvent:event];
}

@end
