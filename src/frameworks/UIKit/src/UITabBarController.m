/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UITabBarController.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIWindow.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSBezierPath.h>
#import "UIKitPrivate.h"

static const CGFloat UIKitTabBarHeight = 49;

/* Where an item's badge bubble goes, in its cell. */
static NSRect UIKitBadgeRect(NSRect cell, CGFloat width)
{
	return NSMakeRect(floor(cell.size.width / 2) + 6, 2, MAX(18, width), 18);
}

/* The view UIKit keeps for each tab, which the tab bar draws itself.  Apps
   reach for it with -[UITabBarItem view] and its _badge ivar, as Cydia
   does to put a spinner in the badge. */
@interface UITabBarButton : UIView {
	UIView *_badge;
}
@end

@implementation UITabBarButton

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_badge = [[UIView alloc] initWithFrame:UIKitBadgeRect(frame, 0)];
		[self addSubview:_badge];
	}
	return self;
}

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];
	[_badge setFrame:UIKitBadgeRect(NSMakeRect(0, 0, size.width, size.height), 0)];
}

/* Touches go to the tab bar. */
- (NSView *)hitTest:(NSPoint)point
{
	return nil;
}

@end

@implementation UITabBarItem {
	UIImage *_selectedImage;
	NSString *_badgeValue;
	UITabBarButton *_view;
}

- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image tag:(NSInteger)tag
{
	if ((self = [super init])) {
		[self setTitle:title];
		[self setImage:image];
		[self setTag:tag];
	}
	return self;
}

- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage
{
	if ((self = [self initWithTitle:title image:image tag:0]))
		_selectedImage = selectedImage;
	return self;
}

- (instancetype)initWithTabBarSystemItem:(UITabBarSystemItem)systemItem tag:(NSInteger)tag
{
	static NSString *const titles[] = {
		@"More", @"Favorites", @"Featured", @"Top Rated", @"Recents", @"Contacts",
		@"History", @"Bookmarks", @"Search", @"Downloads", @"Most Recent", @"Most Viewed",
	};
	NSString *title = systemItem >= 0 && systemItem < (NSInteger)(sizeof(titles) / sizeof(titles[0])) ? titles[systemItem] : nil;
	return [self initWithTitle:title image:nil tag:tag];
}

- (UIImage *)selectedImage { return _selectedImage; }
- (void)setSelectedImage:(UIImage *)image { _selectedImage = image; [[NSNotificationCenter defaultCenter] postNotificationName:UIKitBarItemDidChangeNotification object:self]; }
- (NSString *)badgeValue { return _badgeValue; }
- (void)setBadgeValue:(NSString *)value { _badgeValue = [value copy]; [[NSNotificationCenter defaultCenter] postNotificationName:UIKitBarItemDidChangeNotification object:self]; }
- (void)setAnimatedBadge:(BOOL)animated { }
- (UIView *)view
{
	if (_view == nil)
		_view = [[UITabBarButton alloc] initWithFrame:CGRectMake(0, 0, 64, UIKitTabBarHeight)];
	return _view;
}

@end

/* The image's shape filled with a color, as iOS draws template images. */
static NSImage *UIKitTintedImage(UIImage *image, NSColor *color)
{
	CGSize size = [image size];
	if (size.width <= 0 || size.height <= 0)
		return nil;
	NSImage *tinted = [[NSImage alloc] initWithSize:NSMakeSize(size.width, size.height)];
	[tinted lockFocus];
	[image drawInRect:CGRectMake(0, 0, size.width, size.height)];
	[color set];
	NSRectFillUsingOperation(NSMakeRect(0, 0, size.width, size.height), NSCompositeSourceAtop);
	[tinted unlockFocus];
	return tinted;
}

@implementation UITabBar {
	NSArray *_items;
	__weak UITabBarItem *_selectedItem;
	BOOL _concealed;
	NSInteger _pressedIndex;
	NSMutableDictionary *_tintCache;
}

@synthesize delegate = _delegate;
@synthesize barStyle = _barStyle;
@synthesize tintColor = _tintColor;
@synthesize barTintColor = _barTintColor;
@synthesize translucent = _translucent;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_pressedIndex = -1;
		_tintCache = [NSMutableDictionary dictionary];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemChanged:) name:UIKitBarItemDidChangeNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)itemChanged:(NSNotification *)notification
{
	if ([_items containsObject:[notification object]]) {
		[_tintCache removeAllObjects];
		[self setNeedsDisplay:YES];
	}
}

- (NSArray *)items { return _items; }

- (void)setItems:(NSArray *)items
{
	for (UITabBarItem *item in _items)
		if (![items containsObject:item] && [[item view] superview] == self)
			[[item view] removeFromSuperview];
	_items = [items copy];
	for (UITabBarItem *item in _items)
		if ([[item view] superview] != self)
			[self addSubview:[item view]];
	[self layoutSubviews];
	[_tintCache removeAllObjects];
	if (_selectedItem != nil && ![_items containsObject:_selectedItem])
		_selectedItem = nil;
	[self setNeedsDisplay:YES];
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated { [self setItems:items]; }

- (void)layoutSubviews
{
	[super layoutSubviews];
	[_items enumerateObjectsUsingBlock:^(UITabBarItem *item, NSUInteger index, BOOL *stop) {
		[[item view] setFrame:[self rectForItemAtIndex:index]];
	}];
}
- (UITabBarItem *)selectedItem { return _selectedItem; }
- (void)setSelectedItem:(UITabBarItem *)item { _selectedItem = item; [self setNeedsDisplay:YES]; }

- (void)uikitSetConcealed:(BOOL)concealed
{
	_concealed = concealed;
	[self setNeedsDisplay:YES];
}

- (NSRect)rectForItemAtIndex:(NSUInteger)index
{
	NSRect bounds = [self bounds];
	CGFloat width = [_items count] > 0 ? bounds.size.width / [_items count] : bounds.size.width;
	return NSMakeRect(floor(index * width), 0, floor(width), bounds.size.height);
}

- (NSImage *)imageForItem:(UITabBarItem *)item selected:(BOOL)selected
{
	UIImage *image = selected ? ([item selectedImage] ?: [item image]) : [item image];
	if (image == nil)
		return nil;
	NSValue *key = [NSValue valueWithNonretainedObject:image];
	NSString *cacheKey = [NSString stringWithFormat:@"%@-%d", key, selected];
	NSImage *tinted = [_tintCache objectForKey:cacheKey];
	if (tinted == nil) {
		NSColor *color = selected ? UIKitTintColor() : [NSColor colorWithCalibratedWhite:0.57 alpha:1];
		tinted = UIKitTintedImage(image, color);
		if (tinted != nil)
			[_tintCache setObject:tinted forKey:cacheKey];
	}
	return tinted;
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	[[NSColor colorWithCalibratedRed:0.97 green:0.97 blue:0.97 alpha:1] setFill];
	NSRectFill(rect);
	[[NSColor colorWithCalibratedWhite:0.70 alpha:1] setFill];
	NSRectFill(NSMakeRect(0, 0, bounds.size.width, 0.5));

	[_items enumerateObjectsUsingBlock:^(UITabBarItem *item, NSUInteger index, BOOL *stop) {
		NSRect cell = [self rectForItemAtIndex:index];
		BOOL selected = item == _selectedItem && !_concealed;
		NSImage *image = [self imageForItem:item selected:selected];
		if (image != nil) {
			NSSize size = [image size];
			CGFloat scale = size.height > 30 ? 30 / size.height : 1;
			NSRect target = NSMakeRect(floor(NSMidX(cell) - size.width * scale / 2), 5, size.width * scale, size.height * scale);
			[image drawInRect:target fromRect:NSZeroRect operation:NSCompositeSourceOver
			         fraction:(NSInteger)index == _pressedIndex ? 0.5 : 1 respectFlipped:YES hints:nil];
		}
		NSString *title = [item title];
		if ([title length] > 0) {
			NSDictionary *attributes = @{
				NSFontAttributeName: [NSFont systemFontOfSize:10],
				NSForegroundColorAttributeName: selected ? UIKitTintColor() : [NSColor colorWithCalibratedWhite:0.57 alpha:1],
			};
			NSSize size = [title sizeWithAttributes:attributes];
			[title drawAtPoint:NSMakePoint(floor(NSMidX(cell) - size.width / 2), cell.size.height - size.height - 2) withAttributes:attributes];
		}
		/* An empty badge is a bare bubble, as on iOS. */
		NSString *badge = [item badgeValue];
		if (badge != nil) {
			NSDictionary *attributes = @{
				NSFontAttributeName: [NSFont systemFontOfSize:12],
				NSForegroundColorAttributeName: [NSColor whiteColor],
			};
			NSSize size = [badge sizeWithAttributes:attributes];
			NSRect bubble = UIKitBadgeRect(cell, size.width + 10);
			bubble.origin.x += cell.origin.x;
			[[NSColor colorWithCalibratedRed:1 green:0.23 blue:0.19 alpha:1] setFill];
			[[NSBezierPath bezierPathWithRoundedRect:bubble xRadius:9 yRadius:9] fill];
			[badge drawAtPoint:NSMakePoint(NSMidX(bubble) - size.width / 2, NSMidY(bubble) - size.height / 2) withAttributes:attributes];
		}
	}];
}

- (NSInteger)indexAtTouch:(NSSet *)touches
{
	CGPoint point = [[touches anyObject] locationInView:self];
	for (NSUInteger i = 0; i < [_items count]; i++)
		if (NSPointInRect(NSMakePoint(point.x, point.y), [self rectForItemAtIndex:i]))
			return i;
	return -1;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	_pressedIndex = [self indexAtTouch:touches];
	[self setNeedsDisplay:YES];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSInteger index = [self indexAtTouch:touches];
	BOOL fire = index >= 0 && index == _pressedIndex;
	_pressedIndex = -1;
	[self setNeedsDisplay:YES];
	if (!fire)
		return;
	UITabBarItem *item = [_items objectAtIndex:index];
	if (![item isEnabled])
		return;
	_selectedItem = item;
	if ([_delegate respondsToSelector:@selector(tabBar:didSelectItem:)])
		[_delegate tabBar:self didSelectItem:item];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	_pressedIndex = -1;
	[self setNeedsDisplay:YES];
}

@end

@interface UIKitTabBarControllerView : UIView
@property (nonatomic, weak) UITabBarController *controller;
@end

@interface UITabBarController ()
- (void)layoutContainer;
@end

@implementation UIKitTabBarControllerView

- (void)layoutSubviews
{
	[_controller layoutContainer];
}

@end

@implementation UITabBarController {
	NSArray<UIViewController *> *_viewControllers;
	UITabBar *_tabBar;
	UIView *_transitionView;
	UIViewController *_shown;
	NSUInteger _selectedIndex;
}

@synthesize delegate = _delegate;
@synthesize customizableViewControllers = _customizableViewControllers;

- (instancetype)init
{
	if ((self = [super init])) {
		_tabBar = [[UITabBar alloc] initWithFrame:CGRectMake(0, 0, 320, UIKitTabBarHeight)];
		[_tabBar setDelegate:self];
		_viewControllers = @[];
		_selectedIndex = NSNotFound;
	}
	return self;
}

- (void)loadView
{
	UIKitTabBarControllerView *view = [[UIKitTabBarControllerView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[view setController:self];
	[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[view setBackgroundColor:[UIColor whiteColor]];
	_transitionView = [[UIView alloc] initWithFrame:[view bounds]];
	[_transitionView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[view addSubview:_transitionView];
	[_tabBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
	[view addSubview:_tabBar];
	[self setView:view];
	[self layoutContainer];
	[self showSelected:NO];
}

- (UITabBar *)tabBar { return _tabBar; }
- (UIView *)_transitionView { [self view]; return _transitionView; }
- (UINavigationController *)moreNavigationController { return nil; }
- (NSArray *)viewControllers { return _viewControllers; }

- (void)layoutContainer
{
	if (![self isViewLoaded])
		return;
	NSRect bounds = [[self view] bounds];
	BOOL hideBar = NO;
	if ([_shown isKindOfClass:[UINavigationController class]]) {
		UINavigationController *navigation = (UINavigationController *)_shown;
		hideBar = [[navigation viewControllers] count] > 1 && [[navigation topViewController] hidesBottomBarWhenPushed];
	}
	[_tabBar setHidden:hideBar];
	CGFloat barHeight = hideBar ? 0 : UIKitTabBarHeight;
	[_tabBar setFrame:NSMakeRect(0, bounds.size.height - UIKitTabBarHeight, bounds.size.width, UIKitTabBarHeight)];
	[_transitionView setFrame:NSMakeRect(0, 0, bounds.size.width, bounds.size.height - barHeight)];
	if ([_shown isViewLoaded])
		[[_shown view] setFrame:[_transitionView bounds]];
}

- (void)uikitTabBarItemsChanged
{
	[_tabBar setItems:[_viewControllers valueForKey:@"tabBarItem"] ?: @[]];
	if (_selectedIndex < [_viewControllers count])
		[_tabBar setSelectedItem:[[_viewControllers objectAtIndex:_selectedIndex] tabBarItem]];
}

- (void)setViewControllers:(NSArray *)viewControllers
{
	[self setViewControllers:viewControllers animated:NO];
}

- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
	UIViewController *previous = [self selectedViewController];
	for (UIViewController *controller in _viewControllers)
		if (![viewControllers containsObject:controller])
			[controller uikitSetParent:nil];
	_viewControllers = [viewControllers copy] ?: @[];
	for (UIViewController *controller in _viewControllers)
		[controller uikitSetParent:self];
	NSUInteger index = previous != nil ? [_viewControllers indexOfObject:previous] : NSNotFound;
	if (index == NSNotFound)
		index = [_viewControllers count] > 0 ? MIN(_selectedIndex == NSNotFound ? 0 : _selectedIndex, [_viewControllers count] - 1) : NSNotFound;
	_selectedIndex = index;
	[self uikitTabBarItemsChanged];
	[self showSelected:animated];
}

- (NSUInteger)selectedIndex
{
	return _selectedIndex;
}

- (void)setSelectedIndex:(NSUInteger)index
{
	if (index >= [_viewControllers count])
		return;
	_selectedIndex = index;
	[_tabBar setSelectedItem:[[_viewControllers objectAtIndex:index] tabBarItem]];
	[self showSelected:NO];
}

- (UIViewController *)selectedViewController
{
	return _selectedIndex < [_viewControllers count] ? [_viewControllers objectAtIndex:_selectedIndex] : nil;
}

- (void)setSelectedViewController:(UIViewController *)controller
{
	NSUInteger index = [_viewControllers indexOfObject:controller];
	if (index != NSNotFound)
		[self setSelectedIndex:index];
}

- (void)showSelected:(BOOL)animated
{
	if (![self isViewLoaded])
		return;
	UIViewController *selected = [self selectedViewController];
	if (selected == _shown)
		return;
	BOOL visible = [[self view] window] != nil;
	if (_shown != nil) {
		if (visible)
			[_shown uikitDisappear:animated];
		if ([_shown isViewLoaded])
			[[_shown view] removeFromSuperview];
	}
	_shown = selected;
	if (selected != nil) {
		UIView *view = [selected view];
		[view setFrame:[_transitionView bounds]];
		[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[_transitionView addSubview:view];
		UIWindow *window = [[self view] uiWindow];
		if (window != nil)
			[view attachToWindow:window];
		if (visible)
			[selected uikitAppear:animated];
	}
	[self layoutContainer];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self showSelected:NO];
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

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
	NSUInteger index = [[_viewControllers valueForKey:@"tabBarItem"] indexOfObjectIdenticalTo:item];
	if (index == NSNotFound)
		return;
	UIViewController *controller = [_viewControllers objectAtIndex:index];
	if ([_delegate respondsToSelector:@selector(tabBarController:shouldSelectViewController:)] &&
	    ![_delegate tabBarController:self shouldSelectViewController:controller]) {
		[_tabBar setSelectedItem:[[self selectedViewController] tabBarItem]];
		return;
	}
	/* Tapping the selected tab again pops its navigation stack. */
	if (index == _selectedIndex && [controller isKindOfClass:[UINavigationController class]])
		[(UINavigationController *)controller popToRootViewControllerAnimated:YES];
	[self setSelectedIndex:index];
	[_tabBar uikitSetConcealed:NO];
	if ([_delegate respondsToSelector:@selector(tabBarController:didSelectViewController:)])
		[_delegate tabBarController:self didSelectViewController:controller];
	/* Cydia's controller is its own delegate through this method too. */
	else if ([self respondsToSelector:@selector(tabBarController:didSelectViewController:)])
		[(id<UITabBarControllerDelegate>)self tabBarController:self didSelectViewController:controller];
}

- (void)concealTabBarSelection
{
	[_tabBar uikitSetConcealed:YES];
}

- (void)revealTabBarSelection
{
	[_tabBar uikitSetConcealed:NO];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	for (UIViewController *controller in _viewControllers)
		[controller didReceiveMemoryWarning];
}

@end
