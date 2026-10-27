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

/* frontboardd: the FrontBoard half of SpringBoard, reduced to what apps
   and a launcher need. It owns the application lifecycle: it launches
   installed apps, keeps at most one in the foreground, tells each checked-in
   app when it moves between foreground and background, and asks apps to
   terminate. It draws nothing itself. The system app (the home screen,
   SpringBoard.app) is what the user sees when no other app is in front:
   frontboardd launches it at startup, relaunches it if it dies, brings it
   back for the Home button and tells it about each press. The protocol
   is in FrontBoardServices' FBSLite.h. */

#import <Foundation/Foundation.h>
#import <FrontBoardServices/FrontBoardServices.h>
#import <RunningBoardServices/RunningBoardServices.h>
#import "FBSLite.h"
#include <sys/socket.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>
#include <unistd.h>
#include <pthread.h>
#include <time.h>

/* How long an app gets to run applicationWillTerminate: and exit. */
static const int64_t FBDTerminationGrace = 3 * NSEC_PER_SEC;
/* Two Home button presses this close together are a double press. */
static const uint64_t FBDDoublePressInterval = 400 * NSEC_PER_MSEC;
/* How long to wait before relaunching a system app that died. */
static const int64_t FBDSystemAppRelaunchDelay = 1 * NSEC_PER_SEC;

@interface FBDProcess : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic) pid_t pid;
@property (nonatomic) FBSApplicationState state;
@property (nonatomic) int eventFD;
@property (nonatomic, strong) NSMutableArray<void (^)(void)> *exitHandlers;
@end

@implementation FBDProcess

- (instancetype)init
{
	if ((self = [super init])) {
		_eventFD = -1;
		_exitHandlers = [NSMutableArray array];
	}
	return self;
}

@end

/* All state lives on this queue. */
static dispatch_queue_t sQueue;
static NSMutableArray<FBDProcess *> *sProcesses;
static NSString *sSystemBundleIdentifier;
static BOOL sLaunchSystemApp = YES;
static uint64_t sLastHomePress;

static void FBDLog(NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	fprintf(stderr, "frontboardd: %s\n", [line UTF8String]);
}

static NSString *FBDStateName(FBSApplicationState state)
{
	switch (state) {
		case FBSApplicationStateForeground: return @"foreground";
		case FBSApplicationStateBackground: return @"background";
		default: return @"unknown";
	}
}

static FBDProcess *FBDProcessWithBundleIdentifier(NSString *bundleIdentifier)
{
	for (FBDProcess *process in sProcesses)
		if ([process.bundleIdentifier isEqualToString:bundleIdentifier])
			return process;
	return nil;
}

static BOOL FBDIsSystem(FBDProcess *process)
{
	return [process.bundleIdentifier isEqualToString:sSystemBundleIdentifier];
}

static FBDProcess *FBDSystemProcess(void)
{
	return FBDProcessWithBundleIdentifier(sSystemBundleIdentifier);
}

static BOOL FBDHasForegroundApp(void)
{
	for (FBDProcess *process in sProcesses)
		if (!FBDIsSystem(process) && process.state == FBSApplicationStateForeground)
			return YES;
	return NO;
}

static FBDProcess *FBDProcessWithPid(pid_t pid)
{
	for (FBDProcess *process in sProcesses)
		if (process.pid == pid)
			return process;
	return nil;
}

static void FBDSendState(FBDProcess *process)
{
	if (process.eventFD >= 0)
		FBSLiteSend(process.eventFD, @{ @"event": @"state", @"state": @(process.state) });
}

static void FBDSetState(FBDProcess *process, FBSApplicationState state)
{
	if (process.state == state)
		return;
	FBDLog(@"%@ (%d): %@ -> %@", process.bundleIdentifier, process.pid, FBDStateName(process.state), FBDStateName(state));
	process.state = state;
	FBDSendState(process);
}

/* At most one app is in the foreground. */
static void FBDBringToForeground(FBDProcess *process)
{
	for (FBDProcess *other in sProcesses)
		if (other != process && other.state == FBSApplicationStateForeground)
			FBDSetState(other, FBSApplicationStateBackground);
	FBDSetState(process, FBSApplicationStateForeground);
}

/* Home: no app in front, so the system app is. */
static void FBDGoHome(void)
{
	for (FBDProcess *process in sProcesses)
		if (!FBDIsSystem(process) && process.state == FBSApplicationStateForeground)
			FBDSetState(process, FBSApplicationStateBackground);
	FBDProcess *system = FBDSystemProcess();
	if (system != nil)
		FBDSetState(system, FBSApplicationStateForeground);
}

static void FBDLaunchSystemApp(void);

static void FBDRemove(FBDProcess *process)
{
	if (![sProcesses containsObject:process])
		return;
	FBDLog(@"%@ (%d) exited", process.bundleIdentifier, process.pid);
	BOOL wasForeground = process.state == FBSApplicationStateForeground;
	[sProcesses removeObject:process];
	if (FBDIsSystem(process)) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, FBDSystemAppRelaunchDelay), sQueue, ^{
			FBDLaunchSystemApp();
		});
	} else if (wasForeground) {
		FBDGoHome();
	}
	if (process.eventFD >= 0) {
		shutdown(process.eventFD, SHUT_RDWR);
		process.eventFD = -1;
	}
	for (void (^handler)(void) in process.exitHandlers)
		handler();
	[process.exitHandlers removeAllObjects];
}

/* Connections and reapers block for as long as an app lives, so each gets
   a thread of its own: parked on GCD's global queues they would use up
   its few worker threads (about one per CPU) and stall everything else. */
static void *FBDThreadMain(void *block)
{
	void (^work)(void) = (__bridge_transfer void (^)(void))block;
	work();
	return NULL;
}

static void FBDDetach(void (^work)(void))
{
	pthread_t thread;
	pthread_attr_t attributes;
	pthread_attr_init(&attributes);
	pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
	pthread_create(&thread, &attributes, FBDThreadMain, (__bridge_retained void *)[work copy]);
	pthread_attr_destroy(&attributes);
}

static BOOL FBDIsAlive(pid_t pid)
{
	return [[RBSProcessHandle handleForIdentifier:[RBSProcessIdentifier identifierWithPid:pid] error:NULL] isValid];
}

static NSDictionary *FBDError(FBSOpenApplicationErrorCode code, NSString *reason)
{
	return @{ @"error": reason, @"code": @(code) };
}

static FBDProcess *FBDLaunch(NSString *bundleIdentifier, NSDictionary *options, NSDictionary **error)
{
	NSBundle *bundle = [[FBSSystemService sharedService] bundleForApplication:bundleIdentifier];
	if (bundle == nil) {
		*error = FBDError(FBSOpenApplicationErrorCodeNotFound, [NSString stringWithFormat:@"Application \"%@\" is not installed", bundleIdentifier]);
		return nil;
	}

	pid_t pid;
	NSError *spawnError = FBSLiteSpawnApplication(bundle, options, &pid);
	if (spawnError != nil) {
		*error = FBDError([spawnError code], [spawnError localizedFailureReason] ?: [spawnError description]);
		return nil;
	}

	FBDProcess *process = [[FBDProcess alloc] init];
	process.bundleIdentifier = bundleIdentifier;
	process.pid = pid;
	process.state = FBSApplicationStateBackground;
	[sProcesses addObject:process];
	FBDLog(@"launched %@ (%d)", bundleIdentifier, pid);

	/* We are its parent: reap it, which is also how we learn it exited. */
	FBDDetach(^{
		int status;
		while (waitpid(pid, &status, 0) < 0 && errno == EINTR)
			;
		dispatch_async(sQueue, ^{
			FBDRemove(process);
		});
	});
	return process;
}

static void FBDOpen(NSDictionary *request, void (^reply)(NSDictionary *))
{
	NSString *bundleIdentifier = request[@"bundleIdentifier"];
	NSDictionary *options = request[@"options"];
	BOOL suspended = [options[FBSOpenApplicationOptionKeyActivateSuspended] boolValue];

	FBDProcess *process = FBDProcessWithBundleIdentifier(bundleIdentifier);
	if (process != nil) {
		if (!suspended)
			FBDBringToForeground(process);
		reply(@{ @"pid": @(process.pid) });
		return;
	}

	NSDictionary *error = nil;
	process = FBDLaunch(bundleIdentifier, options, &error);
	if (process == nil) {
		reply(error);
		return;
	}
	if (!suspended)
		FBDBringToForeground(process);
	reply(@{ @"pid": @(process.pid) });
}

/* The home screen, if one is installed and not already running. It comes
   to the front only when no other app is there. */
static void FBDLaunchSystemApp(void)
{
	if (!sLaunchSystemApp || FBDSystemProcess() != nil)
		return;
	if ([[FBSSystemService sharedService] bundleForApplication:sSystemBundleIdentifier] == nil)
		return;
	NSDictionary *error = nil;
	FBDProcess *process = FBDLaunch(sSystemBundleIdentifier, nil, &error);
	if (process == nil)
		FBDLog(@"cannot launch the system app %@: %@", sSystemBundleIdentifier, error[@"error"]);
	else if (!FBDHasForegroundApp())
		FBDSetState(process, FBSApplicationStateForeground);
}

static void FBDHomeButton(void)
{
	uint64_t now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
	NSInteger count = sLastHomePress != 0 && now - sLastHomePress < FBDDoublePressInterval ? 2 : 1;
	/* A third quick press starts over rather than being another double. */
	FBDLog(@"home button, %ld press(es), %llu ms after the last", (long)count, sLastHomePress ? (unsigned long long)((now - sLastHomePress) / NSEC_PER_MSEC) : 0ULL);
	sLastHomePress = count == 2 ? 0 : now;
	FBDGoHome();
	FBDProcess *system = FBDSystemProcess();
	if (system.eventFD >= 0)
		FBSLiteSend(system.eventFD, @{ @"event": @"button", @"button": @"home", @"count": @(count) });
}

static void FBDTerminate(NSDictionary *request, void (^reply)(NSDictionary *))
{
	FBDProcess *process = FBDProcessWithBundleIdentifier(request[@"bundleIdentifier"]);
	if (process == nil) {
		reply(@{});
		return;
	}
	[process.exitHandlers addObject:^{
		reply(@{});
	}];
	if (process.eventFD >= 0) {
		FBSLiteSend(process.eventFD, @{ @"event": @"terminate" });
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, FBDTerminationGrace), sQueue, ^{
			if ([sProcesses containsObject:process]) {
				FBDLog(@"%@ (%d) did not exit; killing it", process.bundleIdentifier, process.pid);
				kill(process.pid, SIGKILL);
			}
		});
	} else {
		kill(process.pid, SIGTERM);
	}
}

static void FBDCheckIn(NSDictionary *request, int fd)
{
	pid_t pid = [request[@"pid"] intValue];
	FBDProcess *process = FBDProcessWithPid(pid);
	if (process == nil) {
		/* Started by someone else, most likely by hand: it is what the user
		   is looking at now. */
		process = [[FBDProcess alloc] init];
		process.bundleIdentifier = request[@"bundleIdentifier"];
		process.pid = pid;
		process.state = FBSApplicationStateBackground;
		[sProcesses addObject:process];
		if (!FBDIsSystem(process))
			FBDBringToForeground(process);
		else if (!FBDHasForegroundApp())
			FBDSetState(process, FBSApplicationStateForeground);
	}
	FBDLog(@"%@ (%d) checked in, %@", process.bundleIdentifier, pid, FBDStateName(process.state));
	process.eventFD = fd;
	FBDSendState(process);
}

static NSArray<NSDictionary *> *FBDList(void)
{
	NSMutableArray *list = [NSMutableArray array];
	for (FBDProcess *process in sProcesses)
		[list addObject:@{ @"bundleIdentifier": process.bundleIdentifier ?: @"", @"pid": @(process.pid), @"state": @(process.state) }];
	return list;
}

/* One thread per connection: read the request, handle it on sQueue. */
static void FBDServe(int fd)
{
	@autoreleasepool {
		NSDictionary *request = FBSLiteReceive(fd);
		NSString *op = request[@"op"];
		if (op == nil) {
			close(fd);
			return;
		}

		if ([op isEqualToString:@"checkin"]) {
			__block FBDProcess *process = nil;
			dispatch_sync(sQueue, ^{
				FBDCheckIn(request, fd);
				process = FBDProcessWithPid([request[@"pid"] intValue]);
			});
			/* The app sends nothing more; EOF means it is gone. */
			while (FBSLiteReceive(fd) != nil)
				;
			dispatch_sync(sQueue, ^{
				if (process.eventFD == fd)
					process.eventFD = -1;
				/* Apps we did not launch are not our children to reap. */
				if (!FBDIsAlive(process.pid))
					FBDRemove(process);
			});
			close(fd);
			return;
		}

		dispatch_semaphore_t done = dispatch_semaphore_create(0);
		__block NSDictionary *response = nil;
		void (^reply)(NSDictionary *) = ^(NSDictionary *message) {
			response = message;
			dispatch_semaphore_signal(done);
		};
		dispatch_async(sQueue, ^{
			if ([op isEqualToString:@"open"])
				FBDOpen(request, reply);
			else if ([op isEqualToString:@"terminate"])
				FBDTerminate(request, reply);
			else if ([op isEqualToString:@"pid"])
				reply(@{ @"pid": @(FBDProcessWithBundleIdentifier(request[@"bundleIdentifier"]).pid) });
			else if ([op isEqualToString:@"home"]) {
				FBDGoHome();
				reply(@{});
			} else if ([op isEqualToString:@"button"]) {
				if ([request[@"button"] isEqualToString:@"home"])
					FBDHomeButton();
				reply(@{});
			} else if ([op isEqualToString:@"list"])
				reply(@{ @"processes": FBDList() });
			else
				reply(@{ @"error": [NSString stringWithFormat:@"unknown request \"%@\"", op], @"code": @(FBSOpenApplicationErrorCodeInvalidRequest) });
		});
		dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
		FBSLiteSend(fd, response);
		close(fd);
	}
}

int main(int argc, char **argv)
{
	@autoreleasepool {
		signal(SIGPIPE, SIG_IGN);
		sQueue = dispatch_queue_create("frontboardd", DISPATCH_QUEUE_SERIAL);
		sProcesses = [NSMutableArray array];
		sSystemBundleIdentifier = [[FBSSystemService sharedService] systemApplicationBundleIdentifier];
		for (int i = 1; i < argc; i++) {
			if (strcmp(argv[i], "--no-system-app") == 0)
				sLaunchSystemApp = NO;
			else {
				fprintf(stderr, "usage: frontboardd [--no-system-app]\n");
				return 2;
			}
		}

		int listener = FBSLiteListen();
		if (listener < 0) {
			FBDLog(@"cannot listen on %@: %s", FBSLiteSocketPath(), strerror(errno));
			return 1;
		}
		FBDLog(@"listening on %@", FBSLiteSocketPath());
		dispatch_async(sQueue, ^{
			FBDLaunchSystemApp();
		});

		for (;;) {
			int fd = accept(listener, NULL, NULL);
			if (fd < 0) {
				if (errno == EINTR)
					continue;
				FBDLog(@"accept: %s", strerror(errno));
				return 1;
			}
			FBDDetach(^{
				FBDServe(fd);
			});
		}
	}
}
