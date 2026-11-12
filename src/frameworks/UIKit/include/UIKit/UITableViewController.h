/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UITABLEVIEWCONTROLLER_H
#define UIKIT_UITABLEVIEWCONTROLLER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UITableView.h>
#import <UIKit/UIControl.h>

@class UINib;

/* Pull to refresh. Darling's tables do not pull, so it only keeps state. */
@interface UIRefreshControl : UIControl
@property (nonatomic, readonly, getter=isRefreshing) BOOL refreshing;
@property (nonatomic, strong) NSAttributedString *attributedTitle;
- (void)beginRefreshing;
- (void)endRefreshing;
@end

@interface UITableViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
- (instancetype)initWithStyle:(UITableViewStyle)style;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic) BOOL clearsSelectionOnViewWillAppear;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@end

@interface UITableViewHeaderFooterView : UIView
- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, readonly) UILabel *textLabel;
@property (nonatomic, readonly) UILabel *detailTextLabel;
@property (nonatomic, strong) UIView *backgroundView;
- (void)prepareForReuse;
@end

@interface UITableView (UITableViewHeaderFooterView)
- (void)registerClass:(Class)viewClass forHeaderFooterViewReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forHeaderFooterViewReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forCellReuseIdentifier:(NSString *)identifier;
- (UITableViewHeaderFooterView *)dequeueReusableHeaderFooterViewWithIdentifier:(NSString *)identifier;
- (UITableViewHeaderFooterView *)headerViewForSection:(NSInteger)section;
- (UITableViewHeaderFooterView *)footerViewForSection:(NSInteger)section;
@end

#endif /* UIKIT_UITABLEVIEWCONTROLLER_H */
