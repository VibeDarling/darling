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

#import <FrontBoardServices/FrontBoardServices.h>
#import <RunningBoardServices/RunningBoardServices.h>
#import "FBSLite.h"
#include <signal.h>
#include <errno.h>
#include <sys/wait.h>


NSString * const FBSOpenApplicationOptionKeyActivateSuspended = @"__ActivateSuspended";
NSString * const FBSOpenApplicationOptionKeyDebuggingOptions = @"__DebugOptions";
NSString * const FBSOpenApplicationOptionKeyLaunchOrigin = @"__LaunchOrigin";
NSString * const FBSOpenApplicationOptionKeyPayloadOptions = @"__PayloadOptions";
NSString * const FBSOpenApplicationOptionKeyPayloadURL = @"__PayloadURL";
NSString * const FBSOpenApplicationOptionKeyPromptUnlockDevice = @"__PromptUnlockDevice";
NSString * const FBSOpenApplicationOptionKeyUnlockDevice = @"__UnlockDevice";

NSString * const FBSDebugOptionKeyArguments = @"__Arguments";
NSString * const FBSDebugOptionKeyEnvironment = @"__Environment";
NSString * const FBSDebugOptionKeyStandardOutPath = @"__StdoutPath";
NSString * const FBSDebugOptionKeyStandardErrorPath = @"__StderrPath";

NSErrorDomain const FBSOpenApplicationErrorDomain = @"FBSOpenApplicationErrorDomain";

static NSError *FBSOpenError(FBSOpenApplicationErrorCode code, NSString *reason)
{
	return [NSError errorWithDomain:FBSOpenApplicationErrorDomain code:code
		userInfo:@{ NSLocalizedFailureReasonErrorKey: reason }];
}

NSArray<NSString *> *FBSApplicationSearchPaths(void)
{
	return @[
		@"/Applications",
		@"/var/containers/Bundle/Application",
		[NSHomeDirectory() stringByAppendingPathComponent:@"Applications"],
	];
}

NSString *const FBSSystemApplicationPath = @"/System/Library/CoreServices/SpringBoard.app";

NSArray<NSBundle *> *FBSInstalledApplications(void)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray<NSBundle *> *bundles = [NSMutableArray array];
	for (NSString *root in FBSApplicationSearchPaths()) {
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

@implementation FBSOpenApplicationOptions

+ (instancetype)optionsWithDictionary:(NSDictionary<NSString *, id> *)dictionary
{
	FBSOpenApplicationOptions *options = [[self alloc] init];
	options.dictionary = dictionary ?: @{};
	return options;
}

- (id)copyWithZone:(NSZone *)zone
{
	return [[self class] optionsWithDictionary:_dictionary];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@>", [self class], _dictionary];
}

@end

@implementation FBSSystemService

+ (instancetype)sharedService
{
	static FBSSystemService *service;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		service = [[self alloc] init];
	});
	return service;
}

- (NSBundle *)bundleForApplication:(NSString *)bundleIdentifier
{
	if ([bundleIdentifier isEqualToString:[self systemApplicationBundleIdentifier]]) {
		NSBundle *bundle = [NSBundle bundleWithPath:FBSSystemApplicationPath];
		if ([[bundle bundleIdentifier] isEqualToString:bundleIdentifier])
			return bundle;
	}
	for (NSBundle *bundle in FBSInstalledApplications())
		if ([[bundle bundleIdentifier] isEqualToString:bundleIdentifier])
			return bundle;
	return nil;
}

- (RBSProcessHandle *)fbs_runningProcessForApplication:(NSString *)bundleIdentifier
{
	return [RBSProcessHandle handleForPredicate:[RBSProcessPredicate predicateMatchingBundleIdentifier:bundleIdentifier] error:NULL];
}

- (NSError *)fbs_launch:(NSBundle *)bundle options:(NSDictionary *)options
{
	pid_t pid;
	NSError *error = FBSLiteSpawnApplication(bundle, options, &pid);
	if (error != nil)
		return error;

	/* We are its parent, so reap it, or it lingers as a zombie that still
	   looks alive to kill(pid, 0). */
	[NSThread detachNewThreadSelector:@selector(fbs_reap:) toTarget:[self class] withObject:@(pid)];
	return nil;
}

/* On a thread of its own: blocked in waitpid on a GCD worker it would take
   one of the few threads GCD runs per CPU. */
+ (void)fbs_reap:(NSNumber *)pid
{
	int status;
	while (waitpid([pid intValue], &status, 0) < 0 && errno == EINTR)
		;
}

+ (void)fbs_awaitTermination:(NSArray *)arguments
{
	int fd = [arguments[0] intValue];
	FBSLiteReceive(fd);
	close(fd);
	if (arguments[1] != [NSNull null])
		((void (^)(void))arguments[1])();
}

/* frontboardd's reply as an NSError, or nil for success. */
static NSError *FBSErrorFromReply(NSDictionary *reply)
{
	if (reply[@"error"] == nil)
		return nil;
	return FBSOpenError([reply[@"code"] integerValue], reply[@"error"]);
}

- (void)openApplication:(NSString *)bundleIdentifier options:(FBSOpenApplicationOptions *)options withResult:(void (^)(NSError *))result
{
	[self openApplication:bundleIdentifier options:options clientPort:MACH_PORT_NULL withResult:result];
}

- (void)openApplication:(NSString *)bundleIdentifier options:(FBSOpenApplicationOptions *)options clientPort:(mach_port_t)port withResult:(void (^)(NSError *))result
{
	NSDictionary *dictionary = [options dictionary] ?: @{};
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSError *error = nil;
		NSDictionary *reply = [bundleIdentifier length] > 0
			? FBSLiteRequest(@{ @"op": @"open", @"bundleIdentifier": bundleIdentifier, @"options": FBSLiteWireOptions(dictionary) })
			: nil;
		if (reply != nil) {
			/* frontboardd launched or activated it. */
			error = FBSErrorFromReply(reply);
		} else if ([bundleIdentifier length] == 0) {
			error = FBSOpenError(FBSOpenApplicationErrorCodeInvalidRequest, @"No bundle identifier");
		} else if ([self fbs_runningProcessForApplication:bundleIdentifier] != nil) {
			/* Already running. Bringing it to the front is frontboardd's
			   job, and none is running. */
		} else {
			NSBundle *bundle = [self bundleForApplication:bundleIdentifier];
			if (bundle == nil)
				error = FBSOpenError(FBSOpenApplicationErrorCodeNotFound, [NSString stringWithFormat:@"Application \"%@\" is not installed", bundleIdentifier]);
			else
				error = [self fbs_launch:bundle options:dictionary];
		}
		if (result != nil)
			result(error);
	});
}

- (void)openURL:(NSURL *)url application:(NSString *)bundleIdentifier options:(FBSOpenApplicationOptions *)options clientPort:(mach_port_t)port withResult:(void (^)(NSError *))result
{
	NSMutableDictionary *dictionary = [[options dictionary] mutableCopy] ?: [NSMutableDictionary dictionary];
	if (url != nil)
		dictionary[FBSOpenApplicationOptionKeyPayloadURL] = url;
	[self openApplication:bundleIdentifier options:[FBSOpenApplicationOptions optionsWithDictionary:dictionary] clientPort:port withResult:result];
}

- (BOOL)canOpenApplication:(NSString *)bundleIdentifier reason:(NSInteger *)reason
{
	BOOL installed = [self bundleForApplication:bundleIdentifier] != nil || [self fbs_runningProcessForApplication:bundleIdentifier] != nil;
	if (reason != NULL)
		*reason = installed ? FBSOpenApplicationErrorCodeNone : FBSOpenApplicationErrorCodeNotFound;
	return installed;
}

- (pid_t)pidForApplication:(NSString *)bundleIdentifier
{
	NSDictionary *reply = FBSLiteRequest(@{ @"op": @"pid", @"bundleIdentifier": bundleIdentifier ?: @"" });
	if (reply != nil)
		return [reply[@"pid"] intValue];
	RBSProcessHandle *handle = [self fbs_runningProcessForApplication:bundleIdentifier];
	return handle != nil ? [handle pid] : 0;
}

- (void)terminateApplication:(NSString *)bundleIdentifier forReason:(NSInteger)reason andReport:(BOOL)report withDescription:(NSString *)description
{
	[self terminateApplication:bundleIdentifier forReason:reason andReport:report withDescription:description completion:nil];
}

- (void)terminateApplication:(NSString *)bundleIdentifier forReason:(NSInteger)reason andReport:(BOOL)report withDescription:(NSString *)description completion:(void (^)(void))completion
{
	int fd = FBSLiteConnect();
	if (fd >= 0) {
		/* frontboardd lets the app run applicationWillTerminate: and replies
		   once it has exited. */
		FBSLiteSend(fd, @{ @"op": @"terminate", @"bundleIdentifier": bundleIdentifier ?: @"" });
		[NSThread detachNewThreadSelector:@selector(fbs_awaitTermination:) toTarget:[self class]
			withObject:@[ @(fd), completion ? [completion copy] : [NSNull null] ]];
		return;
	}
	for (RBSProcessHandle *handle in [RBSProcessHandle handlesForPredicate:[RBSProcessPredicate predicateMatchingBundleIdentifier:bundleIdentifier]])
		if ([handle pid] != getpid())
			kill([handle pid], SIGTERM);
	if (completion != nil)
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), completion);
}

- (mach_port_t)createClientPort
{
	mach_port_t port = MACH_PORT_NULL;
	if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port) != KERN_SUCCESS)
		return MACH_PORT_NULL;
	mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
	return port;
}

- (void)cleanupClientPort:(mach_port_t)port
{
	if (port == MACH_PORT_NULL)
		return;
	mach_port_mod_refs(mach_task_self(), port, MACH_PORT_RIGHT_RECEIVE, -1);
	mach_port_deallocate(mach_task_self(), port);
}

- (NSString *)systemApplicationBundleIdentifier
{
	return @"com.apple.springboard";
}

@end
