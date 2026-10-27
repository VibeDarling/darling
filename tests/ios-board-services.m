/* GraphicsServices, RunningBoardServices and FrontBoardServices: each
   framework's main entry points, including launching, finding and
   terminating an installed app by bundle identifier. See
   ios-board-services.md. */

#import <Foundation/Foundation.h>
#import <GraphicsServices/GraphicsServices.h>
#import <RunningBoardServices/RunningBoardServices.h>
#import <FrontBoardServices/FrontBoardServices.h>
#include <mach-o/dyld.h>

/* The app FBSSystemService launches is this same binary, installed as
   ~/Applications/Sleeper.app (one of FrontBoardServices' search paths);
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
	[[FBSSystemService sharedService] openApplication:bundleIdentifier options:nil withResult:^(NSError *error) {
		result = error;
		dispatch_semaphore_signal(done);
	}];
	dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
	return result;
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
		/* GraphicsServices */
		GSInitialize();
		CGSize size = GSMainScreenSize();
		CHECK(size.width == 1024 && size.height == 768, "GSMainScreenSize default %gx%g", size.width, size.height);
		GSSetMainScreenInfo(CGSizeMake(390, 844), 3, 1);
		CGSize pixels = GSMainScreenPixelSize();
		CHECK(pixels.width == 1170 && pixels.height == 2532 && GSMainScreenScaleFactor() == 3, "GSMainScreenPixelSize %gx%g @%g", pixels.width, pixels.height, GSMainScreenScaleFactor());
		uint64_t t0 = GSCurrentEventTimestamp();
		usleep(1000);
		CHECK(GSCurrentEventTimestamp() > t0, "GSCurrentEventTimestamp advances");

		__block BOOL ranInPushedMode = NO;
		CFStringRef mode = CFSTR("TestMode");
		CFRunLoopTimerRef timer = CFRunLoopTimerCreateWithHandler(NULL, CFAbsoluteTimeGetCurrent() + 0.1, 0, 0, 0, ^(CFRunLoopTimerRef t) {
			NSString *current = CFBridgingRelease(CFRunLoopCopyCurrentMode(CFRunLoopGetMain()));
			ranInPushedMode = [current isEqualToString:@"TestMode"];
			GSEventPopRunLoopMode(mode);
			GSEventStopModal();
		});
		CFRunLoopAddTimer(CFRunLoopGetMain(), timer, mode);
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
			GSEventPushRunLoopMode(mode);
		});
		NSDate *start = [NSDate date];
		GSEventRunModal(true);
		CHECK(ranInPushedMode && -[start timeIntervalSinceNow] < 5, "GSEventRunModal ran a pushed mode and returned after GSEventStopModal (%.2fs)", -[start timeIntervalSinceNow]);

		/* RunningBoardServices */
		RBSProcessHandle *me = [RBSProcessHandle currentProcess];
		CHECK([me pid] == getpid() && [me isValid] && [[me currentState] isRunning], "RBSProcessHandle currentProcess %s", [[me description] UTF8String]);
		RBSProcessHandle *byPid = [RBSProcessHandle handleForIdentifier:[RBSProcessIdentifier identifierWithPid:getpid()] error:NULL];
		CHECK([byPid isEqual:me], "handleForIdentifier(own pid) == currentProcess");
		NSError *error = nil;
		RBSProcessHandle *none = [RBSProcessHandle handleForIdentifier:[RBSProcessIdentifier identifierWithPid:999999] error:&error];
		CHECK(none == nil && [error code] == RBSRequestErrorProcessNotFound, "handleForIdentifier(999999) -> %s", [[error localizedFailureReason] UTF8String]);
		RBSAssertion *assertion = [[RBSAssertion alloc] initWithExplanation:@"test" target:[RBSTarget currentProcess]
			attributes:@[ [RBSDomainAttribute attributeWithDomain:@"com.apple.common" name:@"BasicAudio"] ]];
		CHECK([assertion acquireWithError:NULL] && [assertion isValid] && [[RBSAssertion acquiredAssertionsForTarget:[RBSTarget currentProcess]] count] == 1, "RBSAssertion acquired %s", [[assertion description] UTF8String]);
		[assertion invalidate];
		CHECK(![assertion isValid] && [[RBSAssertion acquiredAssertionsForTarget:[RBSTarget currentProcess]] count] == 0, "RBSAssertion invalidated");

		/* FrontBoardServices */
		FBSSystemService *service = [FBSSystemService sharedService];
		NSInteger reason = -1;
		CHECK([service canOpenApplication:SleeperIdentifier reason:&reason] && reason == 0, "canOpenApplication(com.example.sleeper) at %s", [[[service bundleForApplication:SleeperIdentifier] bundlePath] UTF8String]);
		CHECK([service pidForApplication:SleeperIdentifier] == 0, "sleeper not running before open");
		error = openApp(SleeperIdentifier);
		CHECK(error == nil, "openApplication(com.example.sleeper) error=%s", [[error description] UTF8String]);
		pid_t pid = 0;
		for (int i = 0; i < 400 && pid == 0; i++) { /* a cold first launch on a Pi 4 takes seconds */
			usleep(50000);
			pid = [service pidForApplication:SleeperIdentifier];
		}
		RBSProcessHandle *sleeper = pid ? [RBSProcessHandle handleForIdentifier:[RBSProcessIdentifier identifierWithPid:pid] error:NULL] : nil;
		CHECK(pid > 0 && [[sleeper currentState] isRunning], "pidForApplication -> %d, %s", pid, [[sleeper description] UTF8String]);
		CHECK(pid > 0 && openApp(SleeperIdentifier) == nil && [service pidForApplication:SleeperIdentifier] == pid, "second open reuses the running process");
		[service terminateApplication:SleeperIdentifier forReason:1 andReport:NO withDescription:@"test"];
		for (int i = 0; i < 100 && [sleeper isValid]; i++)
			usleep(50000);
		CHECK(pid > 0 && ![sleeper isValid] && [service pidForApplication:SleeperIdentifier] == 0, "terminateApplication ended pid %d", pid);
		error = openApp(@"com.example.missing");
		CHECK([error code] == FBSOpenApplicationErrorCodeNotFound, "openApplication(missing) -> %s", [[error localizedFailureReason] UTF8String]);

		FBSMutableSceneSettings *settings = [[FBSMutableSceneSettings alloc] init];
		settings.frame = CGRectMake(0, 0, 390, 844);
		settings.foreground = YES;
		FBSSceneSettings *frozen = [settings copy];
		CHECK([frozen isEqual:settings] && ![frozen isKindOfClass:[FBSMutableSceneSettings class]] && [frozen isForeground], "FBSSceneSettings copy %s", [[frozen description] UTF8String]);

		[[NSFileManager defaultManager] removeItemAtPath:sleeperApp error:NULL];
		printf("%s: %d failure(s)\n", failures ? "FAILED" : "OK", failures);
	}
	return failures != 0;
}
