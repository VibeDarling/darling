/* frontboardd end to end: it launches two installed UIKit apps, switches
   the foreground between them, sends one home and terminates both, and
   each app must see exactly the UIApplicationDelegate callbacks iOS would
   deliver, in order. Usage: ios-frontboard-lite <probe app binary>, built
   from ios-frontboard-lite-app.m. See ios-frontboard-lite.md. */

#import <Foundation/Foundation.h>
#import <FrontBoardServices/FrontBoardServices.h>
#include <spawn.h>
#include <signal.h>
#include <unistd.h>
#include <sys/wait.h>

extern char **environ;

static int failures;
#define CHECK(cond, ...) do { BOOL ok_ = (cond); printf("%s ", ok_ ? "PASS" : "FAIL"); printf(__VA_ARGS__); printf("\n"); fflush(stdout); if (!ok_) failures++; } while (0)

#define AppA @"org.darlinghq.lifecycle.a"
#define AppB @"org.darlinghq.lifecycle.b"

static NSString *logPath(NSString *bundleIdentifier)
{
	return [NSString stringWithFormat:@"/private/tmp/%@.log", bundleIdentifier];
}

/* The callbacks an app has logged so far, in order. */
static NSArray<NSString *> *callbacks(NSString *bundleIdentifier)
{
	NSString *log = [NSString stringWithContentsOfFile:logPath(bundleIdentifier) encoding:NSUTF8StringEncoding error:NULL];
	NSMutableArray *result = [NSMutableArray array];
	for (NSString *line in [log componentsSeparatedByString:@"\n"]) {
		NSArray *words = [line componentsSeparatedByString:@" "];
		if ([words count] >= 3 && [words[0] isEqualToString:@"LIFECYCLE"])
			[result addObject:words[2]];
	}
	return result;
}

static BOOL waitFor(NSString *bundleIdentifier, NSArray<NSString *> *expected, double seconds)
{
	for (double waited = 0; waited < seconds; waited += 0.1) {
		if ([callbacks(bundleIdentifier) isEqualToArray:expected])
			return YES;
		usleep(100000);
	}
	return NO;
}

static NSString *joined(NSArray<NSString *> *list)
{
	return [list componentsJoinedByString:@","];
}

static FBSApplicationState stateOf(NSString *bundleIdentifier)
{
	for (NSDictionary *process in [[FBSSystemService sharedService] applicationStates])
		if ([process[@"bundleIdentifier"] isEqualToString:bundleIdentifier])
			return [process[@"state"] integerValue];
	return FBSApplicationStateUnknown;
}

static NSError *openApp(NSString *bundleIdentifier)
{
	NSDictionary *debug = @{ FBSDebugOptionKeyStandardOutPath: logPath(bundleIdentifier) };
	__block NSError *result = nil;
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	[[FBSSystemService sharedService] openApplication:bundleIdentifier
		options:[FBSOpenApplicationOptions optionsWithDictionary:@{ FBSOpenApplicationOptionKeyDebuggingOptions: debug }]
		withResult:^(NSError *error) {
			result = error;
			dispatch_semaphore_signal(done);
		}];
	dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
	return result;
}

static void terminateApp(NSString *bundleIdentifier)
{
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	[[FBSSystemService sharedService] terminateApplication:bundleIdentifier forReason:1 andReport:NO withDescription:@"test" completion:^{
		dispatch_semaphore_signal(done);
	}];
	dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
}

static BOOL install(NSString *bundleIdentifier, NSString *name, NSString *binary)
{
	NSString *app = [NSHomeDirectory() stringByAppendingFormat:@"/Applications/%@.app", name];
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm removeItemAtPath:app error:NULL];
	NSDictionary *info = @{ @"CFBundleIdentifier": bundleIdentifier, @"CFBundleExecutable": name,
		@"CFBundleName": name, @"CFBundlePackageType": @"APPL" };
	return [fm createDirectoryAtPath:app withIntermediateDirectories:YES attributes:nil error:NULL]
		&& [fm copyItemAtPath:binary toPath:[app stringByAppendingPathComponent:name] error:NULL]
		&& [info writeToFile:[app stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
}

/* For screenshots: FBL_PAUSE=<seconds> holds each foreground switch. */
static void pause_(const char *what)
{
	const char *pause = getenv("FBL_PAUSE");
	if (pause != NULL) {
		printf("PAUSE %s\n", what);
		fflush(stdout);
		sleep(atoi(pause));
	}
}

int main(int argc, char **argv)
{
	@autoreleasepool {
		if (argc < 2) {
			fprintf(stderr, "usage: %s <probe app binary>\n", argv[0]);
			return 2;
		}
		NSString *probe = [NSString stringWithUTF8String:argv[1]];
		CHECK(install(AppA, @"LifecycleA", probe) && install(AppB, @"LifecycleB", probe), "installed LifecycleA.app and LifecycleB.app");

		CHECK([[FBSSystemService sharedService] applicationStates] == nil, "no frontboardd before we start one");
		char *daemonArgv[] = { "/usr/libexec/frontboardd", "--no-system-app", NULL };
		pid_t daemon = 0;
		CHECK(posix_spawn(&daemon, daemonArgv[0], NULL, NULL, daemonArgv, environ) == 0, "started frontboardd (%d)", daemon);
		BOOL up = NO;
		for (int i = 0; i < 200 && !up; i++) {
			usleep(50000);
			up = [[FBSSystemService sharedService] applicationStates] != nil;
		}
		CHECK(up, "frontboardd answers on %s", getenv("FRONTBOARD_SOCKET") ?: "/private/var/run/frontboardd.sock");

		NSError *error = openApp(AppA);
		CHECK(error == nil, "open A: %s", [[error description] UTF8String]);
		NSArray *a = @[ @"didFinishLaunching", @"didBecomeActive" ];
		CHECK(waitFor(AppA, a, 60), "A launched and active: %s", [joined(callbacks(AppA)) UTF8String]);
		CHECK(stateOf(AppA) == FBSApplicationStateForeground, "A is in the foreground");
		pause_("A in front");

		error = openApp(AppB);
		CHECK(error == nil, "open B: %s", [[error description] UTF8String]);
		NSArray *b = @[ @"didFinishLaunching", @"didBecomeActive" ];
		CHECK(waitFor(AppB, b, 60), "B launched and active: %s", [joined(callbacks(AppB)) UTF8String]);
		a = [a arrayByAddingObjectsFromArray:@[ @"willResignActive", @"didEnterBackground" ]];
		CHECK(waitFor(AppA, a, 20), "A went to the background: %s", [joined(callbacks(AppA)) UTF8String]);
		CHECK(stateOf(AppA) == FBSApplicationStateBackground && stateOf(AppB) == FBSApplicationStateForeground, "B in front, A behind");
		pid_t pidA = [[FBSSystemService sharedService] pidForApplication:AppA];
		pause_("B in front");

		error = openApp(AppA);
		CHECK(error == nil && [[FBSSystemService sharedService] pidForApplication:AppA] == pidA, "open A again reuses pid %d", pidA);
		a = [a arrayByAddingObjectsFromArray:@[ @"willEnterForeground", @"didBecomeActive" ]];
		CHECK(waitFor(AppA, a, 20), "A came back: %s", [joined(callbacks(AppA)) UTF8String]);
		b = [b arrayByAddingObjectsFromArray:@[ @"willResignActive", @"didEnterBackground" ]];
		CHECK(waitFor(AppB, b, 20), "B went to the background: %s", [joined(callbacks(AppB)) UTF8String]);
		pause_("A in front again");

		CHECK([[FBSSystemService sharedService] backgroundForegroundApplication], "home");
		a = [a arrayByAddingObjectsFromArray:@[ @"willResignActive", @"didEnterBackground" ]];
		CHECK(waitFor(AppA, a, 20), "home sent A to the background: %s", [joined(callbacks(AppA)) UTF8String]);
		CHECK(stateOf(AppA) == FBSApplicationStateBackground && stateOf(AppB) == FBSApplicationStateBackground, "nothing in front");

		terminateApp(AppA);
		terminateApp(AppB);
		a = [a arrayByAddingObject:@"willTerminate"];
		b = [b arrayByAddingObject:@"willTerminate"];
		CHECK(waitFor(AppA, a, 5), "A terminated: %s", [joined(callbacks(AppA)) UTF8String]);
		CHECK(waitFor(AppB, b, 5), "B terminated: %s", [joined(callbacks(AppB)) UTF8String]);
		CHECK([[[FBSSystemService sharedService] applicationStates] count] == 0
			&& [[FBSSystemService sharedService] pidForApplication:AppA] == 0, "frontboardd knows no apps any more");

		error = openApp(@"org.darlinghq.lifecycle.missing");
		CHECK([error code] == FBSOpenApplicationErrorCodeNotFound, "missing app: %s", [[error localizedFailureReason] UTF8String]);

		kill(daemon, SIGTERM);
		waitpid(daemon, NULL, 0);
		printf("%s: %d failure(s)\n", failures ? "FAILED" : "OK", failures);
	}
	return failures != 0;
}
