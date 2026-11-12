/* What a phone host gives UIKit: the screen's size and scale
   (DARLING_UISCREEN=375x667@2), the edges a notch and a home indicator
   cover (DARLING_UISAFEAREA=44,0,34,0), the status bar under the notch, and
   each view's safe area where it is; then the host keyboard typing into a
   UITextField and a UISearchBar, with their delegates told. It prints
   "ready" with where to tap, then waits for real key presses (xdotool, see
   ios-phone.md); one PASS/FAIL line per check, nonzero exit on any failure. */

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

@interface AppDelegate : UIResponder <UIApplicationDelegate, UITextFieldDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic) int began, changes, shouldChange, returned, searchChanges;
@property (nonatomic, copy) NSString *searchText;
@end

@implementation AppDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField { _began++; }

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	_shouldChange++;
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	_returned++;
	[textField resignFirstResponder];
	return YES;
}

- (void)fieldChanged:(UITextField *)field { _changes++; }

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
	_searchChanges++;
	_searchText = [searchText copy];
}

- (void)screenChecks
{
	UIScreen *screen = [UIScreen mainScreen];
	expect(CGRectEqualToRect([screen bounds], CGRectMake(0, 0, 375, 667)) && [screen scale] == 2,
	       "the host's screen: its size in points and its scale", NSStringFromCGRect([screen bounds]));
	expect(CGRectEqualToRect([screen nativeBounds], CGRectMake(0, 0, 750, 1334)), "its size in pixels", NSStringFromCGRect([screen nativeBounds]));
	expect([[UIApplication sharedApplication] statusBarFrame].size.height == 44, "the status bar is as tall as the notch",
	       NSStringFromCGRect([[UIApplication sharedApplication] statusBarFrame]));

	UIView *root = [[_window rootViewController] view];
	expect(UIEdgeInsetsEqualToEdgeInsets([root safeAreaInsets], UIEdgeInsetsMake(44, 0, 34, 0)), "a full screen view's safe area",
	       NSStringFromUIEdgeInsets([root safeAreaInsets]));
	UIView *middle = [[UIView alloc] initWithFrame:CGRectMake(0, 200, 375, 100)];
	UIView *bottom = [[UIView alloc] initWithFrame:CGRectMake(0, 647, 375, 20)];
	[root addSubview:middle];
	[root addSubview:bottom];
	expect(UIEdgeInsetsEqualToEdgeInsets([middle safeAreaInsets], UIEdgeInsetsZero), "a view clear of the edges has none",
	       NSStringFromUIEdgeInsets([middle safeAreaInsets]));
	expect(UIEdgeInsetsEqualToEdgeInsets([bottom safeAreaInsets], UIEdgeInsetsMake(0, 0, 20, 0)), "a view over the home indicator",
	       NSStringFromUIEdgeInsets([bottom safeAreaInsets]));

	UIView *pinned = [[UIView alloc] initWithFrame:CGRectZero];
	[pinned setTranslatesAutoresizingMaskIntoConstraints:NO];
	[root addSubview:pinned];
	UILayoutGuide *safe = [root safeAreaLayoutGuide];
	[NSLayoutConstraint activateConstraints:@[
		[[pinned topAnchor] constraintEqualToAnchor:[safe topAnchor]],
		[[pinned leftAnchor] constraintEqualToAnchor:[safe leftAnchor]],
		[[pinned widthAnchor] constraintEqualToConstant:100],
		[[pinned bottomAnchor] constraintEqualToAnchor:[safe bottomAnchor]],
	]];
	[root layoutIfNeeded];
	expect(CGRectEqualToRect([pinned frame], CGRectMake(0, 44, 100, 667 - 44 - 34)), "a view pinned to the safe area layout guide",
	       NSStringFromCGRect([pinned frame]));
	[pinned removeFromSuperview];
	[middle removeFromSuperview];
	[bottom removeFromSuperview];
}

- (void)typingChecks
{
	expect([[_field text] isEqualToString:@"hello"], "keys typed into a text field", [_field text]);
	expect(_began >= 1, "the field told its delegate editing began", nil);
	expect(_changes >= 5, "each change sent UIControlEventEditingChanged", [NSString stringWithFormat:@"%d", _changes]);
	expect(_shouldChange >= 5, "the delegate was asked before each change", [NSString stringWithFormat:@"%d", _shouldChange]);
	expect(_returned == 1, "Return asked textFieldShouldReturn:", [NSString stringWithFormat:@"%d", _returned]);
	expect([[_search text] isEqualToString:@"abc"] && [_searchText isEqualToString:@"abc"] && _searchChanges >= 3,
	       "a search bar tells its delegate the text", [NSString stringWithFormat:@"%@, told %@ (%d)", [_search text], _searchText, _searchChanges]);
}

static CGPoint centerOnScreen(UIView *view)
{
	NSRect frame = [view convertRect:[view bounds] toView:nil];
	NSRect onScreen = [[view window] convertRectToScreen:frame];
	CGFloat screenHeight = [[[view window] screen] frame].size.height;
	return CGPointMake(NSMidX(onScreen), screenHeight - NSMidY(onScreen));
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	UIViewController *controller = [[UIViewController alloc] init];
	[[controller view] setBackgroundColor:[UIColor whiteColor]];
	[_window setRootViewController:controller];
	_field = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, 335, 40)];
	[_field setBorderStyle:UITextBorderStyleRoundedRect];
	[_field setPlaceholder:@"Type here"];
	[_field setDelegate:self];
	[_field addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingChanged];
	[[controller view] addSubview:_field];
	_search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 200, 375, 44)];
	[_search setDelegate:self];
	[[controller view] addSubview:_search];
	[_window makeKeyAndVisible];

	[self screenChecks];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		CGPoint field = centerOnScreen(self->_field), search = centerOnScreen(self->_search);
		printf("ready field %d %d search %d %d\n", (int)field.x, (int)field.y, (int)search.x, (int)search.y);
	});
	/* The typing (hello, Return, then abc in the search bar) is done when
	   the search bar holds abc, or after two minutes. */
	[self performSelector:@selector(poll:) withObject:@0 afterDelay:1];
	return YES;
}

- (void)poll:(NSNumber *)waited
{
	if (![[_search text] isEqualToString:@"abc"] && [waited intValue] < 240) {
		[self performSelector:@selector(poll:) withObject:@([waited intValue] + 1) afterDelay:0.5];
		return;
	}
	[self typingChecks];
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
