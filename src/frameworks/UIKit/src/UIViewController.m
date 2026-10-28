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
#import <UIKit/UIWindow.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UITabBarController.h>
#import <UIKit/UIBarButtonItem.h>
#import "UIKitPrivate.h"

@implementation UIViewController {
	UINavigationItem *_navigationItem;
	UITabBarItem *_tabBarItem;
	__weak UIViewController *_parent;
	NSMutableArray<UIViewController *> *_children;
	UIViewController *_presented;
	__weak UIViewController *_presenting;
	UIBarButtonItem *_editButtonItem;
	BOOL _editing;
	BOOL _appeared;
	NSArray<NSView *> *_coveredViews;
}

@synthesize modalPresentationStyle = _modalPresentationStyle;
@synthesize modalTransitionStyle = _modalTransitionStyle;
@synthesize hidesBottomBarWhenPushed = _hidesBottomBarWhenPushed;
@synthesize wantsFullScreenLayout = _wantsFullScreenLayout;
@synthesize automaticallyAdjustsScrollViewInsets = _automaticallyAdjustsScrollViewInsets;
@synthesize edgesForExtendedLayout = _edgesForExtendedLayout;
@synthesize contentSizeForViewInPopover = _contentSizeForViewInPopover;
@synthesize preferredContentSize = _preferredContentSize;
@synthesize toolbarItems = _toolbarItems;

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
	return [self init];
}

- (UIView *)view
{
	if (_view == nil) {
		[self loadView];
		if (_view == nil)
			_view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
		[self viewDidLoad];
	}
	return _view;
}

- (void)setView:(UIView *)view
{
	if (view == _view)
		return;
	if (view == nil && _view != nil)
		[self viewDidUnload];
	_view = view;
}

- (BOOL)isViewLoaded
{
	return _view != nil;
}

- (void)loadView
{
	_view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	[_view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
}

- (void)unloadView
{
}

- (void)viewDidLoad { }
- (void)viewDidUnload { }
- (void)viewWillAppear { }
- (void)viewDidAppear { }

- (void)viewWillAppear:(BOOL)animated
{
	[self viewWillAppear];
}

- (void)viewDidAppear:(BOOL)animated
{
	[self viewDidAppear];
}

- (void)viewWillDisappear:(BOOL)animated { }
- (void)viewDidDisappear:(BOOL)animated { }
- (void)viewWillLayoutSubviews { }
- (void)viewDidLayoutSubviews { }
- (void)didReceiveMemoryWarning { }

- (NSString *)title
{
	return _title;
}

- (void)setTitle:(NSString *)title
{
	_title = [title copy];
	[_navigationItem setTitle:_title];
	if (_tabBarItem != nil && [_tabBarItem title] == nil)
		[_tabBarItem setTitle:_title];
}

#pragma mark Containment

- (UINavigationItem *)navigationItem
{
	if (_navigationItem == nil)
		_navigationItem = [[UINavigationItem alloc] initWithTitle:_title];
	return _navigationItem;
}

- (UITabBarItem *)tabBarItem
{
	if (_tabBarItem == nil)
		_tabBarItem = [[UITabBarItem alloc] initWithTitle:_title image:nil tag:0];
	return _tabBarItem;
}

- (void)setTabBarItem:(UITabBarItem *)item
{
	_tabBarItem = item;
	[[self tabBarController] uikitTabBarItemsChanged];
}

- (UIViewController *)parentViewController
{
	return _parent;
}

- (void)uikitSetParent:(UIViewController *)parent
{
	_parent = parent;
}

- (UINavigationController *)navigationController
{
	for (UIViewController *c = _parent; c != nil; c = [c parentViewController])
		if ([c isKindOfClass:[UINavigationController class]])
			return (UINavigationController *)c;
	return [_presenting navigationController];
}

- (UITabBarController *)tabBarController
{
	for (UIViewController *c = _parent; c != nil; c = [c parentViewController])
		if ([c isKindOfClass:[UITabBarController class]])
			return (UITabBarController *)c;
	return nil;
}

- (NSArray *)childViewControllers
{
	return [_children copy] ?: @[];
}

- (void)addChildViewController:(UIViewController *)child
{
	if (child == nil || [child parentViewController] == self)
		return;
	[child removeFromParentViewController];
	if (_children == nil)
		_children = [NSMutableArray array];
	[child willMoveToParentViewController:self];
	[_children addObject:child];
	[child uikitSetParent:self];
}

- (void)removeFromParentViewController
{
	UIViewController *parent = _parent;
	if (parent == nil)
		return;
	[parent->_children removeObject:self];
	_parent = nil;
	[self didMoveToParentViewController:nil];
}

- (void)willMoveToParentViewController:(UIViewController *)parent { }
- (void)didMoveToParentViewController:(UIViewController *)parent { }

#pragma mark Appearance

- (void)uikitAppear:(BOOL)animated
{
	if (_appeared)
		return;
	_appeared = YES;
	[self viewWillAppear:animated];
	[self viewDidAppear:animated];
}

- (void)uikitDisappear:(BOOL)animated
{
	if (!_appeared)
		return;
	_appeared = NO;
	[self viewWillDisappear:animated];
	[self viewDidDisappear:animated];
}

#pragma mark Presentation

- (UIViewController *)presentedViewController { return _presented; }
- (UIViewController *)presentingViewController { return _presenting; }
- (UIViewController *)modalViewController { return _presented; }

- (UIView *)uikitPresentationContainer
{
	UIView *view = [self view];
	NSView *content = [[view window] contentView];
	if ([content isKindOfClass:[UIView class]])
		return (UIView *)content;
	return view;
}

- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion
{
	if (controller == nil)
		return;
	if (_presented != nil) {
		[_presented presentViewController:controller animated:animated completion:completion];
		return;
	}
	_presented = controller;
	controller->_presenting = self;
	UIView *container = [self uikitPresentationContainer];
	UIView *view = [controller view];
	[view setFrame:[container bounds]];
	[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	/* Full-screen presentation takes what it covers off screen, as iOS does. */
	if (_modalPresentationStyle == UIModalPresentationFullScreen || _modalPresentationStyle == UIModalPresentationCurrentContext) {
		NSMutableArray *covered = [NSMutableArray array];
		for (NSView *subview in [container subviews])
			if (![subview isHidden]) {
				[covered addObject:subview];
				[subview setHidden:YES];
			}
		_coveredViews = covered;
	}
	[container addSubview:view];
	[controller uikitAppear:animated];
	if (completion != nil)
		dispatch_async(dispatch_get_main_queue(), completion);
}

- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion
{
	UIViewController *presented = _presented;
	if (presented == nil) {
		[_presenting dismissViewControllerAnimated:animated completion:completion];
		return;
	}
	if (presented->_presented != nil)
		[presented dismissViewControllerAnimated:NO completion:nil];
	[presented uikitDisappear:animated];
	[[presented view] removeFromSuperview];
	for (NSView *covered in _coveredViews)
		[covered setHidden:NO];
	_coveredViews = nil;
	presented->_presenting = nil;
	_presented = nil;
	if (completion != nil)
		dispatch_async(dispatch_get_main_queue(), completion);
}

- (void)presentModalViewController:(UIViewController *)controller animated:(BOOL)animated
{
	[self presentViewController:controller animated:animated completion:nil];
}

- (void)dismissModalViewControllerAnimated:(BOOL)animated
{
	[self dismissViewControllerAnimated:animated completion:nil];
}

#pragma mark Editing

- (BOOL)isEditing
{
	return _editing;
}

- (void)setEditing:(BOOL)editing
{
	[self setEditing:editing animated:NO];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	_editing = editing;
	[_editButtonItem setTitle:editing ? @"Done" : @"Edit"];
	[_editButtonItem setStyle:editing ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered];
}

- (void)uikitToggleEditing:(id)sender
{
	[self setEditing:!_editing animated:YES];
}

- (UIBarButtonItem *)editButtonItem
{
	if (_editButtonItem == nil)
		_editButtonItem = [[UIBarButtonItem alloc] initWithTitle:_editing ? @"Done" : @"Edit"
		                                                   style:UIBarButtonItemStyleBordered
		                                                  target:self
		                                                  action:@selector(uikitToggleEditing:)];
	return _editButtonItem;
}

- (void)setToolbarItems:(NSArray *)items animated:(BOOL)animated
{
	_toolbarItems = [items copy];
}

#pragma mark Orientation

- (UIInterfaceOrientation)interfaceOrientation
{
	return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
	return orientation == UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate
{
	return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
	return 1 << UIInterfaceOrientationPortrait;
}

- (void)_updateLayoutForStatusBarAndInterfaceOrientation
{
}

@end
