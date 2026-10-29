/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UITableViewController.h>
#import <UIKit/UILabel.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIScreen.h>
#import "UIKitPrivate.h"
#import <objc/runtime.h>

@implementation UIRefreshControl {
	BOOL _refreshing;
}

@synthesize attributedTitle = _attributedTitle;

- (instancetype)init
{
	return [self initWithFrame:CGRectMake(0, 0, 320, 60)];
}

- (BOOL)isRefreshing { return _refreshing; }
- (void)beginRefreshing { _refreshing = YES; }
- (void)endRefreshing { _refreshing = NO; }

@end

@implementation UITableViewController {
	UITableView *_tableView;
	UITableViewStyle _style;
	UIRefreshControl *_refreshControl;
	BOOL _clearsSelectionOnViewWillAppear;
	BOOL _reloadedOnce;
}

@synthesize clearsSelectionOnViewWillAppear = _clearsSelectionOnViewWillAppear;

- (instancetype)initWithStyle:(UITableViewStyle)style
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		_style = style;
		_clearsSelectionOnViewWillAppear = YES;
	}
	return self;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
	if ((self = [super initWithNibName:nibName bundle:bundle]))
		_clearsSelectionOnViewWillAppear = YES;
	return self;
}

- (void)loadView
{
	if (_tableView == nil && [self uikitLoadViewFromNib])
		return;
	if (_tableView == nil) {
		UITableView *tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:_style];
		[tableView setDataSource:self];
		[tableView setDelegate:self];
		_tableView = tableView;
	}
	[_tableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[super setView:_tableView];
}

- (void)setView:(UIView *)view
{
	[super setView:view];
	if ([view isKindOfClass:[UITableView class]])
		_tableView = (UITableView *)view;
}

- (UITableView *)tableView
{
	[self view];
	return _tableView;
}

- (void)setTableView:(UITableView *)tableView
{
	_tableView = tableView;
	[super setView:tableView];
}

- (UIRefreshControl *)refreshControl { return _refreshControl; }
- (void)setRefreshControl:(UIRefreshControl *)control { _refreshControl = control; }

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	if (!_reloadedOnce) {
		_reloadedOnce = YES;
		[_tableView reloadData];
	}
	if (_clearsSelectionOnViewWillAppear)
		for (NSIndexPath *path in [_tableView indexPathsForSelectedRows])
			[_tableView deselectRowAtIndexPath:path animated:animated];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	[super setEditing:editing animated:animated];
	[_tableView setEditing:editing animated:animated];
}

/* Subclasses provide the rows; these keep one that does not from crashing. */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

@end

#pragma mark - UITableViewHeaderFooterView

@implementation UITableViewHeaderFooterView {
	NSString *_reuseIdentifier;
	UIView *_contentView;
	UILabel *_textLabel;
	UILabel *_detailTextLabel;
	UIView *_backgroundView;
}

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
	if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 28)]) == nil)
		return nil;
	_reuseIdentifier = [reuseIdentifier copy];
	_contentView = [[UIView alloc] initWithFrame:[self bounds]];
	[_contentView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[self addSubview:_contentView];
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [self initWithReuseIdentifier:nil]))
		[self setFrame:frame];
	return self;
}

- (NSString *)reuseIdentifier { return _reuseIdentifier; }
- (UIView *)contentView { return _contentView; }

- (UILabel *)textLabel
{
	if (_textLabel == nil) {
		_textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_textLabel setFont:[UIFont systemFontOfSize:13]];
		[_textLabel setTextColor:[UIColor colorWithWhite:0.43 alpha:1]];
		[_textLabel setBackgroundColor:nil];
		[_contentView addSubview:_textLabel];
		[self setNeedsLayout];
	}
	return _textLabel;
}

- (UILabel *)detailTextLabel
{
	if (_detailTextLabel == nil) {
		_detailTextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_detailTextLabel setFont:[UIFont systemFontOfSize:12]];
		[_detailTextLabel setTextColor:[UIColor colorWithWhite:0.43 alpha:1]];
		[_detailTextLabel setBackgroundColor:nil];
		[_contentView addSubview:_detailTextLabel];
		[self setNeedsLayout];
	}
	return _detailTextLabel;
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

- (void)layoutSubviews
{
	[super layoutSubviews];
	NSRect bounds = [_contentView bounds];
	CGFloat textWidth = bounds.size.width - 30;
	if (_detailTextLabel != nil) {
		CGFloat detailWidth = MIN(textWidth / 2, [_detailTextLabel sizeThatFits:CGSizeMake(textWidth, bounds.size.height)].width);
		[_detailTextLabel setFrame:NSMakeRect(bounds.size.width - 15 - detailWidth, 0, detailWidth, bounds.size.height)];
		textWidth -= detailWidth + 8;
	}
	[_textLabel setFrame:NSMakeRect(15, 0, MAX(0, textWidth), bounds.size.height)];
}

- (void)prepareForReuse { }

@end

#pragma mark - Header and footer views in tables

static char UIKitHeaderFooterClassesKey;

@implementation UITableView (UITableViewHeaderFooterView)

- (NSMutableDictionary *)uikitHeaderFooterClasses
{
	NSMutableDictionary *classes = objc_getAssociatedObject(self, &UIKitHeaderFooterClassesKey);
	if (classes == nil) {
		classes = [NSMutableDictionary dictionary];
		objc_setAssociatedObject(self, &UIKitHeaderFooterClassesKey, classes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return classes;
}

- (void)registerClass:(Class)viewClass forHeaderFooterViewReuseIdentifier:(NSString *)identifier
{
	if (identifier == nil)
		return;
	if (viewClass == Nil)
		[[self uikitHeaderFooterClasses] removeObjectForKey:identifier];
	else
		[[self uikitHeaderFooterClasses] setObject:viewClass forKey:identifier];
}

- (void)registerNib:(UINib *)nib forHeaderFooterViewReuseIdentifier:(NSString *)identifier
{
	if (identifier == nil)
		return;
	if (nib == nil)
		[[self uikitHeaderFooterClasses] removeObjectForKey:identifier];
	else
		[[self uikitHeaderFooterClasses] setObject:nib forKey:identifier];
}

/* Header views leave the table when it reloads, so each is a new one. */
- (UITableViewHeaderFooterView *)dequeueReusableHeaderFooterViewWithIdentifier:(NSString *)identifier
{
	id viewClass = identifier != nil ? [[self uikitHeaderFooterClasses] objectForKey:identifier] : nil;
	if ([viewClass isKindOfClass:[UINib class]]) {
		for (id object in [(UINib *)viewClass instantiateWithOwner:nil options:nil]) {
			if ([object isKindOfClass:[UIView class]])
				return object;
		}
		return nil;
	}
	if (viewClass == nil)
		return nil;
	return [[viewClass alloc] initWithReuseIdentifier:identifier];
}

- (UITableViewHeaderFooterView *)headerViewForSection:(NSInteger)section { return nil; }
- (UITableViewHeaderFooterView *)footerViewForSection:(NSInteger)section { return nil; }

@end
