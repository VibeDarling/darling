/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIStoryboardSegue.h>
#import <UIKit/UIViewControllerTransitioning.h>
#import <UIKit/UISplitViewController.h>
#import <UIKit/UIPageViewController.h>
#import <UIKit/UIPopoverController.h>
#import <UIKit/UIGestureRecognizer.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIScreen.h>
#import "UIKitPrivate.h"
#include <float.h>

/* The controller a new presentation goes on top of. */
static UIViewController *UIKitTopPresenter(void)
{
	UIViewController *controller = [[UIWindow uikitKeyWindow] rootViewController];
	while ([controller presentedViewController] != nil)
		controller = [controller presentedViewController];
	return controller;
}

/* Makes child's view fill parent's, as its only content. */
static void UIKitShowChild(UIViewController *parent, UIViewController *old, UIViewController *child)
{
	if (old == child)
		return;
	BOOL visible = [parent isViewLoaded] && [[parent view] window] != nil;
	if (old != nil) {
		if (visible)
			[old uikitDisappear:NO];
		if ([old isViewLoaded])
			[[old view] removeFromSuperview];
		[old willMoveToParentViewController:nil];
		[old removeFromParentViewController];
	}
	if (child == nil)
		return;
	[parent addChildViewController:child];
	if ([parent isViewLoaded]) {
		UIView *view = [child view];
		[view setFrame:[[parent view] bounds]];
		[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[[parent view] addSubview:view];
		UIWindow *window = [[parent view] uiWindow];
		if (window != nil)
			[view attachToWindow:window];
		if (visible)
			[child uikitAppear:NO];
	}
	[child didMoveToParentViewController:parent];
}

#pragma mark - UIStoryboardSegue

@implementation UIStoryboardSegue {
	NSString *_identifier;
	UIViewController *_source;
	UIViewController *_destination;
	void (^_performHandler)(void);
}

+ (instancetype)segueWithIdentifier:(NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination performHandler:(void (^)(void))performHandler
{
	UIStoryboardSegue *segue = [[self alloc] initWithIdentifier:identifier source:source destination:destination];
	segue->_performHandler = [performHandler copy];
	return segue;
}

- (instancetype)initWithIdentifier:(NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination
{
	if ((self = [super init])) {
		_identifier = [identifier copy];
		_source = source;
		_destination = destination;
	}
	return self;
}

- (NSString *)identifier { return _identifier; }
- (UIViewController *)sourceViewController { return _source; }
- (UIViewController *)destinationViewController { return _destination; }

- (void)perform
{
	if (_performHandler != nil)
		_performHandler();
}

@end

@implementation UIViewController (UIStoryboardSegue)

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender { return YES; }
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender { }

- (void)showViewController:(UIViewController *)controller sender:(id)sender
{
	UINavigationController *navigationController = [self isKindOfClass:[UINavigationController class]] ? (UINavigationController *)self : [self navigationController];
	if (navigationController != nil)
		[navigationController pushViewController:controller animated:YES];
	else
		[self presentViewController:controller animated:YES completion:nil];
}

- (void)showDetailViewController:(UIViewController *)controller sender:(id)sender
{
	UISplitViewController *split = [self splitViewController];
	if (split != nil && split != self)
		[split showDetailViewController:controller sender:sender];
	else
		[self presentViewController:controller animated:YES completion:nil];
}

@end

#pragma mark - UIPercentDrivenInteractiveTransition

@implementation UIPercentDrivenInteractiveTransition {
	id<UIViewControllerContextTransitioning> _context;
	CGFloat _percentComplete;
}

@synthesize completionSpeed = _completionSpeed;
@synthesize completionCurve = _completionCurve;
@synthesize wantsInteractiveStart = _wantsInteractiveStart;

- (instancetype)init
{
	if ((self = [super init])) {
		_completionSpeed = 1;
		_wantsInteractiveStart = YES;
	}
	return self;
}

- (CGFloat)duration { return 0; }
- (CGFloat)percentComplete { return _percentComplete; }

- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)context
{
	_context = context;
}

- (void)pauseInteractiveTransition { }

- (void)updateInteractiveTransition:(CGFloat)percentComplete
{
	_percentComplete = MIN(MAX(percentComplete, 0), 1);
	[_context updateInteractiveTransition:_percentComplete];
}

- (void)cancelInteractiveTransition
{
	[_context cancelInteractiveTransition];
	_context = nil;
}

- (void)finishInteractiveTransition
{
	_percentComplete = 1;
	[_context finishInteractiveTransition];
	_context = nil;
}

@end

#pragma mark - UISplitViewController

CGFloat const UISplitViewControllerAutomaticDimension = -FLT_MAX;

@implementation UISplitViewController {
	NSArray<UIViewController *> *_viewControllers;
	UIViewController *_shown;
	UIBarButtonItem *_displayModeButtonItem;
}

@synthesize delegate = _delegate;
@synthesize presentsWithGesture = _presentsWithGesture;
@synthesize preferredDisplayMode = _preferredDisplayMode;
@synthesize preferredPrimaryColumnWidthFraction = _preferredPrimaryColumnWidthFraction;
@synthesize minimumPrimaryColumnWidth = _minimumPrimaryColumnWidth;
@synthesize maximumPrimaryColumnWidth = _maximumPrimaryColumnWidth;

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
	if ((self = [super initWithNibName:nibName bundle:bundle])) {
		_viewControllers = @[];
		_presentsWithGesture = YES;
		_preferredPrimaryColumnWidthFraction = UISplitViewControllerAutomaticDimension;
		_minimumPrimaryColumnWidth = UISplitViewControllerAutomaticDimension;
		_maximumPrimaryColumnWidth = UISplitViewControllerAutomaticDimension;
	}
	return self;
}

- (void)loadView
{
	UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[view setBackgroundColor:[UIColor whiteColor]];
	[self setView:view];
	[self uikitShowPrimary];
}

- (NSArray *)viewControllers { return _viewControllers; }

- (void)setViewControllers:(NSArray *)viewControllers
{
	NSArray *old = _viewControllers;
	_viewControllers = [viewControllers copy] ?: @[];
	/* They are its children whether or not its view is loaded. */
	for (UIViewController *controller in old)
		if (![_viewControllers containsObject:controller] && controller != _shown)
			[controller removeFromParentViewController];
	for (UIViewController *controller in _viewControllers)
		[self addChildViewController:controller];
	UIViewController *primary = [_viewControllers firstObject];
	UIViewController *secondary = [_viewControllers count] > 1 ? [_viewControllers objectAtIndex:1] : nil;
	/* Collapsing: the delegate may take the secondary; otherwise the
	 * primary is asked to fold it in. */
	if (secondary != nil && primary != nil) {
		BOOL handled = [_delegate respondsToSelector:@selector(splitViewController:collapseSecondaryViewController:ontoPrimaryViewController:)]
			&& [_delegate splitViewController:self collapseSecondaryViewController:secondary ontoPrimaryViewController:primary];
		if (!handled)
			[primary collapseSecondaryViewController:secondary forSplitViewController:self];
	}
	[self uikitShowPrimary];
}

- (void)uikitShowPrimary
{
	UIViewController *primary = [_viewControllers firstObject];
	UIViewController *old = _shown;
	_shown = primary;
	if ([self isViewLoaded] || old != nil)
		UIKitShowChild(self, old, primary);
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	if (_shown != nil && [[_shown view] superview] != [self view])
		UIKitShowChild(self, nil, _shown);
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[_shown uikitAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[_shown uikitDisappear:animated];
}

- (BOOL)isCollapsed { return YES; }
- (UISplitViewControllerDisplayMode)displayMode { return UISplitViewControllerDisplayModeAllVisible; }
- (CGFloat)primaryColumnWidth { return [[UIScreen mainScreen] bounds].size.width; }

- (UIBarButtonItem *)displayModeButtonItem
{
	if (_displayModeButtonItem == nil)
		_displayModeButtonItem = [[UIBarButtonItem alloc] initWithTitle:nil style:UIBarButtonItemStylePlain target:nil action:NULL];
	return _displayModeButtonItem;
}

- (void)showViewController:(UIViewController *)controller sender:(id)sender
{
	if ([_delegate respondsToSelector:@selector(splitViewController:showViewController:sender:)]
	    && [_delegate splitViewController:self showViewController:controller sender:sender])
		return;
	[[_viewControllers firstObject] showViewController:controller sender:sender];
}

- (void)showDetailViewController:(UIViewController *)controller sender:(id)sender
{
	if ([_delegate respondsToSelector:@selector(splitViewController:showDetailViewController:sender:)]
	    && [_delegate splitViewController:self showDetailViewController:controller sender:sender])
		return;
	UIViewController *primary = [_viewControllers firstObject];
	if ([primary isKindOfClass:[UINavigationController class]]) {
		/* A detail navigation controller's own content goes on the primary's stack. */
		if ([controller isKindOfClass:[UINavigationController class]]) {
			NSArray *stack = [(UINavigationController *)controller viewControllers];
			[(UINavigationController *)controller setViewControllers:@[]];
			for (UIViewController *pushed in stack)
				[(UINavigationController *)primary pushViewController:pushed animated:NO];
			return;
		}
		[(UINavigationController *)primary pushViewController:controller animated:YES];
		return;
	}
	[self presentViewController:controller animated:YES completion:nil];
}

@end

@implementation UIViewController (UISplitViewController)

- (UISplitViewController *)splitViewController
{
	for (UIViewController *controller = self; controller != nil; controller = [controller parentViewController])
		if ([controller isKindOfClass:[UISplitViewController class]])
			return (UISplitViewController *)controller;
	return [[self presentingViewController] splitViewController];
}

/* A navigation controller takes the secondary's controllers onto its stack;
 * other controllers drop it. */
- (void)collapseSecondaryViewController:(UIViewController *)secondary forSplitViewController:(UISplitViewController *)splitViewController
{
	if (![self isKindOfClass:[UINavigationController class]])
		return;
	NSArray *stack = [secondary isKindOfClass:[UINavigationController class]] ? [(UINavigationController *)secondary viewControllers] : @[ secondary ];
	/* An empty detail placeholder stays out of the way. */
	if ([stack count] == 1 && [[stack firstObject] isMemberOfClass:[UIViewController class]])
		return;
	if ([secondary isKindOfClass:[UINavigationController class]])
		[(UINavigationController *)secondary setViewControllers:@[]];
	for (UIViewController *controller in stack)
		[(UINavigationController *)self pushViewController:controller animated:NO];
}

@end

#pragma mark - UIPageViewController

NSString *const UIPageViewControllerOptionSpineLocationKey = @"UIPageViewControllerOptionSpineLocationKey";
NSString *const UIPageViewControllerOptionInterPageSpacingKey = @"UIPageViewControllerOptionInterPageSpacingKey";

@implementation UIPageViewController {
	UIPageViewControllerTransitionStyle _transitionStyle;
	UIPageViewControllerNavigationOrientation _navigationOrientation;
	UIPageViewControllerSpineLocation _spineLocation;
	NSArray<UIViewController *> *_viewControllers;
	NSArray *_gestureRecognizers;
}

@synthesize delegate = _delegate;
@synthesize dataSource = _dataSource;
@synthesize doubleSided = _doubleSided;

- (instancetype)initWithTransitionStyle:(UIPageViewControllerTransitionStyle)style navigationOrientation:(UIPageViewControllerNavigationOrientation)orientation options:(NSDictionary *)options
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		_transitionStyle = style;
		_navigationOrientation = orientation;
		NSNumber *spine = [options objectForKey:UIPageViewControllerOptionSpineLocationKey];
		_spineLocation = spine != nil ? [spine integerValue]
			: style == UIPageViewControllerTransitionStylePageCurl ? UIPageViewControllerSpineLocationMin : UIPageViewControllerSpineLocationNone;
	}
	return self;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
	if ((self = [super initWithNibName:nibName bundle:bundle]))
		_viewControllers = @[];
	return self;
}

- (UIPageViewControllerTransitionStyle)transitionStyle { return _transitionStyle; }
- (UIPageViewControllerNavigationOrientation)navigationOrientation { return _navigationOrientation; }
- (UIPageViewControllerSpineLocation)spineLocation { return _spineLocation; }
- (NSArray *)viewControllers { return _viewControllers ?: @[]; }
- (NSArray *)gestureRecognizers { [self view]; return _gestureRecognizers; }

- (void)loadView
{
	UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	BOOL horizontal = _navigationOrientation == UIPageViewControllerNavigationOrientationHorizontal;
	UISwipeGestureRecognizer *forward = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(uikitTurnForward:)];
	[forward setDirection:horizontal ? UISwipeGestureRecognizerDirectionLeft : UISwipeGestureRecognizerDirectionUp];
	UISwipeGestureRecognizer *back = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(uikitTurnBack:)];
	[back setDirection:horizontal ? UISwipeGestureRecognizerDirectionRight : UISwipeGestureRecognizerDirectionDown];
	[view addGestureRecognizer:forward];
	[view addGestureRecognizer:back];
	_gestureRecognizers = @[ forward, back ];
	[self setView:view];
	UIViewController *current = [_viewControllers firstObject];
	if (current != nil)
		UIKitShowChild(self, nil, current);
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[[_viewControllers firstObject] uikitAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[[_viewControllers firstObject] uikitDisappear:animated];
}

- (void)setViewControllers:(NSArray *)viewControllers direction:(UIPageViewControllerNavigationDirection)direction animated:(BOOL)animated completion:(void (^)(BOOL finished))completion
{
	UIViewController *old = [_viewControllers firstObject];
	_viewControllers = [viewControllers copy] ?: @[];
	UIKitShowChild(self, old, [_viewControllers firstObject]);
	if (completion != nil)
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(YES);
		});
}

- (void)uikitTurn:(BOOL)forward
{
	UIViewController *current = [_viewControllers firstObject];
	id<UIPageViewControllerDataSource> dataSource = _dataSource;
	if (current == nil || dataSource == nil)
		return;
	UIViewController *next = forward ? [dataSource pageViewController:self viewControllerAfterViewController:current]
		: [dataSource pageViewController:self viewControllerBeforeViewController:current];
	if (next == nil)
		return;
	id<UIPageViewControllerDelegate> delegate = _delegate;
	if ([delegate respondsToSelector:@selector(pageViewController:willTransitionToViewControllers:)])
		[delegate pageViewController:self willTransitionToViewControllers:@[ next ]];
	NSArray *previous = _viewControllers;
	_viewControllers = @[ next ];
	UIKitShowChild(self, current, next);
	if ([delegate respondsToSelector:@selector(pageViewController:didFinishAnimating:previousViewControllers:transitionCompleted:)])
		[delegate pageViewController:self didFinishAnimating:YES previousViewControllers:previous transitionCompleted:YES];
}

- (void)uikitTurnForward:(UIGestureRecognizer *)recognizer { [self uikitTurn:YES]; }
- (void)uikitTurnBack:(UIGestureRecognizer *)recognizer { [self uikitTurn:NO]; }

@end

#pragma mark - UIPopoverController

@implementation UIPopoverController {
	UIViewController *_contentViewController;
	BOOL _visible;
}

@synthesize delegate = _delegate;
@synthesize popoverContentSize = _popoverContentSize;
@synthesize passthroughViews = _passthroughViews;
@synthesize backgroundColor = _backgroundColor;

- (instancetype)initWithContentViewController:(UIViewController *)viewController
{
	if ((self = [super init]))
		_contentViewController = viewController;
	return self;
}

- (UIViewController *)contentViewController { return _contentViewController; }

- (void)setContentViewController:(UIViewController *)viewController
{
	[self setContentViewController:viewController animated:NO];
}

- (void)setContentViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if (_visible) {
		[self dismissPopoverAnimated:NO];
		_contentViewController = viewController;
		[self uikitPresent];
		return;
	}
	_contentViewController = viewController;
}

- (void)setPopoverContentSize:(CGSize)size animated:(BOOL)animated { _popoverContentSize = size; }

- (BOOL)isPopoverVisible
{
	return _visible && [_contentViewController presentingViewController] != nil;
}

- (UIPopoverArrowDirection)popoverArrowDirection { return UIPopoverArrowDirectionUnknown; }

- (void)uikitPresent
{
	UIViewController *presenter = UIKitTopPresenter();
	if (_contentViewController == nil || presenter == nil)
		return;
	_visible = YES;
	[presenter presentViewController:_contentViewController animated:YES completion:nil];
}

- (void)presentPopoverFromRect:(CGRect)rect inView:(UIView *)view permittedArrowDirections:(UIPopoverArrowDirection)directions animated:(BOOL)animated
{
	[self uikitPresent];
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)item permittedArrowDirections:(UIPopoverArrowDirection)directions animated:(BOOL)animated
{
	[self uikitPresent];
}

- (void)dismissPopoverAnimated:(BOOL)animated
{
	if (!_visible)
		return;
	_visible = NO;
	if ([_contentViewController presentingViewController] != nil)
		[_contentViewController dismissViewControllerAnimated:animated completion:nil];
}

@end
