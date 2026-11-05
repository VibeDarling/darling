#import <UIKit/UIKit.h>
#import <AppKit/NSApplication.h>
#include <dlfcn.h>
#include <stdio.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

@interface Delegate : NSObject <UIApplicationDelegate> {
    NSMutableArray *_log;
}
@property (nonatomic, readonly) NSMutableArray *log;
@end
@implementation Delegate
@synthesize log = _log;
- (instancetype)init { self = [super init]; _log = [[NSMutableArray alloc] init]; return self; }
- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)options { [_log addObject:@"will"]; return YES; }
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options { [_log addObject:@"did"]; return YES; }
@end

/* Drives the AppKit delegate callbacks directly: no event loop is started. */
int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        if (!dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL)) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        UIApplication *application = [UIApplication sharedApplication];
        Delegate *delegate = [[Delegate alloc] init];
        application.delegate = delegate;

        // The starting value is upstream's constant: Active.
        CHECK(application.applicationState == UIApplicationStateActive);

        id<NSApplicationDelegate> appKit = (id<NSApplicationDelegate>)application;
        NSNotification *note = [NSNotification notificationWithName:@"test" object:nil];
        [appKit applicationWillFinishLaunching:note];
        [appKit applicationDidFinishLaunching:note];
        NSArray *expected = @[@"will", @"did"];
        CHECK([delegate.log isEqualToArray:expected]);

        [appKit applicationDidResignActive:note];
        CHECK(application.applicationState == UIApplicationStateInactive);
        [appKit applicationDidBecomeActive:note];
        CHECK(application.applicationState == UIApplicationStateActive);
        puts("PASS UIKit UIApplication state");
    }
    return 0;
}
