/* The app half of ios-frontboard-lite: a UIKit app that prints each
   lifecycle callback it receives, one line per callback, and shows its
   bundle identifier on a colored window so screenshots tell the copies
   apart. See ios-frontboard-lite.md. */

#import <UIKit/UIKit.h>
#include <stdio.h>

static void logCallback(const char *callback)
{
	printf("LIFECYCLE %s %s state=%ld\n", [[[NSBundle mainBundle] bundleIdentifier] UTF8String], callback,
		(long)[[UIApplication sharedApplication] applicationState]);
	fflush(stdout);
}

@interface ProbeViewController : UIViewController
@end

@implementation ProbeViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
	self.view.backgroundColor = [bundleIdentifier hasSuffix:@".a"]
		? [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1]
		: [UIColor colorWithRed:0.3 green:0.4 blue:0.9 alpha:1];
	UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
	label.text = bundleIdentifier;
	label.textAlignment = NSTextAlignmentCenter;
	label.textColor = [UIColor whiteColor];
	label.font = [UIFont systemFontOfSize:32];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:label];
}

@end

@interface ProbeAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ProbeAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	logCallback("didFinishLaunching");
	self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	self.window.rootViewController = [[ProbeViewController alloc] init];
	[self.window makeKeyAndVisible];
	return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application { logCallback("didBecomeActive"); }
- (void)applicationWillResignActive:(UIApplication *)application { logCallback("willResignActive"); }
- (void)applicationDidEnterBackground:(UIApplication *)application { logCallback("didEnterBackground"); }
- (void)applicationWillEnterForeground:(UIApplication *)application { logCallback("willEnterForeground"); }
- (void)applicationWillTerminate:(UIApplication *)application { logCallback("willTerminate"); }

@end

int main(int argc, char *argv[])
{
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([ProbeAppDelegate class]));
	}
}
