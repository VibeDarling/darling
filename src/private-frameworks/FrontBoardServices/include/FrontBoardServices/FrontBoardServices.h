/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef _FrontBoardServices_H_
#define _FrontBoardServices_H_

/* FrontBoardServices, best effort from class-dumped headers. On iOS these
   calls go over XPC to FrontBoard inside SpringBoard; here there is no
   FrontBoard yet, so FBSSystemService does the work in the calling process:
   it finds installed apps on disk and spawns them, and asks
   RunningBoardServices about running ones. */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#include <mach/mach.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const FBSOpenApplicationOptionKeyActivateSuspended;
extern NSString * const FBSOpenApplicationOptionKeyDebuggingOptions;
extern NSString * const FBSOpenApplicationOptionKeyLaunchOrigin;
extern NSString * const FBSOpenApplicationOptionKeyPayloadOptions;
extern NSString * const FBSOpenApplicationOptionKeyPayloadURL;
extern NSString * const FBSOpenApplicationOptionKeyPromptUnlockDevice;
extern NSString * const FBSOpenApplicationOptionKeyUnlockDevice;

/* Keys of the FBSOpenApplicationOptionKeyDebuggingOptions dictionary. */
extern NSString * const FBSDebugOptionKeyArguments;
extern NSString * const FBSDebugOptionKeyEnvironment;
extern NSString * const FBSDebugOptionKeyStandardOutPath;
extern NSString * const FBSDebugOptionKeyStandardErrorPath;

extern NSErrorDomain const FBSOpenApplicationErrorDomain;

typedef NS_ENUM(NSInteger, FBSOpenApplicationErrorCode) {
	FBSOpenApplicationErrorCodeNone = 0,
	FBSOpenApplicationErrorCodeUnsupported = 1,
	FBSOpenApplicationErrorCodeInvalidRequest = 2,
	FBSOpenApplicationErrorCodeNotFound = 4,
	FBSOpenApplicationErrorCodeLaunchFailed = 6,
};

/* Where installed apps are looked for: each directory's *.app, and one level
   deeper for the iOS container layout (/var/containers/Bundle/Application/<UUID>/X.app). */
extern NSArray<NSString *> *FBSApplicationSearchPaths(void);
/* Every app bundle in those directories, in a stable order. */
extern NSArray<NSBundle *> *FBSInstalledApplications(void);
/* Where the system app (systemApplicationBundleIdentifier, the home
   screen) is installed; frontboardd launches it when it starts. */
extern NSString *const FBSSystemApplicationPath;

@interface FBSOpenApplicationOptions : NSObject <NSCopying>
+ (instancetype)optionsWithDictionary:(nullable NSDictionary<NSString *, id> *)dictionary;
@property (nonatomic, copy) NSDictionary<NSString *, id> *dictionary;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;

- (void)openApplication:(NSString *)bundleIdentifier options:(nullable FBSOpenApplicationOptions *)options withResult:(nullable void (^)(NSError * _Nullable error))result;
- (void)openApplication:(NSString *)bundleIdentifier options:(nullable FBSOpenApplicationOptions *)options clientPort:(mach_port_t)port withResult:(nullable void (^)(NSError * _Nullable error))result;
- (void)openURL:(NSURL *)url application:(NSString *)bundleIdentifier options:(nullable FBSOpenApplicationOptions *)options clientPort:(mach_port_t)port withResult:(nullable void (^)(NSError * _Nullable error))result;

- (BOOL)canOpenApplication:(NSString *)bundleIdentifier reason:(nullable NSInteger *)reason;
- (pid_t)pidForApplication:(NSString *)bundleIdentifier;
- (void)terminateApplication:(NSString *)bundleIdentifier forReason:(NSInteger)reason andReport:(BOOL)report withDescription:(nullable NSString *)description;
- (void)terminateApplication:(NSString *)bundleIdentifier forReason:(NSInteger)reason andReport:(BOOL)report withDescription:(nullable NSString *)description completion:(nullable void (^)(void))completion;

- (mach_port_t)createClientPort;
- (void)cleanupClientPort:(mach_port_t)port;

- (nullable NSString *)systemApplicationBundleIdentifier;

/* Not in Apple's API: the installed bundle for an identifier. */
- (nullable NSBundle *)bundleForApplication:(NSString *)bundleIdentifier;
@end

/* What frontboardd tells an app about itself. */
typedef NS_ENUM(NSInteger, FBSApplicationState) {
	FBSApplicationStateUnknown = 0,
	FBSApplicationStateForeground = 1,
	FBSApplicationStateBackground = 2,
};

@class FBSWorkspace;

@protocol FBSWorkspaceDelegate <NSObject>
- (void)workspace:(FBSWorkspace *)workspace didChangeApplicationState:(FBSApplicationState)state;
- (void)workspaceDidRequestTermination:(FBSWorkspace *)workspace;
@optional
/* frontboardd went away; the app is on its own again. */
- (void)workspaceDidDisconnect:(FBSWorkspace *)workspace;
@end

/* An app's connection to frontboardd. Not Apple's FBSWorkspace interface,
   which is built around scenes: this carries only the application
   lifecycle, the part UIKit needs to deliver the delegate callbacks. */
@interface FBSWorkspace : NSObject
/* nil when no frontboardd is running. Delegate calls arrive on queue. */
+ (nullable instancetype)checkInWithBundleIdentifier:(NSString *)bundleIdentifier delegate:(id<FBSWorkspaceDelegate>)delegate queue:(dispatch_queue_t)queue;
@property (nonatomic, readonly) FBSApplicationState applicationState;
- (void)invalidate;
@end

/* Posted on the delegate queue for each frontboardd event FBSWorkspace does
   not turn into a delegate call; userInfo is the event. The system app gets
   {event: "button", button: "home", count: 1 or 2} for Home button presses. */
extern NSNotificationName const FBSWorkspaceEventNotification;

/* Not in Apple's API: ask frontboardd to background the foreground app, as
   the home button does. NO when no frontboardd is running. */
@interface FBSSystemService (FBSHome)
- (BOOL)backgroundForegroundApplication;
/* bundleIdentifier, pid and state (FBSApplicationState) of each app
   frontboardd knows about; nil when none is running. */
- (nullable NSArray<NSDictionary *> *)applicationStates;
/* A press of the Home button: frontboardd brings the system app (the home
   screen) to the front and tells it about the press; two presses close
   together are a double press. */
- (BOOL)sendHomeButtonPress;
@end

typedef NS_ENUM(NSInteger, FBSSceneLevel) {
	FBSSceneLevelNormal = 1,
};

@interface FBSSceneSettings : NSObject <NSCopying, NSMutableCopying>
@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly) NSInteger interfaceOrientation;
@property (nonatomic, readonly) CGFloat level;
@property (nonatomic, readonly, getter=isForeground) BOOL foreground;
@property (nonatomic, readonly, getter=isBackgrounded) BOOL backgrounded;
@property (nonatomic, readonly, getter=isOccluded) BOOL occluded;
@end

@interface FBSMutableSceneSettings : FBSSceneSettings
@property (nonatomic) CGRect frame;
@property (nonatomic) NSInteger interfaceOrientation;
@property (nonatomic) CGFloat level;
@property (nonatomic, getter=isForeground) BOOL foreground;
@property (nonatomic, getter=isBackgrounded) BOOL backgrounded;
@property (nonatomic, getter=isOccluded) BOOL occluded;
@end

NS_ASSUME_NONNULL_END

#endif
