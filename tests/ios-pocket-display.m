/* An iOS app on the Pocket display backend, as on a phone: the host
   (tools/pocket-host, standing in for the Android app) gives the screen and
   its safe area, shows what the app draws, and sends touches and input method
   text. It prints "ready" with where things are on the host's screen (pixels),
   then waits for ios-pocket-display.sh to tap, drag and type; one PASS/FAIL
   line per check, nonzero exit on any failure. See ios-pocket-display.md. */

#import <UIKit/UIKit.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSScreen.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

/* Records its touches, in its own coordinates. */
@interface Pad : UIView
@property (nonatomic) CGPoint began, ended;
@property (nonatomic) int moves, ends, mostAtOnce;
@end

@implementation Pad

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([[event allTouches] count] == 1)
		_began = [[touches anyObject] locationInView:self];
	_mostAtOnce = MAX(_mostAtOnce, (int)[[event allTouches] count]);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	_moves++;
	_mostAtOnce = MAX(_mostAtOnce, (int)[[event allTouches] count]);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	_ended = [[touches anyObject] locationInView:self];
	_ends += (int)[touches count];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) Pad *pad;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic) int taps, returned;
@end

@implementation AppDelegate

- (void)tapped:(UIButton *)button { _taps++; }

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	_returned++;
	[textField resignFirstResponder];
	return YES;
}

/* The middle of a view, in the host's pixels from the screen's top left. */
static CGPoint hostPixel(UIView *view, CGPoint point)
{
	NSRect frame = [view convertRect:NSMakeRect(point.x, point.y, 0, 0) toView:nil];
	NSRect onScreen = [[view window] convertRectToScreen:frame];
	CGFloat height = [[[view window] screen] frame].size.height;
	CGFloat scale = [[UIScreen mainScreen] scale];
	return CGPointMake(onScreen.origin.x * scale, (height - onScreen.origin.y) * scale);
}

static CGPoint centerPixel(UIView *view)
{
	return hostPixel(view, CGPointMake(CGRectGetMidX([view bounds]), CGRectGetMidY([view bounds])));
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	/* The host's screen is 720x1280 pixels at 2x, and covers 48 pixels at
	   the top and 32 at the bottom. */
	UIScreen *screen = [UIScreen mainScreen];
	expect(CGRectEqualToRect([screen bounds], CGRectMake(0, 0, 360, 640)) && [screen scale] == 2,
	       "the host's screen, in points, and its scale", [NSString stringWithFormat:@"%@ @%g", NSStringFromCGRect([screen bounds]), [screen scale]]);
	expect(CGRectEqualToRect([screen nativeBounds], CGRectMake(0, 0, 720, 1280)), "its pixels", NSStringFromCGRect([screen nativeBounds]));

	_window = [[UIWindow alloc] initWithFrame:[screen bounds]];
	UIViewController *controller = [[UIViewController alloc] init];
	UIView *root = [controller view];
	[root setBackgroundColor:[UIColor whiteColor]];
	[_window setRootViewController:controller];

	UIView *block = [[UIView alloc] initWithFrame:CGRectMake(20, 60, 100, 50)];
	[block setBackgroundColor:[UIColor colorWithRed:0 green:1 blue:0 alpha:1]];
	[block setTag:1];
	[root addSubview:block];

	_button = [UIButton buttonWithType:UIButtonTypeSystem];
	[_button setFrame:CGRectMake(140, 60, 200, 50)];
	[_button setTitle:@"Tap" forState:UIControlStateNormal];
	[_button addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
	[root addSubview:_button];

	_pad = [[Pad alloc] initWithFrame:CGRectMake(20, 140, 320, 200)];
	[_pad setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:1 alpha:1]];
	[_pad setMultipleTouchEnabled:YES];
	[root addSubview:_pad];

	_field = [[UITextField alloc] initWithFrame:CGRectMake(20, 370, 320, 40)];
	[_field setBorderStyle:UITextBorderStyleRoundedRect];
	[_field setDelegate:self];
	[root addSubview:_field];

	[_window makeKeyAndVisible];

	[root layoutIfNeeded];
	UIEdgeInsets safe = [root safeAreaInsets];
	expect(UIEdgeInsetsEqualToEdgeInsets(safe, UIEdgeInsetsMake(24, 0, 16, 0)), "the safe area the host gives",
	       NSStringFromUIEdgeInsets(safe));
	expect([[UIApplication sharedApplication] statusBarFrame].size.height == 24, "the status bar under it",
	       NSStringFromCGRect([[UIApplication sharedApplication] statusBarFrame]));

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		CGPoint b = centerPixel(self->_button), f = centerPixel(self->_field);
		CGPoint p0 = hostPixel(self->_pad, CGPointMake(40, 50)), p1 = hostPixel(self->_pad, CGPointMake(240, 150));
		CGPoint green = centerPixel(block), blue = hostPixel(self->_pad, CGPointMake(10, 190));
		CGPoint white = hostPixel(root, CGPointMake(10, 120));
		printf("ready button %d %d pad %d %d %d %d field %d %d green %d %d blue %d %d white %d %d\n",
		       (int)b.x, (int)b.y, (int)p0.x, (int)p0.y, (int)p1.x, (int)p1.y, (int)f.x, (int)f.y,
		       (int)green.x, (int)green.y, (int)blue.x, (int)blue.y, (int)white.x, (int)white.y);
	});
	[self performSelector:@selector(poll:) withObject:@0 afterDelay:1];
	return YES;
}

- (BOOL)done
{
	return _taps >= 1 && _pad.ends >= 3 && _returned >= 1;
}

- (void)poll:(NSNumber *)waited
{
	if (![self done] && [waited intValue] < 360) {
		[self performSelector:@selector(poll:) withObject:@([waited intValue] + 1) afterDelay:0.5];
		return;
	}
	expect(_taps == 1, "a tap on a button sends its action once", [NSString stringWithFormat:@"%d", _taps]);
	expect(fabs(_pad.began.x - 40) <= 1 && fabs(_pad.began.y - 50) <= 1, "a drag begins where the finger went down",
	       NSStringFromCGPoint(_pad.began));
	expect(_pad.moves >= 5, "and moves with it", [NSString stringWithFormat:@"%d moves", _pad.moves]);
	expect(_pad.mostAtOnce == 2, "two fingers at once", [NSString stringWithFormat:@"%d", _pad.mostAtOnce]);
	expect(_pad.ends >= 3, "every finger ends", [NSString stringWithFormat:@"%d", _pad.ends]);
	expect([[_field text] isEqualToString:@"hell"], "input method text and a delete key reach a text field", [_field text]);
	expect(_returned == 1, "Return asks textFieldShouldReturn:", [NSString stringWithFormat:@"%d", _returned]);
	printf("%d failures\n", failures);
	fflush(stdout);
	exit(failures != 0);
}

@end

int main(int argc, char *argv[])
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
