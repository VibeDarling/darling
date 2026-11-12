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
#import <UIKit/UIWindow.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSEvent.h>
#import <DarlingBoard/DarlingBoard.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSDate.h>
#import <objc/message.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIScreen.h>
#import "UIKitPrivate.h"
#import <dlfcn.h>

/* Jailbreak tweaks: SubstrateLoader loads the ones whose filters match
 * this app, as Cydia Substrate does in every iOS process. By the time
 * UIKit's initializer runs, every class at launch is registered. */
__attribute__((constructor))
static void UIKitLoadTweaks(void)
{
	dlopen("/usr/lib/substrate/SubstrateLoader.dylib", RTLD_LAZY);
}

NSString *const UIApplicationDidFinishLaunchingNotification = @"UIApplicationDidFinishLaunchingNotification";
NSString *const UIApplicationDidBecomeActiveNotification = @"UIApplicationDidBecomeActiveNotification";
NSString *const UIApplicationWillResignActiveNotification = @"UIApplicationWillResignActiveNotification";
NSString *const UIApplicationDidEnterBackgroundNotification = @"UIApplicationDidEnterBackgroundNotification";
NSString *const UIApplicationWillEnterForegroundNotification = @"UIApplicationWillEnterForegroundNotification";
NSString *const UIApplicationWillTerminateNotification = @"UIApplicationWillTerminateNotification";

/* -[NSApplication run] delivers the AppKit delegate callbacks; UIApplication
 * implements them and forwards to the iOS delegate, which never sees AppKit.
 * frontboardd's lifecycle events arrive through DBAppConnection. */
@interface UIApplication () <DBAppConnectionDelegate>
- (void)uikitDidFinishLaunching;
- (void)uikitWillTerminate;
@end

/* AppKit's delegate.  A separate object, so that an app's UIApplication
 * subclass (which may have its own -applicationDidFinishLaunching:) never
 * receives AppKit's callbacks. */
@interface UIKitAppKitDelegate : NSObject <NSApplicationDelegate>
@end

@implementation UIKitAppKitDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[[UIApplication sharedApplication] uikitDidFinishLaunching];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[[UIApplication sharedApplication] uikitWillTerminate];
}

/* Terminate when the run loop asks, instead of falling through to AppKit's
 * last-window handling. */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	return NSTerminateNow;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return NO;
}

@end

/* The keyboard's Home key is the device's Home button: frontboardd sends
 * the foreground app home, and a double press opens the app switcher. */
static const unsigned short UIKitHomeKeyCode = 0x73; /* kVK_Home */

@interface UIKitHostApplication : NSApplication
@end

/* How many runs of the main run loop are in progress, and the runs AppKit's
 * event loop is waiting for events in (see UIKitDeliverEvents). */
static NSUInteger sRunDepth;
static NSUInteger sEventLoopRuns[16];
static NSUInteger sEventLoops;

@implementation UIKitHostApplication

- (NSEvent *)nextEventMatchingMask:(NSEventMask)mask untilDate:(NSDate *)date inMode:(NSRunLoopMode)mode dequeue:(BOOL)dequeue
{
	BOOL main = [NSThread isMainThread] && sEventLoops < sizeof(sEventLoopRuns) / sizeof(*sEventLoopRuns);
	if (main)
		sEventLoopRuns[sEventLoops++] = sRunDepth + 1;
	NSEvent *event = [super nextEventMatchingMask:mask untilDate:date inMode:mode dequeue:dequeue];
	if (main)
		sEventLoops--;
	return event;
}

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
				[[DBApplicationService sharedService] sendHomeButtonPress];
			});
		return;
	}
	if ([event type] == NSKeyDown && UIKitPerformKeyCommand(event))
		return;
	[super sendEvent:event];
}

@end

static UIApplication *sSharedApplication;
static id<UIApplicationDelegate> sDelegateStorage;

@implementation UIApplication {
	UIApplicationState _state;
	DBAppConnection *_lifecycle;
	NSArray<NSWindow *> *_hiddenWindows;
	BOOL _networkActivityIndicatorVisible;
	BOOL _statusBarHidden;
	BOOL _idleTimerDisabled;
	BOOL _applicationSupportsShakeToEdit;
	NSInteger _statusBarStyle;
	NSInteger _applicationIconBadgeNumber;
	NSInteger _ignoringInteractionEvents;
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
	/* With scenes, the scene's delegate hears of these instead; the
	 * notifications are still posted. */
	if (!UIKitUsesScenes() && [delegate respondsToSelector:selector])
		((void (*)(id, SEL, UIApplication *))objc_msgSend)(delegate, selector, self);
	[[NSNotificationCenter defaultCenter] postNotificationName:name object:self];
}

- (void)ui_becomeActive
{
	if (_state == UIApplicationStateActive)
		return;
	if (_state == UIApplicationStateBackground) {
		UIKitScenesEnterForeground();
		[self ui_notify:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification];
		/* Not those the app hid itself while in the background. */
		for (NSWindow *window in _hiddenWindows)
			if (![[window contentView] isKindOfClass:[UIWindow class]] || ![(UIWindow *)[window contentView] isHidden])
				[window orderFront:nil];
		_hiddenWindows = nil;
	}
	_state = UIApplicationStateActive;
	UIKitScenesBecomeActive();
	[self ui_notify:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification];
}

- (void)ui_enterBackground
{
	if (_state == UIApplicationStateBackground)
		return;
	if (_state == UIApplicationStateActive) {
		_state = UIApplicationStateInactive;
		UIKitScenesResignActive();
		[self ui_notify:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification];
	}
	_state = UIApplicationStateBackground;
	UIKitScenesEnterBackground();
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

#pragma mark - DBAppConnectionDelegate

- (void)appConnection:(DBAppConnection *)connection didChangeApplicationState:(DBApplicationState)state
{
	if (state == DBApplicationStateForeground)
		[self ui_becomeActive];
	else if (state == DBApplicationStateBackground)
		[self ui_enterBackground];
}

- (void)appConnectionDidRequestTermination:(DBAppConnection *)connection
{
	[NSApp terminate:nil];
}

- (void)appConnectionDidDisconnect:(DBAppConnection *)connection
{
	_lifecycle = nil;
	[self ui_becomeActive];
}

- (void)run
{
	[NSApp run];
}

#pragma mark - Launch and termination

- (void)uikitDidFinishLaunching
{
	/* With scenes, the scene's storyboard replaces the main one. */
	BOOL scenes = UIKitUsesScenes();
	if (!scenes)
		UIKitLoadMainInterface(self);
	id<UIApplicationDelegate> delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(application:willFinishLaunchingWithOptions:)])
		[(id)delegate application:self willFinishLaunchingWithOptions:nil];
	if ([delegate respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)])
		[delegate application:self didFinishLaunchingWithOptions:nil];
	else if ([delegate respondsToSelector:@selector(applicationDidFinishLaunching:)])
		/* iPhone OS 2's callback, which takes the application. */
		((void (*)(id, SEL, id))objc_msgSend)(delegate, @selector(applicationDidFinishLaunching:), self);
	if (scenes)
		UIKitConnectMainScene(self);
	else
		UIKitShowMainInterface(self);
	[[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidFinishLaunchingNotification object:self];
	UIKitForwardLocalNotifications(self);

	/* With frontboardd, wait for it to say whether we are in front. */
	NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier] ?: [[NSProcessInfo processInfo] processName];
	_lifecycle = [DBAppConnection checkInWithBundleIdentifier:bundleIdentifier delegate:self queue:dispatch_get_main_queue()];
	if (_lifecycle == nil)
		[self ui_becomeActive];
}

- (void)uikitWillTerminate
{
	if (_state == UIApplicationStateActive) {
		_state = UIApplicationStateInactive;
		UIKitScenesResignActive();
		[self ui_notify:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification];
	}
	UIKitScenesDisconnect();
	[self ui_notify:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification];
}

#pragma mark - Status bar, windows and the rest

- (CGRect)statusBarFrame
{
	if (_statusBarHidden)
		return CGRectZero;
	return CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, UIKitStatusBarHeight);
}

- (UIInterfaceOrientation)statusBarOrientation { return UIInterfaceOrientationPortrait; }
- (void)setStatusBarOrientation:(UIInterfaceOrientation)orientation { }
- (void)setStatusBarOrientation:(UIInterfaceOrientation)orientation animated:(BOOL)animated { }
- (BOOL)isStatusBarHidden { return _statusBarHidden; }
- (void)setStatusBarHidden:(BOOL)hidden { _statusBarHidden = hidden; }
- (void)setStatusBarHidden:(BOOL)hidden animated:(BOOL)animated { _statusBarHidden = hidden; }
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(NSInteger)animation { _statusBarHidden = hidden; }
- (NSInteger)statusBarStyle { return _statusBarStyle; }
- (void)setStatusBarStyle:(NSInteger)style { _statusBarStyle = style; }
- (void)setStatusBarStyle:(NSInteger)style animated:(BOOL)animated { _statusBarStyle = style; }
- (void)setStatusBarShowsProgress:(BOOL)shows { }
- (BOOL)isNetworkActivityIndicatorVisible { return _networkActivityIndicatorVisible; }
- (void)setNetworkActivityIndicatorVisible:(BOOL)visible { _networkActivityIndicatorVisible = visible; }
- (BOOL)isIdleTimerDisabled { return _idleTimerDisabled; }
- (void)setIdleTimerDisabled:(BOOL)disabled { _idleTimerDisabled = disabled; }
- (BOOL)applicationSupportsShakeToEdit { return _applicationSupportsShakeToEdit; }
- (void)setApplicationSupportsShakeToEdit:(BOOL)supports { _applicationSupportsShakeToEdit = supports; }
- (NSInteger)applicationIconBadgeNumber { return _applicationIconBadgeNumber; }
- (void)setApplicationIconBadgeNumber:(NSInteger)number { _applicationIconBadgeNumber = number; }
- (void)setApplicationBadgeString:(NSString *)badge { }
- (void)beginIgnoringInteractionEvents { _ignoringInteractionEvents++; }
- (void)endIgnoringInteractionEvents { if (_ignoringInteractionEvents > 0) _ignoringInteractionEvents--; }
- (BOOL)isIgnoringInteractionEvents { return _ignoringInteractionEvents > 0; }
- (NSInteger)userInterfaceLayoutDirection { return 0; }
- (NSString *)preferredContentSizeCategory { return @"UICTContentSizeCategoryL"; }
- (NSTimeInterval)backgroundTimeRemaining { return 600; }
- (NSUInteger)beginBackgroundTaskWithExpirationHandler:(void (^)(void))handler { return 1; }
- (NSUInteger)beginBackgroundTaskWithName:(NSString *)name expirationHandler:(void (^)(void))handler { return 1; }
- (void)endBackgroundTask:(NSUInteger)identifier { }
- (void)registerForRemoteNotificationTypes:(NSUInteger)types { }
- (void)registerForRemoteNotifications { }
- (void)registerUserNotificationSettings:(id)settings { }

- (UIWindow *)keyWindow
{
	return [UIWindow uikitKeyWindow];
}

- (NSArray *)windows
{
	return [UIWindow uikitWindows];
}

- (BOOL)sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event
{
	if (target == nil || ![target respondsToSelector:action])
		return NO;
	((void (*)(id, SEL, id))objc_msgSend)(target, action, sender);
	return YES;
}

- (BOOL)canOpenURL:(NSURL *)url
{
	NSString *scheme = [[url scheme] lowercaseString];
	return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] || [scheme isEqualToString:@"mailto"];
}

- (BOOL)openURL:(NSURL *)url
{
	if (url == nil)
		return NO;
	[[DBApplicationService sharedService] openURL:url completion:nil];
	return YES;
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(void (^)(BOOL success))completion
{
	BOOL opened = [self openURL:url];
	if (completion != nil)
		completion(opened);
}

- (void)openURL:(NSURL *)url asPanel:(BOOL)panel
{
	[self openURL:url];
}

- (BOOL)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended
{
	if (identifier == nil)
		return NO;
	[[DBApplicationService sharedService] openApplication:identifier options:nil completion:nil];
	return YES;
}

/* Back to the home screen, as the Home button does. */
- (void)suspend
{
	[[DBApplicationService sharedService] sendHomeButtonPress];
}

- (void)suspendReturningToLastApp:(BOOL)returning
{
	[self suspend];
}

- (void)terminateWithSuccess
{
	[NSApp terminate:nil];
}

@end

/*
 * What iOS's Core Animation does before the main run loop sleeps: draw what
 * changed. AppKit schedules a redraw with a run loop timer that does not
 * wake the loop when queued from a callout (a main-queue block, where UIKit
 * lays out), so the views laid out there would otherwise wait for the next
 * event to appear.
 */
static void UIKitDisplayBeforeWaiting(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
	@autoreleasepool {
		for (NSWindow *window in [NSApp windows])
			if ([window isVisible] && [window viewsNeedDisplay])
				[window displayIfNeeded];
	}
}

/*
 * iOS delivers events from the main run loop, so an app that runs it itself
 * (SDL's loop, with CFRunLoopRunInMode) gets them. AppKit queues them until
 * its event loop asks for one. So when a run of the loop that is not AppKit's
 * event loop is about to wait or ends, the events queued are sent.
 */
static void UIKitDeliverEvents(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
	static BOOL delivering;
	if (activity == kCFRunLoopEntry) {
		sRunDepth++;
		return;
	}
	BOOL own = sEventLoops > 0 && sEventLoopRuns[sEventLoops - 1] == sRunDepth;
	if (!own && !delivering && NSApp != nil) {
		delivering = YES;
		@autoreleasepool {
			NSEvent *event;
			while ((event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantPast]
			                                      inMode:NSDefaultRunLoopMode dequeue:YES]) != nil)
				[NSApp sendEvent:event];
		}
		delivering = NO;
	}
	if (activity == kCFRunLoopExit)
		sRunDepth--;
}

static void UIKitInstallDisplayObserver(void)
{
	/* Entering first and leaving last, around everything else: the run loop's depth. */
	CFRunLoopObserverRef events = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopEntry, true, -2000000,
		UIKitDeliverEvents, NULL);
	CFRunLoopAddObserver(CFRunLoopGetMain(), events, kCFRunLoopCommonModes);
	CFRelease(events);
	/* Before drawing, so what the events changed is drawn. */
	events = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeWaiting | kCFRunLoopExit, true, 1000000,
		UIKitDeliverEvents, NULL);
	CFRunLoopAddObserver(CFRunLoopGetMain(), events, kCFRunLoopCommonModes);
	CFRelease(events);

	/* After everything else that runs before waiting, as Core Animation's commit. */
	CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeWaiting | kCFRunLoopExit, true, 2000000,
		UIKitDisplayBeforeWaiting, NULL);
	CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
	CFRelease(observer);
}

int UIApplicationMain(int argc, char *argv[], NSString *principalClassName, NSString *delegateClassName)
{
	/* The command line reaches the app through NSProcessInfo. */
	(void)argc;
	(void)argv;

	@autoreleasepool {
		[UIKitHostApplication sharedApplication];

		/* The principal class (from the argument or Info.plist) is the
		 * shared application; it may also be its own delegate. */
		if (principalClassName == nil)
			principalClassName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSPrincipalClass"];
		Class principalClass = principalClassName != nil ? NSClassFromString(principalClassName) : Nil;
		if (principalClass == Nil || ![principalClass isSubclassOfClass:[UIApplication class]])
			principalClass = [UIApplication class];
		if (sSharedApplication == nil)
			sSharedApplication = [[principalClass alloc] init];
		UIApplication *application = sSharedApplication;

		static UIKitAppKitDelegate *appKitDelegate;
		appKitDelegate = [[UIKitAppKitDelegate alloc] init];
		[NSApp setDelegate:appKitDelegate];

		if (delegateClassName != nil) {
			Class delegateClass = NSClassFromString(delegateClassName);
			if (delegateClass == principalClass || [application isKindOfClass:delegateClass]) {
				sDelegateStorage = application;
			} else if (delegateClass != Nil) {
				id delegate = [[delegateClass alloc] init];
				sDelegateStorage = delegate;
			}
		}

		UIKitInstallDisplayObserver();
		[NSApp run];
	}
	return 0;
}
