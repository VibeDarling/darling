/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIApplication.h>
#import <UIKit/UIApplicationDelegate.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSEvent.h>
#import <FrontBoardServices/FrontBoardServices.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSProcessInfo.h>
#import <objc/message.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>

NSString *const UIApplicationDidFinishLaunchingNotification = @"UIApplicationDidFinishLaunchingNotification";
NSString *const UIApplicationDidBecomeActiveNotification = @"UIApplicationDidBecomeActiveNotification";
NSString *const UIApplicationWillResignActiveNotification = @"UIApplicationWillResignActiveNotification";
NSString *const UIApplicationDidEnterBackgroundNotification = @"UIApplicationDidEnterBackgroundNotification";
NSString *const UIApplicationWillEnterForegroundNotification = @"UIApplicationWillEnterForegroundNotification";
NSString *const UIApplicationWillTerminateNotification = @"UIApplicationWillTerminateNotification";

/* -[NSApplication run] delivers the AppKit delegate callbacks; UIApplication
 * implements them and forwards to the iOS delegate, which never sees AppKit.
 * frontboardd's lifecycle events arrive through FBSWorkspace. */
@interface UIApplication () <NSApplicationDelegate, FBSWorkspaceDelegate>
@end

/* The keyboard's Home key is the device's Home button: frontboardd sends
 * the foreground app home, and a double press opens the app switcher. */
static const unsigned short UIKitHomeKeyCode = 0x73; /* kVK_Home */

@interface UIKitHostApplication : NSApplication
@end

@implementation UIKitHostApplication

- (void)sendEvent:(NSEvent *)event
{
	if ([event type] == NSKeyDown && [event keyCode] == UIKitHomeKeyCode) {
		/* Off the main thread, in order: frontboardd times the presses to
		 * spot a double press, so they must not wait behind drawing. */
		static dispatch_queue_t queue;
		static dispatch_once_t once;
		dispatch_once(&once, ^{
			queue = dispatch_queue_create("UIKit.HomeButton", DISPATCH_QUEUE_SERIAL);
		});
		if (![event isARepeat])
			dispatch_async(queue, ^{
				[[FBSSystemService sharedService] sendHomeButtonPress];
			});
		return;
	}
	[super sendEvent:event];
}

@end

static UIApplication *sSharedApplication;
static id<UIApplicationDelegate> sDelegateStorage;

@implementation UIApplication {
	UIApplicationState _state;
	FBSWorkspace *_workspace;
	NSArray<NSWindow *> *_hiddenWindows;
}

- (id<UIApplicationDelegate>)delegate
{
	return sDelegateStorage;
}

- (void)setDelegate:(id<UIApplicationDelegate>)delegate
{
	sDelegateStorage = delegate;
}

+ (UIApplication *)sharedApplication
{
	if (sSharedApplication == nil)
		sSharedApplication = [[UIApplication alloc] init];
	return sSharedApplication;
}

- (instancetype)init
{
	if ((self = [super init]))
		_state = UIApplicationStateInactive;
	return self;
}

- (UIApplicationState)applicationState
{
	return _state;
}

- (void)ui_notify:(SEL)selector name:(NSString *)name
{
	id<UIApplicationDelegate> delegate = [self delegate];
	if ([delegate respondsToSelector:selector])
		((void (*)(id, SEL, UIApplication *))objc_msgSend)(delegate, selector, self);
	[[NSNotificationCenter defaultCenter] postNotificationName:name object:self];
}

- (void)ui_becomeActive
{
	if (_state == UIApplicationStateActive)
		return;
	if (_state == UIApplicationStateBackground) {
		[self ui_notify:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification];
		for (NSWindow *window in _hiddenWindows)
			[window orderFront:nil];
		_hiddenWindows = nil;
	}
	_state = UIApplicationStateActive;
	[self ui_notify:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification];
}

- (void)ui_enterBackground
{
	if (_state == UIApplicationStateBackground)
		return;
	if (_state == UIApplicationStateActive) {
		_state = UIApplicationStateInactive;
		[self ui_notify:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification];
	}
	_state = UIApplicationStateBackground;
	[self ui_notify:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification];

	/* Off screen while in the background, as iOS does; back on return. */
	NSMutableArray<NSWindow *> *hidden = [NSMutableArray array];
	for (NSWindow *window in [NSApp windows]) {
		if ([window isVisible]) {
			[hidden addObject:window];
			[window orderOut:nil];
		}
	}
	_hiddenWindows = hidden;
}

#pragma mark - FBSWorkspaceDelegate

- (void)workspace:(FBSWorkspace *)workspace didChangeApplicationState:(FBSApplicationState)state
{
	if (state == FBSApplicationStateForeground)
		[self ui_becomeActive];
	else if (state == FBSApplicationStateBackground)
		[self ui_enterBackground];
}

- (void)workspaceDidRequestTermination:(FBSWorkspace *)workspace
{
	[NSApp terminate:nil];
}

- (void)workspaceDidDisconnect:(FBSWorkspace *)workspace
{
	_workspace = nil;
	[self ui_becomeActive];
}

- (void)run
{
	[NSApp run];
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	id<UIApplicationDelegate> delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)])
		[delegate application:self didFinishLaunchingWithOptions:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidFinishLaunchingNotification object:self];

	/* With frontboardd, wait for it to say whether we are in front. */
	NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier] ?: [[NSProcessInfo processInfo] processName];
	_workspace = [FBSWorkspace checkInWithBundleIdentifier:bundleIdentifier delegate:self queue:dispatch_get_main_queue()];
	if (_workspace == nil)
		[self ui_becomeActive];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	if (_state == UIApplicationStateActive) {
		_state = UIApplicationStateInactive;
		[self ui_notify:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification];
	}
	[self ui_notify:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification];
}

/* Terminate when the run loop asks, instead of falling through to AppKit's
 * last-window handling. */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	return NSTerminateNow;
}

@end

int UIApplicationMain(int argc, char *argv[], NSString *principalClassName, NSString *delegateClassName)
{
	/* iOS ignores these; the delegate is instantiated by name instead. */
	(void)argc;
	(void)argv;
	(void)principalClassName;

	@autoreleasepool {
		[UIKitHostApplication sharedApplication];

		UIApplication *application = [UIApplication sharedApplication];
		[NSApp setDelegate:application];

		if (delegateClassName != nil) {
			Class delegateClass = NSClassFromString(delegateClassName);
			if (delegateClass != Nil) {
				id delegate = [[delegateClass alloc] init];
				sDelegateStorage = delegate;
				application.delegate = delegate;
			}
		}

		[NSApp run];
	}
	return 0;
}
