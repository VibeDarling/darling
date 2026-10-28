/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIWindow.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIView.h>
#import <AppKit/NSWindow.h>
#import <Foundation/NSProcessInfo.h>

#import "UIKitPrivate.h"
#import <UIKit/UIScreen.h>

/* UIKit's windows, oldest first, and the one made key last. */
static NSHashTable<UIWindow *> *sWindows;
static __weak UIWindow *sKeyWindow;

@implementation UIWindow

+ (UIWindow *)uikitKeyWindow
{
	if (sKeyWindow != nil)
		return sKeyWindow;
	for (UIWindow *window in sWindows)
		if ([(NSWindow *)window->_hostWindow isVisible])
			return window;
	return nil;
}

+ (NSArray *)uikitWindows
{
	return [sWindows allObjects] ?: @[];
}

- (CGFloat)windowLevel { return 0; }
- (void)setWindowLevel:(CGFloat)level { }
- (BOOL)isKeyWindow { return sKeyWindow == self; }
- (id)screen { return [UIScreen mainScreen]; }
- (void)setScreen:(id)screen { }
- (void)sendEvent:(UIEvent *)event { }

- (id)firstResponder
{
	return [(NSWindow *)_hostWindow firstResponder];
}

- (void)orderFront:(id)sender
{
	[super setHidden:NO];
	[(NSWindow *)_hostWindow orderFront:nil];
	[[_rootViewController view] layoutIfNeeded];
	[_rootViewController uikitAppear:NO];
}

- (void)makeKey:(id)sender
{
	[self makeKeyWindow];
}

- (void)setHidden:(BOOL)hidden
{
	[super setHidden:hidden];
	if (hidden) {
		[(NSWindow *)_hostWindow orderOut:nil];
		[_rootViewController uikitDisappear:NO];
	} else {
		[self orderFront:nil];
	}
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self == nil)
		return nil;

	NSRect contentRect = NSMakeRect(frame.origin.x, frame.origin.y,
	                                frame.size.width, frame.size.height);
	/* iOS windows have no frame, title bar or controls. */
	NSWindow *host = [[NSWindow alloc] initWithContentRect:contentRect
	                                            styleMask:NSWindowStyleMaskBorderless
	                                              backing:NSBackingStoreBuffered
	                                                defer:NO];
	[host setReleasedWhenClosed:NO];
	/* No iOS equivalent of an NSWindow title; use the process name so the
	 * windowing system and the launch probes can identify the surface. */
	[host setTitle:[[NSProcessInfo processInfo] processName]];
	[host setContentView:self];
	_hostWindow = host;
	if (sWindows == nil)
		sWindows = [NSHashTable weakObjectsHashTable];
	[sWindows addObject:self];

	[self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[self setFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
	return self;
}

- (void)dealloc
{
	[(NSWindow *)_hostWindow setContentView:nil];
}

- (UIViewController *)rootViewController
{
	return _rootViewController;
}

- (void)setRootViewController:(UIViewController *)controller
{
	if (_rootViewController == controller)
		return;
	if (_rootViewController != nil)
		[[_rootViewController view] removeFromSuperview];

	_rootViewController = controller;
	if (controller == nil)
		return;

	UIView *view = [controller view];
	[view setFrame:[self bounds]];
	[self addSubview:view];
	[view attachToWindow:self];
}

- (void)makeKeyAndVisible
{
	sKeyWindow = self;
	[super setHidden:NO];
	[(NSWindow *)_hostWindow makeKeyAndOrderFront:nil];
	[[_rootViewController view] layoutIfNeeded];
	[_rootViewController uikitAppear:NO];
}

- (void)makeKeyWindow
{
	sKeyWindow = self;
	[(NSWindow *)_hostWindow makeKeyWindow];
}

@end
