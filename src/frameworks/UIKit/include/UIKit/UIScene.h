/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISCENE_H
#define UIKIT_UISCENE_H

#import <UIKit/UIResponder.h>
#import <UIKit/UIGeometry.h>
#import <UIKit/UITraitCollection.h>
#import <CoreGraphics/CGGeometry.h>

@class UIScene, UIWindowScene, UISceneSession, UISceneConnectionOptions, UIWindow, UIScreen, UIStoryboard;
@class NSUserActivity, NSURL, NSSet, NSDictionary, NSArray, NSString;

typedef NSString *UISceneSessionRole;
extern UISceneSessionRole const UIWindowSceneSessionRoleApplication;
extern UISceneSessionRole const UIWindowSceneSessionRoleExternalDisplayNonInteractive;
extern UISceneSessionRole const UIWindowSceneSessionRoleExternalDisplay;

typedef NS_ENUM(NSInteger, UISceneActivationState) {
	UISceneActivationStateUnattached = -1,
	UISceneActivationStateForegroundActive,
	UISceneActivationStateForegroundInactive,
	UISceneActivationStateBackground,
};

extern NSNotificationName const UISceneWillConnectNotification;
extern NSNotificationName const UISceneDidDisconnectNotification;
extern NSNotificationName const UISceneDidActivateNotification;
extern NSNotificationName const UISceneWillDeactivateNotification;
extern NSNotificationName const UISceneWillEnterForegroundNotification;
extern NSNotificationName const UISceneDidEnterBackgroundNotification;

/* Which scene class, delegate and storyboard a session gets. */
@interface UISceneConfiguration : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)configurationWithName:(NSString *)name sessionRole:(UISceneSessionRole)sessionRole;
- (instancetype)initWithName:(NSString *)name sessionRole:(UISceneSessionRole)sessionRole;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) UISceneSessionRole role;
@property (nonatomic) Class sceneClass;
@property (nonatomic) Class delegateClass;
@property (nonatomic, strong) UIStoryboard *storyboard;
@end

@interface UISceneSession : NSObject <NSSecureCoding>
@property (nonatomic, readonly, weak) UIScene *scene;
@property (nonatomic, readonly) UISceneSessionRole role;
@property (nonatomic, readonly, copy) UISceneConfiguration *configuration;
@property (nonatomic, readonly) NSString *persistentIdentifier;
@property (nonatomic, strong) NSUserActivity *stateRestorationActivity;
@property (nonatomic, copy) NSDictionary<NSString *, id> *userInfo;
@end

@interface UIOpenURLContext : NSObject
@property (nonatomic, readonly, copy) NSURL *URL;
@end

/* What the scene was opened for: nothing more than a launch, here. */
@interface UISceneConnectionOptions : NSObject
@property (nonatomic, readonly, copy) NSSet<UIOpenURLContext *> *URLContexts;
@property (nonatomic, readonly) NSString *sourceApplication;
@property (nonatomic, readonly) NSString *handoffUserActivityType;
@property (nonatomic, readonly, copy) NSSet<NSUserActivity *> *userActivities;
@property (nonatomic, readonly) id notificationResponse;
@property (nonatomic, readonly) id shortcutItem;
@property (nonatomic, readonly) id cloudKitShareMetadata;
@end

@protocol UISceneDelegate <NSObject>
@optional
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions;
- (void)sceneDidDisconnect:(UIScene *)scene;
- (void)sceneDidBecomeActive:(UIScene *)scene;
- (void)sceneWillResignActive:(UIScene *)scene;
- (void)sceneWillEnterForeground:(UIScene *)scene;
- (void)sceneDidEnterBackground:(UIScene *)scene;
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts;
- (NSUserActivity *)stateRestorationActivityForScene:(UIScene *)scene;
- (void)scene:(UIScene *)scene willContinueUserActivityWithType:(NSString *)userActivityType;
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity;
@end

@interface UIScene : UIResponder
- (instancetype)initWithSession:(UISceneSession *)session connectionOptions:(UISceneConnectionOptions *)connectionOptions;
@property (nonatomic, readonly) UISceneSession *session;
@property (nonatomic, strong) id<UISceneDelegate> delegate;
@property (nonatomic, readonly) UISceneActivationState activationState;
@property (nonatomic, copy) NSString *title;
- (void)openURL:(NSURL *)url options:(id)options completionHandler:(void (^)(BOOL success))completion;
@end

@interface UIStatusBarManager : NSObject
@property (nonatomic, readonly) NSInteger statusBarStyle;
@property (nonatomic, readonly, getter=isStatusBarHidden) BOOL statusBarHidden;
@property (nonatomic, readonly) CGRect statusBarFrame;
@end

@interface UIWindowScene : UIScene <UITraitEnvironment>
@property (nonatomic, readonly) UIScreen *screen;
@property (nonatomic, readonly) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, readonly) NSArray<UIWindow *> *windows;
@property (nonatomic, readonly) UIWindow *keyWindow;
@property (nonatomic, readonly) UIStatusBarManager *statusBarManager;
@property (nonatomic, readonly) UITraitCollection *traitCollection;
@end

@protocol UIWindowSceneDelegate <UISceneDelegate>
@optional
@property (nonatomic, strong) UIWindow *window;
- (void)windowScene:(UIWindowScene *)windowScene didUpdateCoordinateSpace:(id)previousCoordinateSpace interfaceOrientation:(UIInterfaceOrientation)previousInterfaceOrientation traitCollection:(UITraitCollection *)previousTraitCollection;
- (void)windowScene:(UIWindowScene *)windowScene performActionForShortcutItem:(id)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler;
@end

#endif /* UIKIT_UISCENE_H */
