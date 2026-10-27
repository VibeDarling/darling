/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIViewController.h>
#import <UIKit/UIView.h>
#import <UIKit/UIScreen.h>

@implementation UIViewController

- (UIView *)view
{
	if (_view == nil) {
		[self loadView];
		if (_view == nil)
			_view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
		[self viewDidLoad];
	}
	return _view;
}

/* As on iOS, the default view is screen-sized before -viewDidLoad runs, so
 * subviews built there from its bounds start at their final size. */
- (void)loadView
{
	_view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
}

- (void)viewDidLoad
{
}

- (void)viewWillAppear
{
}

- (void)viewDidAppear
{
}

- (NSString *)title
{
	return _title;
}

- (void)setTitle:(NSString *)title
{
	_title = [title copy];
}

@end
