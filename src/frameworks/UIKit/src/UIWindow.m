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
#import <AppKit/NSScreen.h>
#import <Foundation/NSProcessInfo.h>

#import "UIKitPrivate.h"
#import <UIKit/UIScreen.h>
#import <UIKit/UIGraphics.h>
#import <UIKit/UIColor.h>

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

/* The hosting window's level: windows at a higher one stay in front, even
   of other apps' windows where the display server stacks them by level. */
- (CGFloat)windowLevel { return [(NSWindow *)_hostWindow level]; }
- (void)setWindowLevel:(CGFloat)level { [(NSWindow *)_hostWindow setLevel:(NSInteger)level]; }
/* iOS 2's names for these, which old tweaks still call. */
- (void)setLevel:(CGFloat)level { [self setWindowLevel:level]; }
- (CGFloat)level { return [self windowLevel]; }
- (void)setContentView:(UIView *)view
{
	for (UIView *subview in [[self subviews] copy])
		[subview removeFromSuperview];
	if (view != nil) {
		[view setFrame:[self bounds]];
		[self addSubview:view];
	}
}
- (BOOL)isKeyWindow { return sKeyWindow == self; }

/* What a window doesn't cover shows the windows behind it, as on iOS: one
   whose background is not fully opaque is composed over them. */
- (void)setBackgroundColor:(UIColor *)color
{
	[super setBackgroundColor:color];
	BOOL opaque = color != nil && CGColorGetAlpha([color CGColor]) >= 1;
	[(NSWindow *)_hostWindow setOpaque:opaque];
	[(NSWindow *)_hostWindow setBackgroundColor:opaque ? [color nsColor] : [NSColor clearColor]];
}

/* Such a window's redraws start from its background, transparent where it
   is: filling with a clear color the usual way leaves what was drawn there
   before (a view since removed) in place. */
- (void)drawRect:(NSRect)rect
{
	if ([(NSWindow *)_hostWindow isOpaque]) {
		[super drawRect:rect];
		return;
	}
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, kCGBlendModeCopy);
	CGContextSetFillColorWithColor(context, [[self backgroundColor] ?: [UIColor clearColor] CGColor]);
	CGContextFillRect(context, rect);
	CGContextRestoreGState(context);
}
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

	/* UIKit measures y from the top of the screen, AppKit from the bottom. */
	NSRect screen = [[NSScreen mainScreen] frame];
	NSRect contentRect = NSMakeRect(frame.origin.x, NSMaxY(screen) - frame.origin.y - frame.size.height,
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
