/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UINavigationController.h>
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIWindow.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSGraphics.h>
#import <objc/message.h>
#import "UIKitPrivate.h"

NSString *const UIKitBarItemDidChangeNotification = @"UIKitBarItemDidChangeNotification";

static void UIKitBarItemChanged(id item)
{
	[[NSNotificationCenter defaultCenter] postNotificationName:UIKitBarItemDidChangeNotification object:item];
}

NSColor *UIKitTintColor(void)
{
	return [NSColor colorWithCalibratedRed:0 green:0.478 blue:1 alpha:1];
}

#pragma mark - Bar items

@implementation UIBarItem {
	NSString *_title;
	UIImage *_image;
	BOOL _enabled;
}

@synthesize tag = _tag;
@synthesize imageInsets = _imageInsets;

- (instancetype)init
{
	if ((self = [super init]))
		_enabled = YES;
	return self;
}

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)title { _title = [title copy]; UIKitBarItemChanged(self); }
- (UIImage *)image { return _image; }
- (void)setImage:(UIImage *)image { _image = image; UIKitBarItemChanged(self); }
- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)enabled { _enabled = enabled; UIKitBarItemChanged(self); }
- (void)setTitleTextAttributes:(NSDictionary *)attributes forState:(NSUInteger)state { }

@end

static NSString *UIKitSystemItemTitle(UIBarButtonSystemItem item)
{
	switch (item) {
	case UIBarButtonSystemItemDone: return @"Done";
	case UIBarButtonSystemItemCancel: return @"Cancel";
	case UIBarButtonSystemItemEdit: return @"Edit";
	case UIBarButtonSystemItemSave: return @"Save";
	case UIBarButtonSystemItemAdd: return @"+";
	case UIBarButtonSystemItemCompose: return @"Compose";
	case UIBarButtonSystemItemReply: return @"Reply";
	case UIBarButtonSystemItemAction: return @"Share";
	case UIBarButtonSystemItemOrganize: return @"Organize";
	case UIBarButtonSystemItemBookmarks: return @"Bookmarks";
	case UIBarButtonSystemItemSearch: return @"Search";
	case UIBarButtonSystemItemRefresh: return @"↻";
	case UIBarButtonSystemItemStop: return @"✕";
	case UIBarButtonSystemItemCamera: return @"Camera";
	case UIBarButtonSystemItemTrash: return @"Delete";
	case UIBarButtonSystemItemPlay: return @"▶";
	case UIBarButtonSystemItemPause: return @"‖";
	case UIBarButtonSystemItemRewind: return @"⏪";
	case UIBarButtonSystemItemFastForward: return @"⏩";
	case UIBarButtonSystemItemUndo: return @"Undo";
	case UIBarButtonSystemItemRedo: return @"Redo";
	default: return nil;
	}
}

@implementation UIBarButtonItem {
	UIBarButtonItemStyle _style;
	UIView *_customView;
	BOOL _space;
}

@synthesize target = _target;
@synthesize action = _action;
@synthesize width = _width;
@synthesize tintColor = _tintColor;
@synthesize possibleTitles = _possibleTitles;

- (instancetype)initWithTitle:(NSString *)title style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action
{
	if ((self = [super init])) {
		[self setTitle:title];
		_style = style;
		_target = target;
		_action = action;
	}
	return self;
}

- (instancetype)initWithImage:(UIImage *)image style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action
{
	if ((self = [super init])) {
		[self setImage:image];
		_style = style;
		_target = target;
		_action = action;
	}
	return self;
}

- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem target:(id)target action:(SEL)action
{
	UIBarButtonItemStyle style = systemItem == UIBarButtonSystemItemDone ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
	if ((self = [self initWithTitle:UIKitSystemItemTitle(systemItem) style:style target:target action:action]))
		_space = systemItem == UIBarButtonSystemItemFlexibleSpace || systemItem == UIBarButtonSystemItemFixedSpace;
	return self;
}

- (instancetype)initWithCustomView:(UIView *)customView
{
	if ((self = [super init]))
		_customView = customView;
	return self;
}

- (UIBarButtonItemStyle)style { return _style; }
- (void)setStyle:(UIBarButtonItemStyle)style { _style = style; UIKitBarItemChanged(self); }
- (UIView *)customView { return _customView; }
- (void)setCustomView:(UIView *)view { _customView = view; UIKitBarItemChanged(self); }
- (BOOL)uikitIsSpace { return _space; }

/* Private UIKit API: the view showing the item, where there is one. */
- (UIView *)view
{
	return _customView;
}

- (void)uikitPerform
{
	if (_action == NULL || ![self isEnabled])
		return;
	id target = _target;
	if (target == nil)
		return;
	((void (*)(id, SEL, id))objc_msgSend)(target, _action, self);
}

@end

#pragma mark - Bar button view

/* A tappable title or image in a bar, drawn in the tint color. */
@interface UIKitBarButtonView : UIView
- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image bold:(BOOL)bold handler:(void (^)(void))handler;
@property (nonatomic) BOOL enabled;
- (CGFloat)preferredWidth;
@end

@implementation UIKitBarButtonView {
	NSString *_title;
	UIImage *_image;
	BOOL _bold;
	BOOL _pressed;
	void (^_handler)(void);
}

- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image bold:(BOOL)bold handler:(void (^)(void))handler
{
	if ((self = [super initWithFrame:CGRectZero])) {
		_title = [title copy];
		_image = image;
		_bold = bold;
		_handler = [handler copy];
		_enabled = YES;
	}
	return self;
}

- (NSDictionary *)attributes
{
	NSColor *color = _enabled ? UIKitTintColor() : [NSColor colorWithCalibratedWhite:0.7 alpha:1];
	if (_pressed)
		color = [color colorWithAlphaComponent:0.3];
	return @{
		NSFontAttributeName: _bold ? [NSFont boldSystemFontOfSize:17] : [NSFont systemFontOfSize:17],
		NSForegroundColorAttributeName: color,
	};
}

- (CGFloat)preferredWidth
{
	if (_image != nil)
		return MAX(30, [_image size].width + 16);
	return ceil([_title sizeWithAttributes:[self attributes]].width) + 16;
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	if (_image != nil) {
		CGSize size = [_image size];
		[_image drawInRect:CGRectMake(floor(NSMidX(bounds) - size.width / 2), floor(NSMidY(bounds) - size.height / 2), size.width, size.height)
		         blendMode:kCGBlendModeNormal
		             alpha:_pressed || !_enabled ? 0.3 : 1];
		return;
	}
	NSDictionary *attributes = [self attributes];
	NSSize size = [_title sizeWithAttributes:attributes];
	[_title drawAtPoint:NSMakePoint(floor(NSMidX(bounds) - size.width / 2), floor(NSMidY(bounds) - size.height / 2))
	     withAttributes:attributes];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!_enabled)
		return;
	_pressed = YES;
	[self setNeedsDisplay:YES];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGPoint point = [[touches anyObject] locationInView:self];
	BOOL inside = NSPointInRect(NSMakePoint(point.x, point.y), NSInsetRect([self bounds], -20, -20));
	if (_enabled && inside != _pressed) {
		_pressed = inside;
		[self setNeedsDisplay:YES];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	BOOL fire = _pressed;
	_pressed = NO;
	[self setNeedsDisplay:YES];
	if (fire && _handler != nil)
		_handler();
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	_pressed = NO;
	[self setNeedsDisplay:YES];
}

@end

UIView *UIKitViewForBarButtonItem(UIBarButtonItem *item, BOOL bold)
{
	if ([item customView] != nil)
		return [item customView];
	__weak UIBarButtonItem *weakItem = item;
	UIKitBarButtonView *view = [[UIKitBarButtonView alloc] initWithTitle:[item title]
	                                                               image:[item image]
	                                                                bold:bold || [item style] == UIBarButtonItemStyleDone
	                                                             handler:^{
		[weakItem uikitPerform];
	}];
	[view setEnabled:[item isEnabled]];
	return view;
}

CGFloat UIKitPreferredWidthOfBarView(UIView *view)
{
	if ([view isKindOfClass:[UIKitBarButtonView class]])
		return [(UIKitBarButtonView *)view preferredWidth];
	return [view frame].size.width;
}

#pragma mark - UINavigationItem

@implementation UINavigationItem {
	NSString *_title;
	UIView *_titleView;
	UIBarButtonItem *_backBarButtonItem;
	NSArray *_leftItems;
	NSArray *_rightItems;
	BOOL _hidesBackButton;
}

@synthesize prompt = _prompt;
@synthesize leftItemsSupplementBackButton = _leftItemsSupplementBackButton;

- (instancetype)initWithTitle:(NSString *)title
{
	if ((self = [super init]))
		_title = [title copy];
	return self;
}

- (instancetype)init
{
	return [self initWithTitle:nil];
}

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)title { _title = [title copy]; UIKitBarItemChanged(self); }
- (UIView *)titleView { return _titleView; }
- (void)setTitleView:(UIView *)view { _titleView = view; UIKitBarItemChanged(self); }
- (UIBarButtonItem *)backBarButtonItem { return _backBarButtonItem; }
- (void)setBackBarButtonItem:(UIBarButtonItem *)item { _backBarButtonItem = item; UIKitBarItemChanged(self); }
- (BOOL)hidesBackButton { return _hidesBackButton; }
- (void)setHidesBackButton:(BOOL)hides { _hidesBackButton = hides; UIKitBarItemChanged(self); }
- (void)setHidesBackButton:(BOOL)hides animated:(BOOL)animated { [self setHidesBackButton:hides]; }

- (UIBarButtonItem *)leftBarButtonItem { return [_leftItems firstObject]; }
- (UIBarButtonItem *)rightBarButtonItem { return [_rightItems firstObject]; }
- (void)setLeftBarButtonItem:(UIBarButtonItem *)item { [self setLeftBarButtonItems:item != nil ? @[ item ] : nil]; }
- (void)setRightBarButtonItem:(UIBarButtonItem *)item { [self setRightBarButtonItems:item != nil ? @[ item ] : nil]; }
- (void)setLeftBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated { [self setLeftBarButtonItem:item]; }
- (void)setRightBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated { [self setRightBarButtonItem:item]; }
- (NSArray *)leftBarButtonItems { return _leftItems; }
- (NSArray *)rightBarButtonItems { return _rightItems; }
- (void)setLeftBarButtonItems:(NSArray *)items { _leftItems = [items copy]; UIKitBarItemChanged(self); }
- (void)setRightBarButtonItems:(NSArray *)items { _rightItems = [items copy]; UIKitBarItemChanged(self); }
- (void)setLeftBarButtonItems:(NSArray *)items animated:(BOOL)animated { [self setLeftBarButtonItems:items]; }
- (void)setRightBarButtonItems:(NSArray *)items animated:(BOOL)animated { [self setRightBarButtonItems:items]; }

@end

#pragma mark - UINavigationBar

@implementation UINavigationBar {
	NSMutableArray<UINavigationItem *> *_items;
	NSMutableArray<UIView *> *_itemViews;
	BOOL _needsRebuild;
}

@synthesize delegate = _delegate;
@synthesize barStyle = _barStyle;
@synthesize tintColor = _tintColor;
@synthesize barTintColor = _barTintColor;
@synthesize translucent = _translucent;
@synthesize titleTextAttributes = _titleTextAttributes;

+ (CGSize)defaultSize
{
	return CGSizeMake(320, 44);
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_items = [NSMutableArray array];
		_itemViews = [NSMutableArray array];
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
	UINavigationItem *top = [self topItem];
	id item = [notification object];
	if (item == top || item == [self backItem] || [[top leftBarButtonItems] containsObject:item] ||
	    [[top rightBarButtonItems] containsObject:item] || item == [[self backItem] backBarButtonItem])
		[self rebuild];
}

- (NSArray *)items { return [_items copy]; }
- (UINavigationItem *)topItem { return [_items lastObject]; }
- (UINavigationItem *)backItem { return [_items count] > 1 ? [_items objectAtIndex:[_items count] - 2] : nil; }

- (void)setItems:(NSArray *)items
{
	[_items setArray:items ?: @[]];
	[self rebuild];
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated
{
	[self setItems:items];
}

- (void)pushNavigationItem:(UINavigationItem *)item animated:(BOOL)animated
{
	if (item == nil)
		return;
	[_items addObject:item];
	[self rebuild];
}

- (UINavigationItem *)popNavigationItemAnimated:(BOOL)animated
{
	UINavigationItem *item = [_items lastObject];
	if (item != nil)
		[_items removeLastObject];
	[self rebuild];
	return item;
}

- (void)backPressed
{
	UINavigationItem *top = [self topItem];
	if (top == nil)
		return;
	if ([_delegate respondsToSelector:@selector(navigationBar:shouldPopItem:)]) {
		/* The controller pops for us. */
		[_delegate navigationBar:self shouldPopItem:top];
		return;
	}
	[self popNavigationItemAnimated:YES];
}

- (void)rebuild
{
	for (UIView *view in _itemViews)
		[view removeFromSuperview];
	[_itemViews removeAllObjects];

	UINavigationItem *top = [self topItem];
	UINavigationItem *back = [self backItem];
	NSMutableArray *left = [NSMutableArray array];
	if (back != nil && ![top hidesBackButton] && ([[top leftBarButtonItems] count] == 0 || [top leftItemsSupplementBackButton])) {
		NSString *title = [[back backBarButtonItem] title] ?: [back title] ?: @"Back";
		if ([title length] > 12)
			title = @"Back";
		__weak UINavigationBar *weakSelf = self;
		UIKitBarButtonView *button = [[UIKitBarButtonView alloc] initWithTitle:[@"‹ " stringByAppendingString:title]
		                                                                 image:nil
		                                                                  bold:NO
		                                                               handler:^{
			[weakSelf backPressed];
		}];
		[left addObject:button];
	}
	for (UIBarButtonItem *item in [top leftBarButtonItems])
		if (![item uikitIsSpace])
			[left addObject:UIKitViewForBarButtonItem(item, NO)];
	NSMutableArray *right = [NSMutableArray array];
	for (UIBarButtonItem *item in [top rightBarButtonItems])
		if (![item uikitIsSpace])
			[right addObject:UIKitViewForBarButtonItem(item, NO)];

	NSRect bounds = [self bounds];
	CGFloat x = 4;
	for (UIView *view in left) {
		CGFloat width = UIKitPreferredWidthOfBarView(view);
		CGFloat height = [view isKindOfClass:[UIKitBarButtonView class]] ? bounds.size.height : MIN([view frame].size.height, bounds.size.height);
		[view setFrame:NSMakeRect(x, floor((bounds.size.height - height) / 2), width, height)];
		[view setAutoresizingMask:UIViewAutoresizingFlexibleRightMargin];
		[self addSubview:view];
		[_itemViews addObject:view];
		x += width;
	}
	x = bounds.size.width - 4;
	for (UIView *view in right) {
		CGFloat width = UIKitPreferredWidthOfBarView(view);
		CGFloat height = [view isKindOfClass:[UIKitBarButtonView class]] ? bounds.size.height : MIN([view frame].size.height, bounds.size.height);
		x -= width;
		[view setFrame:NSMakeRect(x, floor((bounds.size.height - height) / 2), width, height)];
		[view setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
		[self addSubview:view];
		[_itemViews addObject:view];
	}
	UIView *titleView = [top titleView];
	if (titleView != nil) {
		NSRect frame = [titleView frame];
		frame.origin.x = floor((bounds.size.width - frame.size.width) / 2);
		frame.origin.y = floor((bounds.size.height - frame.size.height) / 2);
		[titleView setFrame:frame];
		[titleView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
		[self addSubview:titleView];
		[_itemViews addObject:titleView];
	}
	[self setNeedsDisplay:YES];
}

- (void)layoutSubviews
{
	[self rebuild];
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	[[NSColor colorWithCalibratedRed:0.97 green:0.97 blue:0.97 alpha:1] setFill];
	NSRectFill(rect);
	[[NSColor colorWithCalibratedWhite:0.70 alpha:1] setFill];
	NSRectFill(NSMakeRect(0, bounds.size.height - 0.5, bounds.size.width, 0.5));

	UINavigationItem *top = [self topItem];
	if ([top titleView] != nil || [[top title] length] == 0)
		return;
	/* Centred, but clear of the buttons. */
	CGFloat leftEdge = 0, rightEdge = bounds.size.width;
	for (UIView *view in _itemViews) {
		NSRect frame = [view frame];
		if (NSMidX(frame) < bounds.size.width / 2)
			leftEdge = MAX(leftEdge, NSMaxX(frame));
		else
			rightEdge = MIN(rightEdge, NSMinX(frame));
	}
	CGFloat inset = MAX(leftEdge, bounds.size.width - rightEdge) + 4;
	NSDictionary *attributes = @{
		NSFontAttributeName: [NSFont boldSystemFontOfSize:17],
		NSForegroundColorAttributeName: [NSColor blackColor],
	};
	NSString *title = [top title];
	CGFloat available = bounds.size.width - 2 * inset;
	while ([title length] > 1 && [title sizeWithAttributes:attributes].width > available)
		title = [[title substringToIndex:[title length] - 2] stringByAppendingString:@"…"];
	NSSize size = [title sizeWithAttributes:attributes];
	[title drawAtPoint:NSMakePoint(floor((bounds.size.width - size.width) / 2), floor((bounds.size.height - size.height) / 2))
	    withAttributes:attributes];
}

@end

#pragma mark - UINavigationController

static const CGFloat UIKitNavigationBarHeight = 44;

/* Leaves room for the status bar when the controller's view reaches the
 * top of the window, as iOS 7 does, and fills that strip like the bar. */
@interface UIKitNavigationView : UIView
@property (nonatomic, weak) UINavigationController *controller;
@end

@interface UINavigationController () <UINavigationBarDelegate>
- (void)layoutContainer;
- (CGFloat)barTop;
@end

@implementation UIKitNavigationView

- (void)layoutSubviews
{
	[_controller layoutContainer];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	[_controller layoutContainer];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	CGFloat top = [_controller barTop];
	if (top > 0 && ![_controller isNavigationBarHidden]) {
		[[NSColor colorWithCalibratedRed:0.97 green:0.97 blue:0.97 alpha:1] setFill];
		NSRectFill(NSMakeRect(0, 0, [self bounds].size.width, top));
	}
}

@end

@implementation UINavigationController {
	NSMutableArray<UIViewController *> *_stack;
	UINavigationBar *_navigationBar;
	UIViewController *_shown;
	BOOL _navigationBarHidden;
	BOOL _toolbarHidden;
}

@synthesize delegate = _delegate;

- (instancetype)init
{
	if ((self = [super init])) {
		_stack = [NSMutableArray array];
		_navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, UIKitNavigationBarHeight)];
		[_navigationBar setDelegate:self];
		_toolbarHidden = YES;
	}
	return self;
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
{
	if ((self = [self init]) && rootViewController != nil)
		[self setViewControllers:@[ rootViewController ]];
	return self;
}

- (void)loadView
{
	UIKitNavigationView *view = [[UIKitNavigationView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	[view setController:self];
	[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[view setBackgroundColor:[UIColor whiteColor]];
	[_navigationBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
	[view addSubview:_navigationBar];
	[self setView:view];
	[self showTop:NO];
}

- (UINavigationBar *)navigationBar { return _navigationBar; }
- (NSArray *)viewControllers { return [_stack copy]; }
- (UIViewController *)topViewController { return [_stack lastObject]; }

- (UIViewController *)visibleViewController
{
	UIViewController *top = [self topViewController];
	UIViewController *presented = [self presentedViewController] ?: [top presentedViewController];
	return presented ?: top;
}

- (CGFloat)barTop
{
	if (![self isViewLoaded])
		return 0;
	UIView *view = [self view];
	if ([view window] == nil)
		return 0;
	NSPoint origin = [view convertPoint:NSMakePoint(0, 0) toView:nil];
	NSView *content = [[view window] contentView];
	NSPoint inContent = [content convertPoint:origin fromView:nil];
	return inContent.y < 1 ? UIKitStatusBarHeight : 0;
}

- (void)layoutContainer
{
	if (![self isViewLoaded])
		return;
	NSRect bounds = [[self view] bounds];
	CGFloat top = [self barTop];
	CGFloat contentTop = top;
	[_navigationBar setHidden:_navigationBarHidden];
	if (!_navigationBarHidden) {
		[_navigationBar setFrame:NSMakeRect(0, top, bounds.size.width, UIKitNavigationBarHeight)];
		contentTop += UIKitNavigationBarHeight;
	}
	UIView *content = [_shown isViewLoaded] ? [_shown view] : nil;
	if (content != nil && [content superview] == [self view])
		[content setFrame:NSMakeRect(0, contentTop, bounds.size.width, MAX(0, bounds.size.height - contentTop))];
	[[self view] setNeedsDisplay:YES];
}

/* Puts the top controller's view in place of the one shown before. */
- (void)showTop:(BOOL)animated
{
	UIViewController *top = [self topViewController];
	[_navigationBar setItems:[_stack valueForKey:@"navigationItem"] ?: @[]];
	if (![self isViewLoaded] || top == _shown)
		return;
	if ([_delegate respondsToSelector:@selector(navigationController:willShowViewController:animated:)] && top != nil)
		[_delegate navigationController:self willShowViewController:top animated:animated];
	UIViewController *old = _shown;
	BOOL visible = [[self view] window] != nil;
	if (old != nil) {
		if (visible)
			[old uikitDisappear:animated];
		if ([old isViewLoaded])
			[[old view] removeFromSuperview];
	}
	_shown = top;
	if (top != nil) {
		UIView *view = [top view];
		[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[[self view] addSubview:view positioned:NSWindowBelow relativeTo:_navigationBar];
		UIWindow *window = (UIWindow *)[[self view] uiWindow];
		if (window != nil)
			[view attachToWindow:window];
		[self layoutContainer];
		if (visible)
			[top uikitAppear:animated];
	}
	if ([_delegate respondsToSelector:@selector(navigationController:didShowViewController:animated:)] && top != nil)
		[_delegate navigationController:self didShowViewController:top animated:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self showTop:NO];
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

- (void)setViewControllers:(NSArray *)viewControllers
{
	[self setViewControllers:viewControllers animated:NO];
}

- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
	for (UIViewController *controller in _stack)
		if (![viewControllers containsObject:controller])
			[controller uikitSetParent:nil];
	[_stack setArray:viewControllers ?: @[]];
	for (UIViewController *controller in _stack)
		[controller uikitSetParent:self];
	[self showTop:animated];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if (viewController == nil || [_stack containsObject:viewController])
		return;
	[_stack addObject:viewController];
	[viewController uikitSetParent:self];
	[self showTop:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
	if ([_stack count] < 2)
		return nil;
	UIViewController *top = [_stack lastObject];
	[_stack removeLastObject];
	[self showTop:animated];
	[top uikitSetParent:nil];
	return top;
}

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	NSUInteger index = [_stack indexOfObject:viewController];
	if (index == NSNotFound)
		return nil;
	NSRange range = NSMakeRange(index + 1, [_stack count] - index - 1);
	NSArray *popped = [_stack subarrayWithRange:range];
	[_stack removeObjectsInRange:range];
	[self showTop:animated];
	for (UIViewController *controller in popped)
		[controller uikitSetParent:nil];
	return popped;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
	if ([_stack count] == 0)
		return nil;
	return [self popToViewController:[_stack firstObject] animated:animated];
}

- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item
{
	[self popViewControllerAnimated:YES];
	return NO;
}

- (BOOL)isNavigationBarHidden { return _navigationBarHidden; }

- (void)setNavigationBarHidden:(BOOL)hidden
{
	_navigationBarHidden = hidden;
	[self layoutContainer];
}

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated
{
	[self setNavigationBarHidden:hidden];
}

- (BOOL)isToolbarHidden { return _toolbarHidden; }
- (void)setToolbarHidden:(BOOL)hidden { _toolbarHidden = hidden; }
- (void)setToolbarHidden:(BOOL)hidden animated:(BOOL)animated { _toolbarHidden = hidden; }

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	for (UIViewController *controller in _stack)
		[controller didReceiveMemoryWarning];
}

@end
