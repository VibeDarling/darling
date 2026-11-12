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

#ifndef _DarlingBoard_H_
#define _DarlingBoard_H_

/* DarlingBoard: Darling's own interface between apps, the home screen
   (SpringBoard-lite) and frontboardd, the daemon that owns the application
   lifecycle. It is private to Darling: no guest app links it, and none of
   its names imitate Apple's. UIKit, SpringBoard-lite, SpringBoardServices,
   LaunchServices, frontboardd and usernotificationsd use it.

   When frontboardd runs, requests go to it over the socket described in
   DBWire.h. When it does not, DBApplicationService does the work in the
   calling process: it finds installed apps on disk, spawns them, and looks
   running ones up in the process table. */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* Keys of the options dictionary of -openApplication:options:completion:. */
/* NSNumber (BOOL): launch the app, or leave it, in the background. */
extern NSString * const DBOpenApplicationOptionSuspended;
/* NSDictionary of the DBDebugOption keys below. */
extern NSString * const DBOpenApplicationOptionDebugging;

/* NSArray of NSString: arguments after the executable path. */
extern NSString * const DBDebugOptionArguments;
/* NSDictionary of NSString: variables to add to, or override in, the
   launching process's environment. */
extern NSString * const DBDebugOptionEnvironment;
/* NSString: files to send the app's standard output and error to. */
extern NSString * const DBDebugOptionStandardOutPath;
extern NSString * const DBDebugOptionStandardErrorPath;

extern NSErrorDomain const DBOpenApplicationErrorDomain;

typedef NS_ENUM(NSInteger, DBOpenApplicationError) {
	DBOpenApplicationErrorInvalidRequest = 1,
	DBOpenApplicationErrorNotFound = 2,
	DBOpenApplicationErrorLaunchFailed = 3,
};

/* Where installed apps are looked for: each directory's *.app, and one level
   deeper for the iOS container layout (/var/containers/Bundle/Application/<UUID>/X.app). */
extern NSArray<NSString *> *DBApplicationSearchPaths(void);
/* Every app bundle in those directories, in a stable order. */
extern NSArray<NSBundle *> *DBInstalledApplications(void);
/* The system app: the home screen, which frontboardd launches when it
   starts and brings back for the Home button. */
extern NSString * const DBSystemApplicationPath;
extern NSString * const DBSystemApplicationBundleIdentifier;

/* Pids of the processes whose executable lies inside an installed bundle
   with this identifier (the nearest enclosing .app). */
extern NSArray<NSNumber *> *DBProcessesForApplication(NSString *bundleIdentifier);
/* Whether pid names a process that has not exited; a zombie has. */
extern BOOL DBProcessIsAlive(pid_t pid);

/* An app's place in the lifecycle, as frontboardd reports it. The values
   travel over the wire. */
typedef NS_ENUM(NSInteger, DBApplicationState) {
	DBApplicationStateUnknown = 0,
	DBApplicationStateForeground = 1,
	DBApplicationStateBackground = 2,
};

@interface DBApplicationService : NSObject
+ (instancetype)sharedService;

/* The installed bundle for an identifier, the system app included. */
- (nullable NSBundle *)bundleForApplication:(NSString *)bundleIdentifier;

/* Launch an app, or bring the running one to the front unless the options
   ask for DBOpenApplicationOptionSuspended. The completion runs on a
   background queue. */
- (void)openApplication:(NSString *)bundleIdentifier options:(nullable NSDictionary<NSString *, id> *)options completion:(nullable void (^)(NSError * _Nullable error))completion;
/* Hand a URL to whichever service handles its scheme. Only frontboardd can
   do this; without it the completion gets DBOpenApplicationErrorNotFound. */
- (void)openURL:(NSURL *)url completion:(nullable void (^)(NSError * _Nullable error))completion;

/* The app's pid, or 0 when it is not running. */
- (pid_t)pidOfApplication:(NSString *)bundleIdentifier;
/* With frontboardd, the app gets to run applicationWillTerminate: first,
   and the completion runs once it has exited. Without, it gets SIGTERM. */
- (void)terminateApplication:(NSString *)bundleIdentifier completion:(nullable void (^)(void))completion;

/* The rest need frontboardd, and return NO or nil without it. */
/* Send the foreground app to the background. */
- (BOOL)backgroundForegroundApplication;
/* bundleIdentifier, pid and state (DBApplicationState) of each app
   frontboardd knows about. */
- (nullable NSArray<NSDictionary *> *)applicationStates;
/* A press of the Home button: frontboardd brings the system app to the
   front and tells it about the press; two presses close together are a
   double press. */
- (BOOL)sendHomeButtonPress;
@end

@class DBAppConnection;

@protocol DBAppConnectionDelegate <NSObject>
- (void)appConnection:(DBAppConnection *)connection didChangeApplicationState:(DBApplicationState)state;
- (void)appConnectionDidRequestTermination:(DBAppConnection *)connection;
@optional
/* frontboardd went away; the app is on its own again. */
- (void)appConnectionDidDisconnect:(DBAppConnection *)connection;
@end

/* An app's own connection to frontboardd, over which it learns when it
   moves between foreground and background and when to terminate. */
@interface DBAppConnection : NSObject
/* nil when no frontboardd is running. Delegate calls arrive on queue. */
+ (nullable instancetype)checkInWithBundleIdentifier:(NSString *)bundleIdentifier delegate:(id<DBAppConnectionDelegate>)delegate queue:(dispatch_queue_t)queue;
@property (nonatomic, readonly) DBApplicationState applicationState;
- (void)invalidate;
@end

/* Posted on the delegate queue for each frontboardd event DBAppConnection
   does not turn into a delegate call; userInfo is the event. The system app
   gets {event: "button", button: "home", count: 1 or 2} for Home button
   presses. */
extern NSNotificationName const DBAppConnectionEventNotification;

NS_ASSUME_NONNULL_END

#endif
