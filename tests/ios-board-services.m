/* DarlingBoard without frontboardd: finding, launching, and terminating
   an installed app by bundle identifier, and the process lookups behind
   them. See ios-board-services.md. */

#import <Foundation/Foundation.h>
#import <DarlingBoard/DarlingBoard.h>
#include <mach-o/dyld.h>

/* The app DBApplicationService launches is this same binary, installed as
   ~/Applications/Sleeper.app (one of DBApplicationSearchPaths());
   run under that name it just sleeps until terminated. */
#define SleeperIdentifier @"com.example.sleeper"

static NSString *installSleeper(void)
{
	char path[4096];
	uint32_t size = sizeof(path);
	if (_NSGetExecutablePath(path, &size) != 0)
		return nil;
	NSString *app = [NSHomeDirectory() stringByAppendingPathComponent:@"Applications/Sleeper.app"];
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm removeItemAtPath:app error:NULL];
	if (![fm createDirectoryAtPath:app withIntermediateDirectories:YES attributes:nil error:NULL]
			|| ![fm copyItemAtPath:[NSString stringWithUTF8String:path] toPath:[app stringByAppendingPathComponent:@"Sleeper"] error:NULL])
		return nil;
	NSDictionary *info = @{ @"CFBundleIdentifier": SleeperIdentifier, @"CFBundleExecutable": @"Sleeper",
		@"CFBundleName": @"Sleeper", @"CFBundlePackageType": @"APPL" };
	if (![info writeToFile:[app stringByAppendingPathComponent:@"Info.plist"] atomically:YES])
		return nil;
	return app;
}

static int failures;
#define CHECK(cond, ...) do { BOOL ok_ = (cond); printf("%s ", ok_ ? "PASS" : "FAIL"); printf(__VA_ARGS__); printf("\n"); if (!ok_) failures++; } while (0)

static NSError *openApp(NSString *bundleIdentifier)
{
	__block NSError *result = nil;
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	[[DBApplicationService sharedService] openApplication:bundleIdentifier options:nil completion:^(NSError *error) {
		result = error;
		dispatch_semaphore_signal(done);
	}];
	dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
	return result;
}

static void terminateApp(NSString *bundleIdentifier)
{
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	[[DBApplicationService sharedService] terminateApplication:bundleIdentifier completion:^{
		dispatch_semaphore_signal(done);
	}];
	dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
}

int main(int argc, char **argv)
{
	if (strcmp(getprogname(), "Sleeper") == 0) {
		sleep(120);
		return 0;
	}

	@autoreleasepool {
		NSString *sleeperApp = installSleeper();
		CHECK(sleeperApp != nil, "installed %s", [sleeperApp UTF8String]);

		/* Processes */
		CHECK(DBProcessIsAlive(getpid()), "DBProcessIsAlive(own pid)");
		CHECK(!DBProcessIsAlive(999999), "DBProcessIsAlive(999999) is NO");

		/* Applications, with no frontboardd running */
		DBApplicationService *service = [DBApplicationService sharedService];
		CHECK([[service bundleForApplication:SleeperIdentifier] bundlePath] != nil, "bundleForApplication(com.example.sleeper) at %s", [[[service bundleForApplication:SleeperIdentifier] bundlePath] UTF8String]);
		CHECK([service pidOfApplication:SleeperIdentifier] == 0, "sleeper not running before open");
		NSError *error = openApp(SleeperIdentifier);
		CHECK(error == nil, "openApplication(com.example.sleeper) error=%s", [[error description] UTF8String]);
		pid_t pid = 0;
		for (int i = 0; i < 400 && pid == 0; i++) { /* a cold first launch on a Pi 4 takes seconds */
			usleep(50000);
			pid = [service pidOfApplication:SleeperIdentifier];
		}
		CHECK(pid > 0 && DBProcessIsAlive(pid) && [DBProcessesForApplication(SleeperIdentifier) containsObject:@(pid)], "pidOfApplication -> %d", pid);
		CHECK(pid > 0 && openApp(SleeperIdentifier) == nil && [service pidOfApplication:SleeperIdentifier] == pid, "second open reuses the running process");
		terminateApp(SleeperIdentifier);
		for (int i = 0; i < 100 && DBProcessIsAlive(pid); i++)
			usleep(50000);
		CHECK(pid > 0 && !DBProcessIsAlive(pid) && [service pidOfApplication:SleeperIdentifier] == 0, "terminateApplication ended pid %d", pid);
		error = openApp(@"com.example.missing");
		CHECK([[error domain] isEqualToString:DBOpenApplicationErrorDomain] && [error code] == DBOpenApplicationErrorNotFound, "openApplication(missing) -> %s", [[error localizedFailureReason] UTF8String]);

		[[NSFileManager defaultManager] removeItemAtPath:sleeperApp error:NULL];
		printf("%s: %d failure(s)\n", failures ? "FAILED" : "OK", failures);
	}
	return failures != 0;
}
