/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * UITableView keeps only the cells in view: it records every row's offset
 * when the data is (re)loaded, and on each scroll asks its data source for
 * the rows that came into view, recycling the ones that left.
 */

#import <UIKit/UITableView.h>
#import <UIKit/UILabel.h>
#import <UIKit/UIImageView.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIImage.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSGraphics.h>
#import "UIKitPrivate.h"

NSString *const UITableViewIndexSearch = @"{search}";
const CGFloat UITableViewAutomaticDimension = -1;

static const CGFloat UIKitDeleteButtonWidth = 82;

@implementation NSIndexPath (UITableView)

+ (NSIndexPath *)indexPathForRow:(NSInteger)row inSection:(NSInteger)section
{
	NSUInteger indexes[2] = { (NSUInteger)section, (NSUInteger)row };
	return [NSIndexPath indexPathWithIndexes:indexes length:2];
}

+ (NSIndexPath *)indexPathForItem:(NSInteger)item inSection:(NSInteger)section
{
	return [self indexPathForRow:item inSection:section];
}

- (NSInteger)section
{
	return [self length] > 0 ? (NSInteger)[self indexAtPosition:0] : NSNotFound;
}

- (NSInteger)row
{
	return [self length] > 1 ? (NSInteger)[self indexAtPosition:1] : NSNotFound;
}

- (NSInteger)item
{
	return [self row];
}

@end

#pragma mark - Cells

@interface UITableViewCell ()
@property (nonatomic, weak) UITableView *uikitTableView;
@property (nonatomic) BOOL uikitShowsDeleteButton;
@end

@implementation UITableViewCell {
	NSString *_reuseIdentifier;
	UITableViewCellStyle _style;
	UIView *_contentView;
	UILabel *_textLabel;
	UILabel *_detailTextLabel;
	UIImageView *_imageView;
	UIView *_backgroundView;
	UIView *_selectedBackgroundView;
	UIView *_accessoryView;
	UIView *_editingAccessoryView;
	UITableViewCellAccessoryType _accessoryType;
	UITableViewCellAccessoryType _editingAccessoryType;
	BOOL _selected;
	BOOL _highlighted;
	BOOL _editing;
	UIColor *_selectedTextColor;
}

@synthesize selectionStyle = _selectionStyle;
@synthesize indentationLevel = _indentationLevel;
@synthesize indentationWidth = _indentationWidth;
@synthesize showsReorderControl = _showsReorderControl;
@synthesize shouldIndentWhileEditing = _shouldIndentWhileEditing;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 44)]) == nil)
		return nil;
	_style = style;
	_reuseIdentifier = [reuseIdentifier copy];
	_selectionStyle = UITableViewCellSelectionStyleBlue;
	_indentationWidth = 10;
	_shouldIndentWhileEditing = YES;
	[self setBackgroundColor:[UIColor whiteColor]];
	[self setAutoresizesSubviews:YES];
	_contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
	[_contentView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[self addSubview:_contentView];
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
	if ((self = [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]))
		[self setFrame:frame];
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame reuseIdentifier:nil];
}

- (NSString *)reuseIdentifier { return _reuseIdentifier; }
- (UIView *)contentView { return _contentView; }

- (UILabel *)textLabel
{
	if (_textLabel == nil) {
		_textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_textLabel setFont:[UIFont systemFontOfSize:_style == UITableViewCellStyleSubtitle ? 17 : 17]];
		[_textLabel setHighlightedTextColor:[UIColor blackColor]];
		[_contentView addSubview:_textLabel];
		[self setNeedsLayout];
	}
	return _textLabel;
}

- (UILabel *)detailTextLabel
{
	if (_detailTextLabel == nil && _style != UITableViewCellStyleDefault) {
		_detailTextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_detailTextLabel setFont:[UIFont systemFontOfSize:_style == UITableViewCellStyleSubtitle ? 12 : 17]];
		[_detailTextLabel setTextColor:_style == UITableViewCellStyleValue1 ? [UIColor colorWithWhite:0.56 alpha:1] : [UIColor blackColor]];
		if (_style == UITableViewCellStyleValue1)
			[_detailTextLabel setTextAlignment:NSTextAlignmentRight];
		[_contentView addSubview:_detailTextLabel];
		[self setNeedsLayout];
	}
	return _detailTextLabel;
}

- (UIImageView *)imageView
{
	if (_imageView == nil) {
		_imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
		[_contentView addSubview:_imageView];
		[self setNeedsLayout];
	}
	return _imageView;
}

- (UIView *)backgroundView { return _backgroundView; }

- (void)setBackgroundView:(UIView *)view
{
	[_backgroundView removeFromSuperview];
	_backgroundView = view;
	if (view != nil) {
		[view setFrame:[self bounds]];
		[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[self insertSubview:view atIndex:0];
	}
}

- (UIView *)selectedBackgroundView { return _selectedBackgroundView; }
- (void)setSelectedBackgroundView:(UIView *)view { _selectedBackgroundView = view; [self updateSelectionAppearance]; }
- (UITableViewCellAccessoryType)accessoryType { return _accessoryType; }
- (void)setAccessoryType:(UITableViewCellAccessoryType)type { _accessoryType = type; [self setNeedsLayout]; [self setNeedsDisplay:YES]; }
- (UITableViewCellAccessoryType)editingAccessoryType { return _editingAccessoryType; }
- (void)setEditingAccessoryType:(UITableViewCellAccessoryType)type { _editingAccessoryType = type; }
- (UIView *)editingAccessoryView { return _editingAccessoryView; }
- (void)setEditingAccessoryView:(UIView *)view { _editingAccessoryView = view; }
- (UIView *)accessoryView { return _accessoryView; }

- (void)setAccessoryView:(UIView *)view
{
	[_accessoryView removeFromSuperview];
	_accessoryView = view;
	if (view != nil)
		[self addSubview:view];
	[self setNeedsLayout];
}

- (UITableViewCellEditingStyle)editingStyle
{
	return _uikitShowsDeleteButton ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (void)setUikitShowsDeleteButton:(BOOL)shows
{
	_uikitShowsDeleteButton = shows;
	[self setNeedsLayout];
	[self setNeedsDisplay:YES];
}

- (CGFloat)accessoryWidth
{
	if (_uikitShowsDeleteButton)
		return UIKitDeleteButtonWidth;
	if (_accessoryView != nil)
		return [_accessoryView frame].size.width + 15;
	switch (_accessoryType) {
	case UITableViewCellAccessoryNone: return 0;
	case UITableViewCellAccessoryCheckmark: return 38;
	default: return 33;
	}
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	NSRect bounds = [self bounds];
	CGFloat accessory = [self accessoryWidth];
	CGFloat indent = _indentationLevel * _indentationWidth;
	[_contentView setFrame:NSMakeRect(indent, 0, MAX(0, bounds.size.width - accessory - indent), bounds.size.height)];
	if (_accessoryView != nil && !_uikitShowsDeleteButton) {
		NSRect frame = [_accessoryView frame];
		frame.origin.x = bounds.size.width - frame.size.width - 15;
		frame.origin.y = floor((bounds.size.height - frame.size.height) / 2);
		[_accessoryView setFrame:frame];
		[_accessoryView setHidden:NO];
	} else {
		[_accessoryView setHidden:YES];
	}

	NSRect content = [_contentView bounds];
	CGFloat x = 15;
	if (_imageView != nil && [_imageView image] != nil) {
		CGSize size = [[_imageView image] size];
		CGFloat height = MIN(size.height, content.size.height);
		CGFloat width = size.height > 0 ? size.width * height / size.height : size.width;
		[_imageView setFrame:NSMakeRect(x, floor((content.size.height - height) / 2), width, height)];
		x += width + 15;
	}
	CGFloat width = MAX(0, content.size.width - x - 10);
	if (_style == UITableViewCellStyleSubtitle && [[_detailTextLabel text] length] > 0) {
		CGFloat top = floor((content.size.height - 40) / 2);
		[_textLabel setFrame:NSMakeRect(x, top, width, 22)];
		[_detailTextLabel setFrame:NSMakeRect(x, top + 22, width, 18)];
	} else if (_style == UITableViewCellStyleValue1 && _detailTextLabel != nil) {
		CGFloat detail = MIN(width / 2, [[_detailTextLabel text] sizeWithFont:[_detailTextLabel font]].width + 2);
		[_textLabel setFrame:NSMakeRect(x, 0, width - detail - 6, content.size.height)];
		[_detailTextLabel setFrame:NSMakeRect(x + width - detail, 0, detail, content.size.height)];
	} else if (_style == UITableViewCellStyleValue2 && _detailTextLabel != nil) {
		[_textLabel setFrame:NSMakeRect(x, 0, 80, content.size.height)];
		[_detailTextLabel setFrame:NSMakeRect(x + 86, 0, MAX(0, width - 86), content.size.height)];
	} else {
		[_textLabel setFrame:NSMakeRect(x, 0, width, content.size.height)];
	}
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	BOOL highlighted = (_selected || _highlighted) && _selectionStyle != UITableViewCellSelectionStyleNone;
	if (highlighted && _selectedBackgroundView == nil) {
		[[NSColor colorWithCalibratedWhite:0.85 alpha:1] setFill];
		NSRectFill(rect);
	} else {
		[super drawRect:rect];
	}

	CGFloat midY = NSMidY(bounds);
	CGFloat right = bounds.size.width;
	if (_uikitShowsDeleteButton) {
		NSRect button = NSMakeRect(right - UIKitDeleteButtonWidth, 0, UIKitDeleteButtonWidth, bounds.size.height);
		[[NSColor colorWithCalibratedRed:1 green:0.23 blue:0.19 alpha:1] setFill];
		NSRectFill(button);
		NSDictionary *attributes = @{ NSFontAttributeName: [NSFont systemFontOfSize:17], NSForegroundColorAttributeName: [NSColor whiteColor] };
		NSString *title = @"Delete";
		NSSize size = [title sizeWithAttributes:attributes];
		[title drawAtPoint:NSMakePoint(NSMidX(button) - size.width / 2, midY - size.height / 2) withAttributes:attributes];
		return;
	}
	if (_accessoryView != nil)
		return;
	if (_accessoryType == UITableViewCellAccessoryDisclosureIndicator || _accessoryType == UITableViewCellAccessoryDetailDisclosureButton) {
		NSBezierPath *chevron = [NSBezierPath bezierPath];
		[chevron moveToPoint:NSMakePoint(right - 22, midY - 6.5)];
		[chevron lineToPoint:NSMakePoint(right - 15.5, midY)];
		[chevron lineToPoint:NSMakePoint(right - 22, midY + 6.5)];
		[chevron setLineWidth:2];
		[[NSColor colorWithCalibratedWhite:0.78 alpha:1] setStroke];
		[chevron stroke];
	} else if (_accessoryType == UITableViewCellAccessoryCheckmark) {
		NSBezierPath *check = [NSBezierPath bezierPath];
		[check moveToPoint:NSMakePoint(right - 30, midY)];
		[check lineToPoint:NSMakePoint(right - 25, midY + 5)];
		[check lineToPoint:NSMakePoint(right - 15, midY - 6)];
		[check setLineWidth:2];
		[UIKitTintColor() setStroke];
		[check stroke];
	}
}

- (BOOL)isSelected { return _selected; }
- (BOOL)isHighlighted { return _highlighted; }
- (void)setSelected:(BOOL)selected { [self setSelected:selected animated:NO]; }
- (void)setHighlighted:(BOOL)highlighted { [self setHighlighted:highlighted animated:NO]; }

- (void)updateSelectionAppearance
{
	BOOL on = (_selected || _highlighted) && _selectionStyle != UITableViewCellSelectionStyleNone;
	if (_selectedBackgroundView != nil) {
		if (on && [_selectedBackgroundView superview] != self) {
			[_selectedBackgroundView setFrame:[self bounds]];
			[_selectedBackgroundView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
			[self insertSubview:_selectedBackgroundView belowSubview:_contentView];
		} else if (!on) {
			[_selectedBackgroundView removeFromSuperview];
		}
	}
	[self _updateHighlightColorsForView:_contentView highlighted:on];
	[self setNeedsDisplay:YES];
	[_contentView setNeedsDisplay:YES];
	for (NSView *view in [_contentView subviews])
		[view setNeedsDisplay:YES];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
	_selected = selected;
	[self updateSelectionAppearance];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
	_highlighted = highlighted;
	[self updateSelectionAppearance];
}

- (void)_updateHighlightColorsForView:(id)view highlighted:(BOOL)highlighted
{
	for (NSView *subview in [view subviews]) {
		if ([subview respondsToSelector:@selector(setHighlighted:)])
			[(id)subview setHighlighted:highlighted];
	}
}

- (float)selectionPercent
{
	return _selected ? 1 : 0;
}

- (BOOL)isEditing { return _editing; }
- (void)setEditing:(BOOL)editing { [self setEditing:editing animated:NO]; }

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	_editing = editing;
	[self setNeedsLayout];
}

- (void)prepareForReuse
{
	_highlighted = NO;
	_selected = NO;
	[self updateSelectionAppearance];
}

/* Taps on the cell are the table's business. */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[[self uikitTableView] touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[[self uikitTableView] touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[[self uikitTableView] touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[[self uikitTableView] touchesCancelled:touches withEvent:event];
}

#pragma mark iPhone OS 2 API

- (NSString *)text { return [_textLabel text]; }
- (void)setText:(NSString *)text { [[self textLabel] setText:text]; }
- (UIFont *)font { return [[self textLabel] font]; }
- (void)setFont:(UIFont *)font { [[self textLabel] setFont:font]; }
- (UIColor *)textColor { return [[self textLabel] textColor]; }
- (void)setTextColor:(UIColor *)color { [[self textLabel] setTextColor:color]; }
- (UIColor *)selectedTextColor { return _selectedTextColor; }
- (void)setSelectedTextColor:(UIColor *)color { _selectedTextColor = color; [[self textLabel] setHighlightedTextColor:color]; }
- (UIImage *)image { return [_imageView image]; }
- (void)setImage:(UIImage *)image { [[self imageView] setImage:image]; [self setNeedsLayout]; }
- (NSTextAlignment)textAlignment { return [[self textLabel] textAlignment]; }
- (void)setTextAlignment:(NSTextAlignment)alignment { [[self textLabel] setTextAlignment:alignment]; }

@end

#pragma mark - Section headers and the index

@interface UIKitTableSectionHeader : UIView
@property (nonatomic, copy) NSString *title;
@property (nonatomic) BOOL grouped;
@property (nonatomic) BOOL footer;
@end

@implementation UIKitTableSectionHeader

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	if (!_grouped) {
		[[NSColor colorWithCalibratedRed:0.97 green:0.97 blue:0.97 alpha:1] setFill];
		NSRectFill(rect);
	}
	if ([_title length] == 0)
		return;
	NSDictionary *attributes = @{
		NSFontAttributeName: _grouped ? [NSFont systemFontOfSize:13] : [NSFont boldSystemFontOfSize:15],
		NSForegroundColorAttributeName: _grouped ? [NSColor colorWithCalibratedWhite:0.43 alpha:1] : [NSColor blackColor],
	};
	NSString *title = _grouped && !_footer ? [_title uppercaseString] : _title;
	NSSize size = [title sizeWithAttributes:attributes];
	CGFloat y = _grouped ? (_footer ? 6 : bounds.size.height - size.height - 6) : floor((bounds.size.height - size.height) / 2);
	[title drawInRect:NSMakeRect(15, y, bounds.size.width - 30, size.height) withAttributes:attributes];
}

- (NSView *)hitTest:(NSPoint)point
{
	return nil;
}

@end

@interface UIKitTableIndex : UIView
@property (nonatomic, copy) NSArray *titles;
@property (nonatomic, weak) UITableView *tableView;
@end

@interface UITableView ()
- (void)uikitJumpToIndexTitleAtIndex:(NSInteger)index;
@end

@implementation UIKitTableIndex

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	NSUInteger count = [_titles count];
	if (count == 0)
		return;
	CGFloat step = MIN(16, (bounds.size.height - 8) / count);
	CGFloat top = floor((bounds.size.height - step * count) / 2);
	NSDictionary *attributes = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize:11], NSForegroundColorAttributeName: UIKitTintColor() };
	[_titles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger i, BOOL *stop) {
		NSSize size = [title sizeWithAttributes:attributes];
		[title drawAtPoint:NSMakePoint(floor(NSMidX(bounds) - size.width / 2), top + i * step + (step - size.height) / 2) withAttributes:attributes];
	}];
}

- (void)jumpForTouches:(NSSet *)touches
{
	NSRect bounds = [self bounds];
	NSUInteger count = [_titles count];
	if (count == 0)
		return;
	CGFloat step = MIN(16, (bounds.size.height - 8) / count);
	CGFloat top = floor((bounds.size.height - step * count) / 2);
	CGPoint point = [[touches anyObject] locationInView:self];
	NSInteger index = (NSInteger)floor((point.y - top) / step);
	index = MAX(0, MIN((NSInteger)count - 1, index));
	[_tableView uikitJumpToIndexTitleAtIndex:index];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event { [self jumpForTouches:touches]; }
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event { [self jumpForTouches:touches]; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { }

@end

#pragma mark - UITableView

/* One section's geometry, in content coordinates. */
@interface UIKitTableSection : NSObject {
@public
	NSInteger rows;
	CGFloat top;
	CGFloat headerHeight;
	CGFloat footerHeight;
	CGFloat rowsTop;
	CGFloat *rowOffsets; /* rows + 1 entries: each row's top, then the end */
	NSString *headerTitle;
	NSString *footerTitle;
}
@end

@implementation UIKitTableSection

- (void)dealloc
{
	free(rowOffsets);
}

@end

@implementation UITableView {
	UITableViewStyle _style;
	__weak id<UITableViewDataSource> _dataSource;
	CGFloat _rowHeight;
	NSMutableArray<UIKitTableSection *> *_sections;
	NSMutableDictionary<NSIndexPath *, UITableViewCell *> *_visibleCells;
	NSMutableDictionary<NSString *, NSMutableArray<UITableViewCell *> *> *_reusableCells;
	NSMutableDictionary<NSString *, Class> *_registeredClasses;
	NSMutableDictionary<NSString *, UIView *> *_headerViews;
	NSMutableSet<NSIndexPath *> *_selectedRows;
	UIView *_tableHeaderView;
	UIView *_tableFooterView;
	UIView *_backgroundView;
	UIKitTableIndex *_indexView;
	NSArray *_indexTitles;
	NSIndexPath *_pressedRow;
	NSInteger _updateDepth;
	BOOL _editing;
	BOOL _needsReload;
	BOOL _tiling;
}

@synthesize estimatedRowHeight = _estimatedRowHeight;
@synthesize sectionHeaderHeight = _sectionHeaderHeight;
@synthesize sectionFooterHeight = _sectionFooterHeight;
@synthesize separatorStyle = _separatorStyle;
@synthesize separatorColor = _separatorColor;
@synthesize separatorInset = _separatorInset;
@synthesize allowsSelection = _allowsSelection;
@synthesize allowsSelectionDuringEditing = _allowsSelectionDuringEditing;
@synthesize allowsMultipleSelection = _allowsMultipleSelection;
@synthesize sectionIndexMinimumDisplayRowCount = _sectionIndexMinimumDisplayRowCount;
@synthesize sectionIndexColor = _sectionIndexColor;
@synthesize sectionIndexBackgroundColor = _sectionIndexBackgroundColor;

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
	if ((self = [super initWithFrame:frame]) == nil)
		return nil;
	_style = style;
	_rowHeight = 44;
	_sectionHeaderHeight = style == UITableViewStyleGrouped ? 35 : 22;
	_sectionFooterHeight = style == UITableViewStyleGrouped ? 17 : 22;
	_separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	_separatorColor = [UIColor colorWithRed:0.78 green:0.78 blue:0.8 alpha:1];
	_separatorInset = UIEdgeInsetsMake(0, 15, 0, 0);
	_allowsSelection = YES;
	_sections = [NSMutableArray array];
	_visibleCells = [NSMutableDictionary dictionary];
	_reusableCells = [NSMutableDictionary dictionary];
	_registeredClasses = [NSMutableDictionary dictionary];
	_headerViews = [NSMutableDictionary dictionary];
	_selectedRows = [NSMutableSet set];
	_needsReload = YES;
	[self setBackgroundColor:style == UITableViewStyleGrouped ? [UIColor groupTableViewBackgroundColor] : [UIColor whiteColor]];
	[self setAlwaysBounceVertical:YES];
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame style:UITableViewStylePlain];
}

- (UITableViewStyle)style { return _style; }
- (id<UITableViewDataSource>)dataSource { return _dataSource; }

- (void)setDataSource:(id<UITableViewDataSource>)dataSource
{
	_dataSource = dataSource;
	_needsReload = YES;
	[self setNeedsLayout];
}

- (id<UITableViewDelegate>)delegate
{
	return (id<UITableViewDelegate>)[super delegate];
}

- (void)setDelegate:(id<UITableViewDelegate>)delegate
{
	[super setDelegate:delegate];
	_needsReload = YES;
	[self setNeedsLayout];
}

- (CGFloat)rowHeight { return _rowHeight; }

- (void)setRowHeight:(CGFloat)rowHeight
{
	_rowHeight = rowHeight > 0 ? rowHeight : 44;
	_needsReload = YES;
	[self setNeedsLayout];
}

- (UIView *)tableHeaderView { return _tableHeaderView; }

- (void)setTableHeaderView:(UIView *)view
{
	[_tableHeaderView removeFromSuperview];
	_tableHeaderView = view;
	if (view != nil)
		[self addSubview:view];
	_needsReload = YES;
	[self setNeedsLayout];
}

- (UIView *)tableFooterView { return _tableFooterView; }

- (void)setTableFooterView:(UIView *)view
{
	[_tableFooterView removeFromSuperview];
	_tableFooterView = view;
	if (view != nil)
		[self addSubview:view];
	_needsReload = YES;
	[self setNeedsLayout];
}

- (UIView *)backgroundView { return _backgroundView; }
- (void)setBackgroundView:(UIView *)view { _backgroundView = view; }

#pragma mark Data

- (NSInteger)numberOfSections
{
	[self reloadIfNeeded];
	return [_sections count];
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section
{
	[self reloadIfNeeded];
	return section >= 0 && section < (NSInteger)[_sections count] ? ((UIKitTableSection *)[_sections objectAtIndex:section])->rows : 0;
}

- (void)reloadIfNeeded
{
	if (_needsReload)
		[self reloadData];
}

- (void)reloadData
{
	_needsReload = NO;
	for (UITableViewCell *cell in [_visibleCells allValues])
		[self recycleCell:cell];
	[_visibleCells removeAllObjects];
	for (UIView *view in [_headerViews allValues])
		[view removeFromSuperview];
	[_headerViews removeAllObjects];
	[_selectedRows removeAllObjects];
	[_sections removeAllObjects];

	id<UITableViewDataSource> dataSource = _dataSource;
	id<UITableViewDelegate> delegate = [self delegate];
	CGFloat width = [self bounds].size.width;
	CGFloat y = 0;
	if (_tableHeaderView != nil) {
		NSRect frame = [_tableHeaderView frame];
		[_tableHeaderView setFrame:NSMakeRect(0, 0, width, frame.size.height)];
		y += frame.size.height;
	}

	NSInteger count = 0;
	if (dataSource != nil)
		count = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:self] : 1;
	BOOL variable = [delegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)];
	for (NSInteger s = 0; s < count; s++) {
		UIKitTableSection *section = [[UIKitTableSection alloc] init];
		section->top = y;
		section->rows = MAX(0, [dataSource tableView:self numberOfRowsInSection:s]);
		if ([dataSource respondsToSelector:@selector(tableView:titleForHeaderInSection:)])
			section->headerTitle = [[dataSource tableView:self titleForHeaderInSection:s] copy];
		if ([dataSource respondsToSelector:@selector(tableView:titleForFooterInSection:)])
			section->footerTitle = [[dataSource tableView:self titleForFooterInSection:s] copy];

		BOOL hasHeaderView = [delegate respondsToSelector:@selector(tableView:viewForHeaderInSection:)];
		if ([delegate respondsToSelector:@selector(tableView:heightForHeaderInSection:)])
			section->headerHeight = MAX(0, [delegate tableView:self heightForHeaderInSection:s]);
		else if (section->headerTitle != nil || hasHeaderView || _style == UITableViewStyleGrouped)
			section->headerHeight = _style == UITableViewStyleGrouped && section->headerTitle == nil ? (s == 0 ? 35 : 17) : _sectionHeaderHeight;
		if ([delegate respondsToSelector:@selector(tableView:heightForFooterInSection:)])
			section->footerHeight = MAX(0, [delegate tableView:self heightForFooterInSection:s]);
		else if (section->footerTitle != nil)
			section->footerHeight = _style == UITableViewStyleGrouped ? 40 : _sectionFooterHeight;
		else if (_style == UITableViewStyleGrouped)
			section->footerHeight = _sectionFooterHeight;

		y += section->headerHeight;
		section->rowsTop = y;
		section->rowOffsets = malloc(sizeof(CGFloat) * (section->rows + 1));
		for (NSInteger r = 0; r < section->rows; r++) {
			section->rowOffsets[r] = y;
			CGFloat height = _rowHeight;
			if (variable) {
				height = [delegate tableView:self heightForRowAtIndexPath:[NSIndexPath indexPathForRow:r inSection:s]];
				if (height < 0)
					height = _rowHeight;
			}
			y += height;
		}
		section->rowOffsets[section->rows] = y;
		y += section->footerHeight;
		[_sections addObject:section];
	}
	if (_tableFooterView != nil) {
		NSRect frame = [_tableFooterView frame];
		[_tableFooterView setFrame:NSMakeRect(0, y, width, frame.size.height)];
		y += frame.size.height;
	}
	[self setContentSize:CGSizeMake(width, y)];
	[self reloadSectionIndexTitles];
	[self tile];
	[self setNeedsDisplay:YES];
}

- (void)reloadSectionIndexTitles
{
	id<UITableViewDataSource> dataSource = _dataSource;
	_indexTitles = nil;
	NSInteger rows = 0;
	for (UIKitTableSection *section in _sections)
		rows += section->rows;
	if ([dataSource respondsToSelector:@selector(sectionIndexTitlesForTableView:)] && rows >= _sectionIndexMinimumDisplayRowCount)
		_indexTitles = [[dataSource sectionIndexTitlesForTableView:self] copy];
	if ([_indexTitles count] == 0) {
		[_indexView removeFromSuperview];
		_indexView = nil;
		return;
	}
	if (_indexView == nil) {
		_indexView = [[UIKitTableIndex alloc] initWithFrame:CGRectZero];
		[_indexView setTableView:self];
	}
	[_indexView setTitles:[_indexTitles valueForKey:@"description"]];
	[_indexView setNeedsDisplay:YES];
}

- (void)uikitJumpToIndexTitleAtIndex:(NSInteger)index
{
	id<UITableViewDataSource> dataSource = _dataSource;
	if (index < 0 || index >= (NSInteger)[_indexTitles count])
		return;
	NSInteger section = index;
	if ([dataSource respondsToSelector:@selector(tableView:sectionForSectionIndexTitle:atIndex:)])
		section = [dataSource tableView:self sectionForSectionIndexTitle:[_indexTitles objectAtIndex:index] atIndex:index];
	if (section < 0 || section >= (NSInteger)[_sections count])
		return;
	UIKitTableSection *info = [_sections objectAtIndex:section];
	CGPoint offset = CGPointMake(0, info->top);
	CGFloat maxY = MAX(0, [self contentSize].height - [self bounds].size.height);
	offset.y = MIN(offset.y, maxY);
	[self setContentOffset:offset];
}

#pragma mark Geometry

- (CGRect)rectForSection:(NSInteger)section
{
	[self reloadIfNeeded];
	if (section < 0 || section >= (NSInteger)[_sections count])
		return CGRectZero;
	UIKitTableSection *info = [_sections objectAtIndex:section];
	CGFloat bottom = info->rowOffsets[info->rows] + info->footerHeight;
	return CGRectMake(0, info->top, [self bounds].size.width, bottom - info->top);
}

- (CGRect)rectForHeaderInSection:(NSInteger)section
{
	[self reloadIfNeeded];
	if (section < 0 || section >= (NSInteger)[_sections count])
		return CGRectZero;
	UIKitTableSection *info = [_sections objectAtIndex:section];
	return CGRectMake(0, info->top, [self bounds].size.width, info->headerHeight);
}

- (CGRect)rectForFooterInSection:(NSInteger)section
{
	[self reloadIfNeeded];
	if (section < 0 || section >= (NSInteger)[_sections count])
		return CGRectZero;
	UIKitTableSection *info = [_sections objectAtIndex:section];
	return CGRectMake(0, info->rowOffsets[info->rows], [self bounds].size.width, info->footerHeight);
}

- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self reloadIfNeeded];
	NSInteger s = [indexPath section], r = [indexPath row];
	if (s < 0 || s >= (NSInteger)[_sections count])
		return CGRectZero;
	UIKitTableSection *info = [_sections objectAtIndex:s];
	if (r < 0 || r >= info->rows)
		return CGRectZero;
	return CGRectMake(0, info->rowOffsets[r], [self bounds].size.width, info->rowOffsets[r + 1] - info->rowOffsets[r]);
}

/* The last row whose top is at or above y. */
static NSInteger UIKitRowAtOffset(UIKitTableSection *section, CGFloat y)
{
	NSInteger low = 0, high = section->rows - 1;
	while (low < high) {
		NSInteger mid = (low + high + 1) / 2;
		if (section->rowOffsets[mid] <= y)
			low = mid;
		else
			high = mid - 1;
	}
	return low;
}

- (NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point
{
	[self reloadIfNeeded];
	for (NSUInteger s = 0; s < [_sections count]; s++) {
		UIKitTableSection *info = [_sections objectAtIndex:s];
		if (info->rows == 0 || point.y < info->rowOffsets[0] || point.y >= info->rowOffsets[info->rows])
			continue;
		return [NSIndexPath indexPathForRow:UIKitRowAtOffset(info, point.y) inSection:s];
	}
	return nil;
}

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect
{
	[self reloadIfNeeded];
	NSMutableArray *paths = [NSMutableArray array];
	CGFloat top = CGRectGetMinY(rect), bottom = CGRectGetMaxY(rect);
	for (NSUInteger s = 0; s < [_sections count]; s++) {
		UIKitTableSection *info = [_sections objectAtIndex:s];
		if (info->rows == 0 || bottom <= info->rowOffsets[0] || top >= info->rowOffsets[info->rows])
			continue;
		NSInteger first = UIKitRowAtOffset(info, MAX(top, info->rowOffsets[0]));
		for (NSInteger r = first; r < info->rows && info->rowOffsets[r] < bottom; r++)
			[paths addObject:[NSIndexPath indexPathForRow:r inSection:s]];
	}
	return paths;
}

- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell
{
	for (NSIndexPath *path in _visibleCells)
		if ([_visibleCells objectForKey:path] == cell)
			return path;
	return nil;
}

- (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return indexPath != nil ? [_visibleCells objectForKey:[NSIndexPath indexPathForRow:[indexPath row] inSection:[indexPath section]]] : nil;
}

- (NSArray *)indexPathsForVisibleRows
{
	return [[_visibleCells allKeys] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)visibleCells
{
	NSMutableArray *cells = [NSMutableArray array];
	for (NSIndexPath *path in [self indexPathsForVisibleRows])
		[cells addObject:[_visibleCells objectForKey:path]];
	return cells;
}

#pragma mark Tiling

- (void)recycleCell:(UITableViewCell *)cell
{
	[cell removeFromSuperview];
	NSString *identifier = [cell reuseIdentifier];
	if (identifier == nil)
		return;
	NSMutableArray *queue = [_reusableCells objectForKey:identifier];
	if (queue == nil) {
		queue = [NSMutableArray array];
		[_reusableCells setObject:queue forKey:identifier];
	}
	if ([queue count] < 32)
		[queue addObject:cell];
}

- (UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier
{
	if (identifier == nil)
		return nil;
	NSMutableArray *queue = [_reusableCells objectForKey:identifier];
	UITableViewCell *cell = [queue lastObject];
	if (cell != nil) {
		[queue removeLastObject];
		[cell prepareForReuse];
		return cell;
	}
	Class cls = [_registeredClasses objectForKey:identifier];
	return cls != Nil ? [[cls alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier] : nil;
}

- (UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath
{
	return [self dequeueReusableCellWithIdentifier:identifier];
}

- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier
{
	if (identifier == nil)
		return;
	if (cellClass != Nil)
		[_registeredClasses setObject:cellClass forKey:identifier];
	else
		[_registeredClasses removeObjectForKey:identifier];
}

- (UIView *)headerViewForSection:(NSInteger)s footer:(BOOL)footer
{
	UIKitTableSection *info = [_sections objectAtIndex:s];
	CGFloat height = footer ? info->footerHeight : info->headerHeight;
	if (height <= 0)
		return nil;
	id<UITableViewDelegate> delegate = [self delegate];
	UIView *view = nil;
	SEL selector = footer ? @selector(tableView:viewForFooterInSection:) : @selector(tableView:viewForHeaderInSection:);
	if ([delegate respondsToSelector:selector])
		view = footer ? [delegate tableView:self viewForFooterInSection:s] : [delegate tableView:self viewForHeaderInSection:s];
	if (view == nil) {
		NSString *title = footer ? info->footerTitle : info->headerTitle;
		if (title == nil && _style == UITableViewStyleGrouped)
			return nil;
		UIKitTableSectionHeader *header = [[UIKitTableSectionHeader alloc] initWithFrame:CGRectZero];
		[header setTitle:title];
		[header setGrouped:_style == UITableViewStyleGrouped];
		[header setFooter:footer];
		view = header;
	}
	return view;
}

- (void)tile
{
	if (_tiling)
		return;
	_tiling = YES;
	NSRect bounds = [self bounds];
	CGFloat width = bounds.size.width;
	CGFloat top = bounds.origin.y, bottom = NSMaxY(bounds);

	NSMutableSet *wanted = [NSMutableSet setWithArray:[self indexPathsForRowsInRect:CGRectMake(0, top, width, bottom - top)]];
	for (NSIndexPath *path in [_visibleCells allKeys]) {
		if (![wanted containsObject:path]) {
			[self recycleCell:[_visibleCells objectForKey:path]];
			[_visibleCells removeObjectForKey:path];
		}
	}
	id<UITableViewDataSource> dataSource = _dataSource;
	id<UITableViewDelegate> delegate = [self delegate];
	BOOL canDelete = _editing && [dataSource respondsToSelector:@selector(tableView:commitEditingStyle:forRowAtIndexPath:)];
	for (NSIndexPath *path in [[wanted allObjects] sortedArrayUsingSelector:@selector(compare:)]) {
		CGRect rect = [self rectForRowAtIndexPath:path];
		UITableViewCell *cell = [_visibleCells objectForKey:path];
		if (cell == nil) {
			cell = [dataSource tableView:self cellForRowAtIndexPath:path];
			if (cell == nil)
				cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
			[cell setUikitTableView:self];
			[_visibleCells setObject:cell forKey:path];
			[cell setSelected:[_selectedRows containsObject:path] animated:NO];
			BOOL deletable = canDelete;
			if (deletable && [dataSource respondsToSelector:@selector(tableView:canEditRowAtIndexPath:)])
				deletable = [dataSource tableView:self canEditRowAtIndexPath:path];
			if (deletable && [delegate respondsToSelector:@selector(tableView:editingStyleForRowAtIndexPath:)])
				deletable = [delegate tableView:self editingStyleForRowAtIndexPath:path] == UITableViewCellEditingStyleDelete;
			[cell setEditing:_editing animated:NO];
			[cell setUikitShowsDeleteButton:deletable];
			if ([delegate respondsToSelector:@selector(tableView:indentationLevelForRowAtIndexPath:)])
				[cell setIndentationLevel:[delegate tableView:self indentationLevelForRowAtIndexPath:path]];
			[cell setFrame:NSMakeRect(0, rect.origin.y, width, rect.size.height)];
			[cell setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
			if ([delegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)])
				[delegate tableView:self willDisplayCell:cell forRowAtIndexPath:path];
			[self addSubview:cell];
			[cell layoutIfNeeded];
		} else {
			[cell setFrame:NSMakeRect(0, rect.origin.y, width, rect.size.height)];
		}
	}

	/* Headers and footers of the sections in view. */
	NSMutableSet *wantedHeaders = [NSMutableSet set];
	for (NSUInteger s = 0; s < [_sections count]; s++) {
		UIKitTableSection *info = [_sections objectAtIndex:s];
		CGFloat sectionBottom = info->rowOffsets[info->rows] + info->footerHeight;
		if (sectionBottom < top || info->top > bottom)
			continue;
		for (int footer = 0; footer < 2; footer++) {
			NSString *key = [NSString stringWithFormat:@"%lu%@", (unsigned long)s, footer ? @"f" : @"h"];
			CGFloat height = footer ? info->footerHeight : info->headerHeight;
			CGFloat y = footer ? info->rowOffsets[info->rows] : info->top;
			if (height <= 0)
				continue;
			UIView *view = [_headerViews objectForKey:key];
			if (view == nil) {
				view = [self headerViewForSection:s footer:footer];
				if (view == nil)
					continue;
				[_headerViews setObject:view forKey:key];
				[self addSubview:view];
			}
			/* Plain tables keep the current section's header pinned. */
			if (!footer && _style == UITableViewStylePlain && y < top)
				y = MIN(top, info->rowOffsets[info->rows] - height);
			[view setFrame:NSMakeRect(0, y, width, height)];
			if (!footer && _style == UITableViewStylePlain)
				[self addSubview:view positioned:NSWindowAbove relativeTo:nil];
			[wantedHeaders addObject:key];
		}
	}
	for (NSString *key in [_headerViews allKeys]) {
		if (![wantedHeaders containsObject:key]) {
			[[_headerViews objectForKey:key] removeFromSuperview];
			[_headerViews removeObjectForKey:key];
		}
	}

	if (_indexView != nil) {
		if ([_indexView superview] != self)
			[self addSubview:_indexView];
		[_indexView setFrame:NSMakeRect(width - 18, top, 18, bounds.size.height)];
		[self addSubview:_indexView positioned:NSWindowAbove relativeTo:nil];
	}
	_tiling = NO;
	[self setNeedsDisplay:YES];
}

- (void)uikitDidScroll
{
	[super uikitDidScroll];
	[self tile];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	if (_needsReload)
		[self reloadData];
	else
		[self tile];
}

- (void)setFrameSize:(NSSize)size
{
	CGFloat oldWidth = [self frame].size.width;
	[super setFrameSize:size];
	if (oldWidth != size.width)
		_needsReload = YES;
	[self setNeedsLayout];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	if ([self window] != nil)
		[self layoutIfNeeded];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	if (_separatorStyle == UITableViewCellSeparatorStyleNone)
		return;
	/* Separators under the rows in view, and below the last row in a
	 * plain table, the empty rows iOS shows. */
	[[_separatorColor nsColor] setFill];
	NSRect bounds = [self bounds];
	CGFloat inset = _separatorInset.left;
	for (UIKitTableSection *info in _sections) {
		if (info->rows == 0)
			continue;
		CGFloat first = info->rowOffsets[0], last = info->rowOffsets[info->rows];
		if (last < NSMinY(rect) || first > NSMaxY(rect))
			continue;
		NSInteger start = UIKitRowAtOffset(info, MAX(first, NSMinY(rect)));
		for (NSInteger r = start; r < info->rows && info->rowOffsets[r] <= NSMaxY(rect); r++) {
			CGFloat y = info->rowOffsets[r + 1] - 0.5;
			BOOL lastRow = r == info->rows - 1;
			CGFloat x = lastRow && _style == UITableViewStyleGrouped ? 0 : inset;
			NSRectFill(NSMakeRect(x, y, bounds.size.width - x, 0.5));
		}
		if (_style == UITableViewStyleGrouped)
			NSRectFill(NSMakeRect(0, first, bounds.size.width, 0.5));
	}
	if (_style == UITableViewStylePlain && [_sections count] > 0) {
		CGFloat y = [self contentSize].height - (_tableFooterView != nil ? [_tableFooterView frame].size.height : 0);
		if (_tableFooterView == nil)
			for (; y < NSMaxY(rect); y += _rowHeight)
				NSRectFill(NSMakeRect(inset, y + _rowHeight - 0.5, bounds.size.width - inset, 0.5));
	}
}

#pragma mark Selection

- (NSIndexPath *)indexPathForSelectedRow
{
	return [[[_selectedRows allObjects] sortedArrayUsingSelector:@selector(compare:)] firstObject];
}

- (NSArray *)indexPathsForSelectedRows
{
	return [_selectedRows count] > 0 ? [[_selectedRows allObjects] sortedArrayUsingSelector:@selector(compare:)] : nil;
}

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition
{
	[self reloadIfNeeded];
	if (!_allowsMultipleSelection)
		for (NSIndexPath *path in [_selectedRows allObjects])
			[self deselectRowAtIndexPath:path animated:NO];
	if (indexPath == nil)
		return;
	NSIndexPath *path = [NSIndexPath indexPathForRow:[indexPath row] inSection:[indexPath section]];
	[_selectedRows addObject:path];
	[[_visibleCells objectForKey:path] setSelected:YES animated:animated];
	if (scrollPosition != UITableViewScrollPositionNone)
		[self scrollToRowAtIndexPath:path atScrollPosition:scrollPosition animated:animated];
}

- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
	if (indexPath == nil)
		return;
	NSIndexPath *path = [NSIndexPath indexPathForRow:[indexPath row] inSection:[indexPath section]];
	[_selectedRows removeObject:path];
	[[_visibleCells objectForKey:path] setSelected:NO animated:animated];
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
	CGRect rect = [self rectForRowAtIndexPath:indexPath];
	if (CGRectIsEmpty(rect))
		return;
	CGFloat height = [self bounds].size.height;
	CGPoint offset = [self contentOffset];
	switch (scrollPosition) {
	case UITableViewScrollPositionTop: offset.y = rect.origin.y; break;
	case UITableViewScrollPositionMiddle: offset.y = CGRectGetMidY(rect) - height / 2; break;
	case UITableViewScrollPositionBottom: offset.y = CGRectGetMaxY(rect) - height; break;
	default: [self scrollRectToVisible:rect animated:animated]; return;
	}
	offset.y = MAX(0, MIN(offset.y, [self contentSize].height - height));
	[self setContentOffset:offset animated:animated];
}

- (void)scrollToNearestSelectedRowAtScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
	NSIndexPath *selected = [self indexPathForSelectedRow];
	if (selected != nil)
		[self scrollToRowAtIndexPath:selected atScrollPosition:scrollPosition animated:animated];
}

- (void)uikitTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGPoint point = [[touches anyObject] locationInView:self];
	NSIndexPath *path = [self indexPathForRowAtPoint:point];
	_pressedRow = path;
	if (path == nil || (!_allowsSelection && !_editing) || (_editing && !_allowsSelectionDuringEditing))
		return;
	id<UITableViewDelegate> delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(tableView:shouldHighlightRowAtIndexPath:)] &&
	    ![delegate tableView:self shouldHighlightRowAtIndexPath:path])
		return;
	[[_visibleCells objectForKey:path] setHighlighted:YES animated:NO];
}

- (void)uikitTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (_pressedRow != nil)
		[[_visibleCells objectForKey:_pressedRow] setHighlighted:NO animated:NO];
	_pressedRow = nil;
}

- (void)uikitTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSIndexPath *path = _pressedRow;
	_pressedRow = nil;
	if (path == nil)
		return;
	UITableViewCell *cell = [_visibleCells objectForKey:path];
	[cell setHighlighted:NO animated:NO];
	id<UITableViewDelegate> delegate = [self delegate];
	id<UITableViewDataSource> dataSource = _dataSource;

	CGPoint point = [[touches anyObject] locationInView:cell];
	if ([cell editingStyle] == UITableViewCellEditingStyleDelete && point.x >= [cell bounds].size.width - UIKitDeleteButtonWidth) {
		[dataSource tableView:self commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:path];
		return;
	}
	if ([cell accessoryType] == UITableViewCellAccessoryDetailDisclosureButton && point.x >= [cell bounds].size.width - 44 &&
	    [delegate respondsToSelector:@selector(tableView:accessoryButtonTappedForRowWithIndexPath:)]) {
		[delegate tableView:self accessoryButtonTappedForRowWithIndexPath:path];
		return;
	}
	if ((!_allowsSelection && !_editing) || (_editing && !_allowsSelectionDuringEditing))
		return;
	if ([delegate respondsToSelector:@selector(tableView:willSelectRowAtIndexPath:)]) {
		path = [delegate tableView:self willSelectRowAtIndexPath:path];
		if (path == nil)
			return;
	}
	NSIndexPath *previous = [self indexPathForSelectedRow];
	if (previous != nil && ![previous isEqual:path] && !_allowsMultipleSelection) {
		[self deselectRowAtIndexPath:previous animated:NO];
		if ([delegate respondsToSelector:@selector(tableView:didDeselectRowAtIndexPath:)])
			[delegate tableView:self didDeselectRowAtIndexPath:previous];
	}
	[self selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
	if ([delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
		[delegate tableView:self didSelectRowAtIndexPath:path];
}

#pragma mark Editing and updates

- (BOOL)isEditing { return _editing; }
- (void)setEditing:(BOOL)editing { [self setEditing:editing animated:NO]; }

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	if (_editing == editing)
		return;
	_editing = editing;
	CGPoint offset = [self contentOffset];
	[self reloadData];
	[self setContentOffset:[self clampedOffset:offset]];
}

- (CGPoint)clampedOffset:(CGPoint)offset
{
	CGFloat maxY = MAX(0, [self contentSize].height - [self bounds].size.height);
	offset.y = MAX(0, MIN(offset.y, maxY));
	offset.x = 0;
	return offset;
}

/* Changes are not animated: the table reloads when they are done. */
- (void)reloadAfterUpdate
{
	if (_updateDepth > 0)
		return;
	CGPoint offset = [self contentOffset];
	NSArray *selected = [self indexPathsForSelectedRows];
	[self reloadData];
	[self setContentOffset:[self clampedOffset:offset]];
	for (NSIndexPath *path in selected)
		if ([path section] < (NSInteger)[_sections count] && [path row] < ((UIKitTableSection *)[_sections objectAtIndex:[path section]])->rows)
			[self selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)beginUpdates
{
	_updateDepth++;
}

- (void)endUpdates
{
	if (_updateDepth > 0)
		_updateDepth--;
	[self reloadAfterUpdate];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation { [self reloadAfterUpdate]; }
- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation { [self reloadAfterUpdate]; }
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation { [self reloadAfterUpdate]; }
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation { [self reloadAfterUpdate]; }
- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation { [self reloadAfterUpdate]; }
- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation { [self reloadAfterUpdate]; }

@end
