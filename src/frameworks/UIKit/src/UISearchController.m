/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UISearchController.h>
#import <UIKit/UIWindow.h>
#import <objc/runtime.h>
#import "UIKitPrivate.h"

@implementation UISearchController {
	UIViewController *_resultsController;
	UISearchBar *_searchBar;
	BOOL _active;
}

@synthesize searchResultsUpdater = _searchResultsUpdater;
@synthesize delegate = _delegate;
@synthesize dimsBackgroundDuringPresentation = _dimsBackgroundDuringPresentation;
@synthesize hidesNavigationBarDuringPresentation = _hidesNavigationBarDuringPresentation;
@synthesize automaticallyShowsCancelButton = _automaticallyShowsCancelButton;
@synthesize automaticallyShowsSearchResultsController = _automaticallyShowsSearchResultsController;
@synthesize showsSearchResultsController = _showsSearchResultsController;

- (instancetype)initWithSearchResultsController:(UIViewController *)searchResultsController
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		_resultsController = searchResultsController;
		_searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 56)];
		[_searchBar setUikitSearchController:self];
		_dimsBackgroundDuringPresentation = YES;
		_hidesNavigationBarDuringPresentation = YES;
		_automaticallyShowsCancelButton = YES;
		_automaticallyShowsSearchResultsController = YES;
	}
	return self;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
	return [self initWithSearchResultsController:nil];
}

- (UIViewController *)searchResultsController { return _resultsController; }
- (UISearchBar *)searchBar { return _searchBar; }
- (BOOL)obscuresBackgroundDuringPresentation { return _dimsBackgroundDuringPresentation; }
- (void)setObscuresBackgroundDuringPresentation:(BOOL)obscures { _dimsBackgroundDuringPresentation = obscures; }
- (BOOL)isActive { return _active; }

- (void)setActive:(BOOL)active
{
	if (active == _active)
		return;
	id<UISearchControllerDelegate> delegate = _delegate;
	if (active) {
		if ([delegate respondsToSelector:@selector(willPresentSearchController:)])
			[delegate willPresentSearchController:self];
		_active = YES;
		if (_automaticallyShowsCancelButton)
			[_searchBar setShowsCancelButton:YES animated:YES];
		if (_automaticallyShowsSearchResultsController)
			_showsSearchResultsController = YES;
		[self uikitPlaceResults];
		[self uikitUpdateResults];
		if ([delegate respondsToSelector:@selector(didPresentSearchController:)])
			[delegate didPresentSearchController:self];
	} else {
		if ([delegate respondsToSelector:@selector(willDismissSearchController:)])
			[delegate willDismissSearchController:self];
		_active = NO;
		if (_automaticallyShowsCancelButton)
			[_searchBar setShowsCancelButton:NO animated:YES];
		[_searchBar resignFirstResponder];
		[self uikitPlaceResults];
		[self uikitUpdateResults];
		if ([delegate respondsToSelector:@selector(didDismissSearchController:)])
			[delegate didDismissSearchController:self];
	}
}

- (void)setShowsSearchResultsController:(BOOL)shows
{
	_showsSearchResultsController = shows;
	[self uikitPlaceResults];
}

/* The results cover the bar's window from the bar down, while active. */
- (void)uikitPlaceResults
{
	if (_resultsController == nil)
		return;
	UIView *results = [_resultsController view];
	UIView *host = (UIView *)[[_searchBar window] contentView];
	BOOL show = _active && _showsSearchResultsController && [host isKindOfClass:[UIView class]];
	if (!show) {
		if ([results superview] != nil) {
			[_resultsController uikitDisappear:NO];
			[results removeFromSuperview];
		}
		return;
	}
	NSRect bar = [host convertRect:[_searchBar bounds] fromView:_searchBar];
	NSRect bounds = [host bounds];
	CGFloat top = NSMaxY(bar);
	[results setFrame:NSMakeRect(0, top, bounds.size.width, MAX(0, bounds.size.height - top))];
	[results setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	if ([results superview] != host) {
		[host addSubview:results];
		[_resultsController uikitAppear:NO];
	}
}

- (void)uikitUpdateResults
{
	[_searchResultsUpdater updateSearchResultsForSearchController:self];
}

- (void)uikitSearchBarDidBeginEditing
{
	if (!_active)
		[self setActive:YES];
}

- (void)uikitSearchBarTextDidChange
{
	if (_active)
		[self uikitUpdateResults];
}

- (void)uikitSearchBarCancelled
{
	[_searchBar setText:@""];
	[self setActive:NO];
}

@end

static char UIKitSearchControllerKey, UIKitHidesSearchBarKey;

@implementation UINavigationItem (UISearchController)

- (UISearchController *)searchController
{
	return objc_getAssociatedObject(self, &UIKitSearchControllerKey);
}

- (void)setSearchController:(UISearchController *)searchController
{
	objc_setAssociatedObject(self, &UIKitSearchControllerKey, searchController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[[NSNotificationCenter defaultCenter] postNotificationName:UIKitBarItemDidChangeNotification object:self];
}

- (BOOL)hidesSearchBarWhenScrolling
{
	NSNumber *hides = objc_getAssociatedObject(self, &UIKitHidesSearchBarKey);
	return hides != nil ? [hides boolValue] : YES;
}

- (void)setHidesSearchBarWhenScrolling:(BOOL)hides
{
	objc_setAssociatedObject(self, &UIKitHidesSearchBarKey, @(hides), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
