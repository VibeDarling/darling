/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIAPPLICATION_H
#define UIKIT_UIAPPLICATION_H

#import <Foundation/NSObjCRuntime.h>
#import <UIKit/UIResponder.h>

#import <UIKit/UIGeometry.h>

@class NSString, NSArray, NSURL, NSDictionary, UIWindow, UIEvent;
@protocol UIApplicationDelegate;

typedef NS_ENUM(NSInteger, UIApplicationState) {
	UIApplicationStateActive,
	UIApplicationStateInactive,
	UIApplicationStateBackground,
};

extern NSString *const UIApplicationDidFinishLaunchingNotification;
extern NSString *const UIApplicationDidBecomeActiveNotification;
extern NSString *const UIApplicationWillResignActiveNotification;
extern NSString *const UIApplicationDidEnterBackgroundNotification;
extern NSString *const UIApplicationWillEnterForegroundNotification;
extern NSString *const UIApplicationWillTerminateNotification;

/*
 * When frontboardd runs, it decides when the app is in the foreground or the
 * background, and UIApplication turns its word into the delegate callbacks
 * and notifications; a backgrounded app's windows are taken off screen.
 * Without frontboardd the app becomes active once it has finished launching
 * and stays so.
 */
@interface UIApplication : UIResponder

+ (UIApplication *)sharedApplication;

@property (nonatomic, assign) id<UIApplicationDelegate> delegate;
@property (nonatomic, readonly) UIApplicationState applicationState;
@property (nonatomic, readonly) CGRect statusBarFrame;
@property (nonatomic, getter=isStatusBarHidden) BOOL statusBarHidden;

/* Drain the main run loop, as -[NSApplication run] does. */
- (void)run;

- (BOOL)canOpenURL:(NSURL *)url;
- (BOOL)openURL:(NSURL *)url;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(void (^)(BOOL success))completion;
@property (nonatomic, readonly) UIWindow *keyWindow;
@property (nonatomic, readonly) NSArray *windows;
- (BOOL)sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event;
@property (nonatomic, readonly) NSInteger statusBarStyle;

@end

#import <Foundation/Foundation.h>

@class UIScene, UISceneSession, UILocalNotification;

/* One scene, for the whole screen (see UIScene.h). */
@interface UIApplication (UIScene)
@property (nonatomic, readonly) NSSet<UIScene *> *connectedScenes;
@property (nonatomic, readonly) NSSet<UISceneSession *> *openSessions;
@property (nonatomic, readonly) BOOL supportsMultipleScenes;
- (void)requestSceneSessionActivation:(UISceneSession *)sceneSession userActivity:(NSUserActivity *)userActivity options:(id)options errorHandler:(void (^)(NSError *error))errorHandler;
- (void)requestSceneSessionDestruction:(UISceneSession *)sceneSession options:(id)options errorHandler:(void (^)(NSError *error))errorHandler;
- (void)requestSceneSessionRefresh:(UISceneSession *)sceneSession;
@end

/* iOS 4's local notifications, kept with UserNotifications'. */
@interface UIApplication (UILocalNotifications)
- (void)scheduleLocalNotification:(UILocalNotification *)notification;
- (void)presentLocalNotificationNow:(UILocalNotification *)notification;
- (void)cancelLocalNotification:(UILocalNotification *)notification;
- (void)cancelAllLocalNotifications;
@property (nonatomic, copy) NSArray<UILocalNotification *> *scheduledLocalNotifications;
@end

/*
 * Entry point.  principalClassName is accepted for source compatibility and
 * ignored; delegateClassName names the UIApplicationDelegate subclass to
 * instantiate, as on iOS.  Returns only after the application terminates.
 */
int UIApplicationMain(int argc, char *argv[], NSString *principalClassName, NSString *delegateClassName);

#endif /* UIKIT_UIAPPLICATION_H */
