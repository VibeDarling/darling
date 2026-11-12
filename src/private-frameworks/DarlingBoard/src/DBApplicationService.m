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


#import <DarlingBoard/DarlingBoard.h>
#import "DBWire.h"
#include <signal.h>
#include <errno.h>
#include <unistd.h>
#include <sys/wait.h>

/* Option keys and their values are Darling's own: both ends of the wire
   are in this tree. */
NSString * const DBOpenApplicationOptionSuspended = @"suspended";
NSString * const DBOpenApplicationOptionDebugging = @"debugging";

NSString * const DBDebugOptionArguments = @"arguments";
NSString * const DBDebugOptionEnvironment = @"environment";
NSString * const DBDebugOptionStandardOutPath = @"standardOutPath";
NSString * const DBDebugOptionStandardErrorPath = @"standardErrorPath";

NSErrorDomain const DBOpenApplicationErrorDomain = @"DBOpenApplicationErrorDomain";

NSString * const DBSystemApplicationPath = @"/System/Library/CoreServices/SpringBoard.app";
/* SpringBoard-lite's CFBundleIdentifier (src/SpringBoard/Info.plist). */
NSString * const DBSystemApplicationBundleIdentifier = @"com.apple.springboard";

static NSError *DBOpenError(DBOpenApplicationError code, NSString *reason)
{
	return [NSError errorWithDomain:DBOpenApplicationErrorDomain code:code
		userInfo:@{ NSLocalizedFailureReasonErrorKey: reason }];
}

NSArray<NSString *> *DBApplicationSearchPaths(void)
{
	return @[
		@"/Applications",
		@"/var/containers/Bundle/Application",
		[NSHomeDirectory() stringByAppendingPathComponent:@"Applications"],
	];
}

NSArray<NSBundle *> *DBInstalledApplications(void)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray<NSBundle *> *bundles = [NSMutableArray array];
	for (NSString *root in DBApplicationSearchPaths()) {
		NSArray<NSString *> *entries = [[fm contentsOfDirectoryAtPath:root error:NULL] sortedArrayUsingSelector:@selector(compare:)];
		for (NSString *entry in entries) {
			NSString *path = [root stringByAppendingPathComponent:entry];
			NSArray<NSString *> *candidates = @[ path ];
			/* Installed apps sit one directory deeper, in a container. */
			if (![[entry pathExtension] isEqualToString:@"app"]) {
				NSMutableArray *nested = [NSMutableArray array];
				for (NSString *inner in [fm contentsOfDirectoryAtPath:path error:NULL])
					if ([[inner pathExtension] isEqualToString:@"app"])
						[nested addObject:[path stringByAppendingPathComponent:inner]];
				candidates = nested;
			}
			for (NSString *candidate in candidates) {
				NSBundle *bundle = [NSBundle bundleWithPath:candidate];
				if ([bundle bundleIdentifier] != nil)
					[bundles addObject:bundle];
			}
		}
	}
	return bundles;
}

/* The live processes running an app, this one excluded. */
static NSArray<NSNumber *> *DBLiveProcessesForApplication(NSString *bundleIdentifier)
{
	NSMutableArray<NSNumber *> *live = [NSMutableArray array];
	for (NSNumber *pid in DBProcessesForApplication(bundleIdentifier))
		if ([pid intValue] != getpid() && DBProcessIsAlive([pid intValue]))
			[live addObject:pid];
	return live;
}

/* frontboardd's reply as an NSError, or nil for success. */
static NSError *DBErrorFromReply(NSDictionary *reply)
{
	if (reply[@"error"] == nil)
		return nil;
	return DBOpenError([reply[@"code"] integerValue], reply[@"error"]);
}

@implementation DBApplicationService

+ (instancetype)sharedService
{
	static DBApplicationService *service;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		service = [[self alloc] init];
	});
	return service;
}

- (NSBundle *)bundleForApplication:(NSString *)bundleIdentifier
{
	if ([bundleIdentifier isEqualToString:DBSystemApplicationBundleIdentifier]) {
		NSBundle *bundle = [NSBundle bundleWithPath:DBSystemApplicationPath];
		if ([[bundle bundleIdentifier] isEqualToString:bundleIdentifier])
			return bundle;
	}
	for (NSBundle *bundle in DBInstalledApplications())
		if ([[bundle bundleIdentifier] isEqualToString:bundleIdentifier])
			return bundle;
	return nil;
}

- (NSError *)db_launch:(NSBundle *)bundle options:(NSDictionary *)options
{
	pid_t pid;
	NSError *error = DBSpawnApplication(bundle, options, &pid);
	if (error != nil)
		return error;

	/* We are its parent, so reap it, or it lingers as a zombie that still
	   looks alive to kill(pid, 0). */
	[NSThread detachNewThreadSelector:@selector(db_reap:) toTarget:[self class] withObject:@(pid)];
	return nil;
}

/* On a thread of its own: blocked in waitpid on a GCD worker it would take
   one of the few threads GCD runs per CPU. */
+ (void)db_reap:(NSNumber *)pid
{
	int status;
	while (waitpid([pid intValue], &status, 0) < 0 && errno == EINTR)
		;
}

+ (void)db_awaitTermination:(NSArray *)arguments
{
	int fd = [arguments[0] intValue];
	DBWireReceive(fd);
	close(fd);
	if (arguments[1] != [NSNull null])
		((void (^)(void))arguments[1])();
}

- (void)openApplication:(NSString *)bundleIdentifier options:(NSDictionary<NSString *, id> *)options completion:(void (^)(NSError *))completion
{
	NSDictionary *dictionary = options ?: @{};
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSError *error = nil;
		NSDictionary *reply = [bundleIdentifier length] > 0
			? DBWireRequest(@{ @"op": @"open", @"bundleIdentifier": bundleIdentifier, @"options": DBWireOptions(dictionary) })
			: nil;
		if (reply != nil) {
			/* frontboardd launched or activated it. */
			error = DBErrorFromReply(reply);
		} else if ([bundleIdentifier length] == 0) {
			error = DBOpenError(DBOpenApplicationErrorInvalidRequest, @"No bundle identifier");
		} else if ([DBLiveProcessesForApplication(bundleIdentifier) count] > 0) {
			/* Already running. Bringing it to the front is frontboardd's
			   job, and none is running. */
		} else {
			NSBundle *bundle = [self bundleForApplication:bundleIdentifier];
			if (bundle == nil)
				error = DBOpenError(DBOpenApplicationErrorNotFound, [NSString stringWithFormat:@"Application \"%@\" is not installed", bundleIdentifier]);
			else
				error = [self db_launch:bundle options:dictionary];
		}
		if (completion != nil)
			completion(error);
	});
}

- (void)openURL:(NSURL *)url completion:(void (^)(NSError *))completion
{
	NSString *string = [url absoluteString];
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSError *error;
		if (string == nil) {
			error = DBOpenError(DBOpenApplicationErrorInvalidRequest, @"No URL");
		} else {
			/* frontboardd finds the service for the URL's scheme. */
			NSDictionary *reply = DBWireRequest(@{ @"op": @"openURL", @"url": string });
			error = reply != nil ? DBErrorFromReply(reply)
				: DBOpenError(DBOpenApplicationErrorNotFound, [NSString stringWithFormat:@"Nothing can open %@", string]);
		}
		if (completion != nil)
			completion(error);
	});
}

- (pid_t)pidOfApplication:(NSString *)bundleIdentifier
{
	NSDictionary *reply = DBWireRequest(@{ @"op": @"pid", @"bundleIdentifier": bundleIdentifier ?: @"" });
	if (reply != nil)
		return [reply[@"pid"] intValue];
	return [[DBLiveProcessesForApplication(bundleIdentifier) firstObject] intValue];
}

- (void)terminateApplication:(NSString *)bundleIdentifier completion:(void (^)(void))completion
{
	int fd = DBWireConnect();
	if (fd >= 0) {
		/* frontboardd lets the app run applicationWillTerminate: and replies
		   once it has exited. */
		DBWireSend(fd, @{ @"op": @"terminate", @"bundleIdentifier": bundleIdentifier ?: @"" });
		[NSThread detachNewThreadSelector:@selector(db_awaitTermination:) toTarget:[self class]
			withObject:@[ @(fd), completion ? [completion copy] : [NSNull null] ]];
		return;
	}
	for (NSNumber *pid in DBLiveProcessesForApplication(bundleIdentifier))
		kill([pid intValue], SIGTERM);
	if (completion != nil)
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), completion);
}

- (BOOL)backgroundForegroundApplication
{
	return DBWireRequest(@{ @"op": @"home" }) != nil;
}

- (NSArray<NSDictionary *> *)applicationStates
{
	return DBWireRequest(@{ @"op": @"list" })[@"processes"];
}

- (BOOL)sendHomeButtonPress
{
	return DBWireRequest(@{ @"op": @"button", @"button": @"home" }) != nil;
}

@end
