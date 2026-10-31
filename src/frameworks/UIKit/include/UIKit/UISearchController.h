/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISEARCHCONTROLLER_H
#define UIKIT_UISEARCHCONTROLLER_H

#import <UIKit/UIViewController.h>
#import <UIKit/UITextField.h>
#import <UIKit/UINavigationController.h>

@class UISearchController;

@protocol UISearchResultsUpdating <NSObject>
@required
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController;
@end

@protocol UISearchControllerDelegate <NSObject>
@optional
- (void)willPresentSearchController:(UISearchController *)searchController;
- (void)didPresentSearchController:(UISearchController *)searchController;
- (void)willDismissSearchController:(UISearchController *)searchController;
- (void)didDismissSearchController:(UISearchController *)searchController;
- (void)presentSearchController:(UISearchController *)searchController;
@end

/*
 * iOS 8's search: its bar goes where the app puts it, or under the
 * navigation bar of the controller whose navigationItem has it. Editing
 * the bar makes it active; while it is, the results controller's view
 * covers the window below the bar, and the updater hears of each change
 * to the text. Cancel ends it. The background is never dimmed.
 */
@interface UISearchController : UIViewController
- (instancetype)initWithSearchResultsController:(UIViewController *)searchResultsController;
@property (nonatomic, weak) id<UISearchResultsUpdating> searchResultsUpdater;
@property (nonatomic, getter=isActive) BOOL active;
@property (nonatomic, weak) id<UISearchControllerDelegate> delegate;
@property (nonatomic) BOOL dimsBackgroundDuringPresentation;
@property (nonatomic) BOOL obscuresBackgroundDuringPresentation;
@property (nonatomic) BOOL hidesNavigationBarDuringPresentation;
@property (nonatomic) BOOL automaticallyShowsCancelButton;
@property (nonatomic) BOOL automaticallyShowsSearchResultsController;
@property (nonatomic) BOOL showsSearchResultsController;
@property (nonatomic, readonly, strong) UIViewController *searchResultsController;
@property (nonatomic, readonly, strong) UISearchBar *searchBar;
@end

@interface UINavigationItem (UISearchController)
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic) BOOL hidesSearchBarWhenScrolling;
@end

#endif /* UIKIT_UISEARCHCONTROLLER_H */
