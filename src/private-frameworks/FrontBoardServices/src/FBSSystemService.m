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
#include <spawn.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/wait.h>

extern char **environ;

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
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *root in FBSApplicationSearchPaths()) {
		for (NSString *entry in [fm contentsOfDirectoryAtPath:root error:NULL]) {
			NSString *path = [root stringByAppendingPathComponent:entry];
			NSArray<NSString *> *candidates = @[ path ];
			if (![[entry pathExtension] isEqualToString:@"app"]) {
				NSMutableArray *nested = [NSMutableArray array];
				for (NSString *inner in [fm contentsOfDirectoryAtPath:path error:NULL])
					if ([[inner pathExtension] isEqualToString:@"app"])
						[nested addObject:[path stringByAppendingPathComponent:inner]];
				candidates = nested;
			}
			for (NSString *candidate in candidates) {
				NSBundle *bundle = [NSBundle bundleWithPath:candidate];
				if ([[bundle bundleIdentifier] isEqualToString:bundleIdentifier])
					return bundle;
			}
		}
	}
	return nil;
}

- (RBSProcessHandle *)fbs_runningProcessForApplication:(NSString *)bundleIdentifier
{
	return [RBSProcessHandle handleForPredicate:[RBSProcessPredicate predicateMatchingBundleIdentifier:bundleIdentifier] error:NULL];
}

- (NSError *)fbs_launch:(NSBundle *)bundle options:(NSDictionary *)options
{
	NSString *executable = [bundle executablePath];
	if (executable == nil)
		return FBSOpenError(FBSOpenApplicationErrorCodeLaunchFailed, [NSString stringWithFormat:@"%@ has no executable", [bundle bundlePath]]);

	NSDictionary *debug = options[FBSOpenApplicationOptionKeyDebuggingOptions];
	NSMutableArray<NSString *> *arguments = [NSMutableArray arrayWithObject:executable];
	[arguments addObjectsFromArray:debug[FBSDebugOptionKeyArguments] ?: @[]];

	/* Start from the raw environ, not NSProcessInfo: Darling's loader hides
	   its own __mldr_* variables from the latter, and exec needs them. */
	NSDictionary<NSString *, NSString *> *overrides = debug[FBSDebugOptionKeyEnvironment] ?: @{};
	NSMutableArray<NSString *> *environment = [NSMutableArray array];
	for (char **entry = environ; *entry != NULL; entry++) {
		NSString *string = [NSString stringWithUTF8String:*entry];
		NSRange equals = [string rangeOfString:@"="];
		if (string == nil || (equals.location != NSNotFound && overrides[[string substringToIndex:equals.location]] != nil))
			continue;
		[environment addObject:string];
	}
	[overrides enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
		[environment addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
	}];

	posix_spawn_file_actions_t actions;
	posix_spawn_file_actions_init(&actions);
	if (debug[FBSDebugOptionKeyStandardOutPath] != nil)
		posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, [debug[FBSDebugOptionKeyStandardOutPath] fileSystemRepresentation], O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (debug[FBSDebugOptionKeyStandardErrorPath] != nil)
		posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, [debug[FBSDebugOptionKeyStandardErrorPath] fileSystemRepresentation], O_WRONLY | O_CREAT | O_TRUNC, 0644);

	size_t argc = [arguments count];
	char **argv = calloc(argc + 1, sizeof(char *));
	for (size_t i = 0; i < argc; i++)
		argv[i] = strdup([arguments[i] UTF8String]);
	size_t envc = [environment count];
	char **envp = calloc(envc + 1, sizeof(char *));
	for (size_t i = 0; i < envc; i++)
		envp[i] = strdup([environment[i] UTF8String]);

	pid_t pid;
	int rc = posix_spawn(&pid, argv[0], &actions, NULL, argv, envp);
	posix_spawn_file_actions_destroy(&actions);
	for (size_t i = 0; i < argc; i++)
		free(argv[i]);
	free(argv);
	for (size_t i = 0; i < envc; i++)
		free(envp[i]);
	free(envp);

	if (rc != 0)
		return FBSOpenError(FBSOpenApplicationErrorCodeLaunchFailed, [NSString stringWithFormat:@"posix_spawn %@: %s", executable, strerror(rc)]);

	/* We are its parent, so reap it, or it lingers as a zombie that still
	   looks alive to kill(pid, 0). */
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		int status;
		while (waitpid(pid, &status, 0) < 0 && errno == EINTR)
			;
	});
	return nil;
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
		if ([bundleIdentifier length] == 0) {
			error = FBSOpenError(FBSOpenApplicationErrorCodeInvalidRequest, @"No bundle identifier");
		} else if ([self fbs_runningProcessForApplication:bundleIdentifier] != nil) {
			/* Already running. Bringing it to the front is the display
			   owner's job, and there is none to ask yet. */
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
	RBSProcessHandle *handle = [self fbs_runningProcessForApplication:bundleIdentifier];
	return handle != nil ? [handle pid] : 0;
}

- (void)terminateApplication:(NSString *)bundleIdentifier forReason:(NSInteger)reason andReport:(BOOL)report withDescription:(NSString *)description
{
	[self terminateApplication:bundleIdentifier forReason:reason andReport:report withDescription:description completion:nil];
}

- (void)terminateApplication:(NSString *)bundleIdentifier forReason:(NSInteger)reason andReport:(BOOL)report withDescription:(NSString *)description completion:(void (^)(void))completion
{
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
