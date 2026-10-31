/* Preferences.framework, as tweak preference bundles use it: a plist of
   specifiers loaded into a PSListController subclass, shown in a navigation
   controller and driven with real pointer events. One PASS/FAIL line per
   check; exits nonzero on any failure. See ios-preferences.md. */

#import <UIKit/UIKit.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSWindow.h>
#import <Preferences/Preferences.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

static NSEvent *pointer(NSEventType type, UIView *view, CGPoint point, NSTimeInterval time)
{
	NSPoint inWindow = [view convertPoint:NSMakePoint(point.x, point.y) toView:nil];
	return [NSEvent mouseEventWithType:type location:inWindow modifierFlags:0 timestamp:time
	                      windowNumber:[[view window] windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1];
}

static NSTimeInterval sClock = 1000;

/* A press and release at the middle of a view. */
static void tap(UIView *view)
{
	CGPoint middle = CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds));
	[view mouseDown:pointer(NSLeftMouseDown, view, middle, sClock += 0.01)];
	[view mouseUp:pointer(NSLeftMouseUp, view, middle, sClock += 0.01)];
}

static void spin(NSTimeInterval seconds)
{
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static void spinUntil(BOOL (^done)(void))
{
	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:15];
	while (!done() && [limit timeIntervalSinceNow] > 0)
		spin(0.05);
}

static NSString *const Domain = @"org.darlinghq.preftest";

static id stored(NSString *key)
{
	CFPreferencesAppSynchronize((__bridge CFStringRef) Domain);
	return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef) key, (__bridge CFStringRef) Domain));
}

static int sNotifications;

static void changed(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info)
{
	sNotifications++;
}

/* A page with a link to a page of its own class, and a button. */
@interface TestListController : PSListController
@property (nonatomic) int buttonPresses;
@property (nonatomic, strong) PSSpecifier *pressed;
@end

@interface TestDetailController : PSListController
@end

static NSBundle *sBundle;

@implementation TestListController

- (NSArray *)specifiers
{
	if (!_specifiers)
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self bundle:sBundle];
	return _specifiers;
}

- (void)press:(PSSpecifier *)specifier
{
	self.buttonPresses++;
	self.pressed = specifier;
}

@end

@implementation TestDetailController

- (NSArray *)specifiers
{
	if (!_specifiers)
		_specifiers = [self loadSpecifiersFromPlistName:@"Detail" target:self bundle:sBundle];
	return _specifiers;
}

@end

/* Writes the settings bundle the pages load from. */
static NSBundle *makeBundle(void)
{
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"preftest-%d.bundle", getpid()]];
	NSString *english = [path stringByAppendingPathComponent:@"en.lproj"];
	[[NSFileManager defaultManager] createDirectoryAtPath:english withIntermediateDirectories:YES attributes:nil error:NULL];
	NSDictionary *root = @{
		@"title": @"TestTitle",
		@"items": @[
			@{ @"cell": @"PSSwitchCell", @"label": @"Enabled", @"key": @"enabled", @"defaults": Domain,
			   @"default": @YES, @"id": @"enabled", @"PostNotification": @"org.darlinghq.preftest/changed" },
			@{ @"cell": @"PSGroupCell", @"label": @"Look", @"footerText": @"How it looks" },
			@{ @"cell": @"PSLinkListCell", @"label": @"Theme", @"key": @"theme", @"defaults": Domain,
			   @"default": @"dark", @"validValues": @[ @"light", @"dark", @"auto" ],
			   @"validTitles": @[ @"Light", @"Dark", @"Automatic" ], @"id": @"theme" },
			@{ @"cell": @"PSSliderCell", @"key": @"size", @"defaults": Domain, @"default": @0.25,
			   @"min": @0, @"max": @1, @"id": @"size" },
			@{ @"cell": @"PSSegmentCell", @"key": @"mode", @"defaults": Domain, @"default": @1,
			   @"validValues": @[ @0, @1, @2 ], @"validTitles": @[ @"A", @"B", @"C" ], @"id": @"mode" },
			@{ @"cell": @"PSEditTextCell", @"label": @"Name", @"key": @"name", @"defaults": Domain,
			   @"placeholder": @"Your name", @"keyboard": @"email", @"autoCaps": @"words", @"noAutoCorrect": @YES, @"id": @"name" },
			@{ @"cell": @"PSGroupCell", @"label": @"Speed", @"isRadioGroup": @YES, @"key": @"speed", @"defaults": Domain, @"default": @"slow" },
			@{ @"cell": @"PSListItemCell", @"label": @"Slow", @"value": @"slow", @"id": @"slow" },
			@{ @"cell": @"PSListItemCell", @"label": @"Fast", @"value": @"fast", @"id": @"fast" },
			@{ @"cell": @"PSGroupCell" },
			@{ @"cell": @"PSLinkCell", @"label": @"More", @"detail": @"TestDetailController", @"id": @"more" },
			@{ @"cell": @"PSButtonCell", @"label": @"Respring", @"action": @"press:", @"id": @"respring" },
			@{ @"cell": @"PSStaticTextCell", @"label": @"Version 1.0", @"id": @"version" },
		],
	};
	NSDictionary *detail = @{ @"title": @"Detail", @"items": @[ @{ @"cell": @"PSTitleValueCell", @"label": @"Detail row" } ] };
	[root writeToFile:[path stringByAppendingPathComponent:@"Root.plist"] atomically:YES];
	[detail writeToFile:[path stringByAppendingPathComponent:@"Detail.plist"] atomically:YES];
	[@"\"TestTitle\" = \"Test Settings\";\n\"Theme\" = \"Colour theme\";\n" writeToFile:[english stringByAppendingPathComponent:@"Root.strings"]
		atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	return [NSBundle bundleWithPath:path];
}

static void clearPreferences(void)
{
	for (NSString *key in @[ @"enabled", @"theme", @"size", @"mode", @"name", @"speed" ])
		CFPreferencesSetAppValue((__bridge CFStringRef) key, NULL, (__bridge CFStringRef) Domain);
	CFPreferencesAppSynchronize((__bridge CFStringRef) Domain);
}

static UITableViewCell *cellOf(PSListController *list, NSString *identifier)
{
	return [list.table cellForRowAtIndexPath:[list indexPathForSpecifier:[list specifierForID:identifier]]];
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	clearPreferences();
	sBundle = makeBundle();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, changed,
		CFSTR("org.darlinghq.preftest/changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

	TestListController *list = [[TestListController alloc] init];
	PSRootController *root = [[PSRootController alloc] initWithTitle:@"Settings" identifier:@"com.apple.Preferences"];
	[root pushViewController:list animated:NO];
	self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	self.window.rootViewController = root;
	[self.window makeKeyAndVisible];
	dispatch_async(dispatch_get_main_queue(), ^{
		[self runChecks:list root:root];
	});
	return YES;
}

- (void)runChecks:(TestListController *)list root:(PSRootController *)root
{
	NSArray *specifiers = list.specifiers;
	expect(specifiers.count == 13, "the plist's items become specifiers", [NSString stringWithFormat:@"%lu", (unsigned long) specifiers.count]);
	expect([list.title isEqual:@"Test Settings"], "the page's title, localized from the plist's strings table", list.title);
	PSSpecifier *theme = [list specifierForID:@"theme"];
	expect(theme.cellType == PSLinkListCell && theme.detailControllerClass == [PSListItemsController class]
		&& [theme.titleDictionary[@"auto"] isEqual:@"Automatic"],
		"a link list gets its titles and PSListItemsController", theme.name);
	expect([theme.name isEqual:@"Colour theme"], "labels are localized", theme.name);
	PSTextFieldSpecifier *name = (PSTextFieldSpecifier *) [list specifierForID:@"name"];
	expect([name isKindOfClass:[PSTextFieldSpecifier class]] && [name.placeholder isEqual:@"Your name"]
		&& name->keyboardType == UIKeyboardTypeEmailAddress && name->autoCapsType == UITextAutocapitalizationTypeWords
		&& name->autoCorrectionType == UITextAutocorrectionTypeNo,
		"a text field's specifier has its placeholder and keyboard traits", nil);
	expect([list specifierForID:@"respring"]->action == @selector(press:), "a button's action", nil);

	UITableView *table = list.table;
	spinUntil(^BOOL { return table.window != nil; });
	expect(table.window != nil && table.style == UITableViewStyleGrouped, "the page is a grouped table on screen", nil);
	expect([list numberOfGroups] == 4 && [table numberOfSections] == 4, "the group specifiers make the sections",
		[NSString stringWithFormat:@"%ld", (long) [table numberOfSections]]);
	expect([table numberOfRowsInSection:0] == 1 && [table numberOfRowsInSection:1] == 4 && [table numberOfRowsInSection:2] == 2
		&& [table numberOfRowsInSection:3] == 3, "each section has its rows", nil);
	expect([[list tableView:table titleForHeaderInSection:1] isEqual:@"Look"]
		&& [[list tableView:table titleForFooterInSection:1] isEqual:@"How it looks"]
		&& [list tableView:table titleForHeaderInSection:0] == nil,
		"a group's header and footer; no header before the first group", nil);

	PSSwitchTableCell *enabledCell = (PSSwitchTableCell *) cellOf(list, @"enabled");
	UISwitch *toggle = (UISwitch *) enabledCell.control;
	expect([enabledCell isKindOfClass:[PSSwitchTableCell class]] && [toggle isKindOfClass:[UISwitch class]] && toggle.on,
		"a switch row shows the default value", nil);
	PSTableCell *themeCell = (PSTableCell *) cellOf(list, @"theme");
	expect([themeCell.detailTextLabel.text isEqual:@"Dark"] && themeCell.accessoryType == UITableViewCellAccessoryDisclosureIndicator,
		"a link list row shows its value's title", themeCell.detailTextLabel.text);
	PSSliderTableCell *sizeCell = (PSSliderTableCell *) cellOf(list, @"size");
	expect([sizeCell.control isKindOfClass:[UISlider class]] && fabsf(((UISlider *) sizeCell.control).value - 0.25f) < 0.001f,
		"a slider row", nil);
	PSSegmentTableCell *modeCell = (PSSegmentTableCell *) cellOf(list, @"mode");
	expect([modeCell.control isKindOfClass:[UISegmentedControl class]] && ((UISegmentedControl *) modeCell.control).selectedSegmentIndex == 1,
		"a segment row", nil);
	PSEditableTableCell *nameCell = (PSEditableTableCell *) cellOf(list, @"name");
	expect([nameCell isKindOfClass:[PSEditableTableCell class]] && [nameCell.textField.placeholder isEqual:@"Your name"]
		&& nameCell.textField.keyboardType == UIKeyboardTypeEmailAddress,
		"a text row's field", nil);
	expect(((PSTableCell *) cellOf(list, @"slow")).checked && !((PSTableCell *) cellOf(list, @"fast")).checked,
		"a radio group checks its default", nil);

	// Changing settings, with the pointer.
	spinUntil(^BOOL { return !CGRectIsEmpty(toggle.bounds); });
	tap(toggle);
	spinUntil(^BOOL { return stored(@"enabled") != nil; });
	expect([stored(@"enabled") isEqual:@NO] && !toggle.on, "tapping the switch stores NO under its key and domain", [stored(@"enabled") description]);
	expect(sNotifications == 1, "and posts its PostNotification", [NSString stringWithFormat:@"%d", sNotifications]);
	NSString *file = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Preferences/%@.plist", Domain]];
	expect([[NSDictionary dictionaryWithContentsOfFile:file][@"enabled"] isEqual:@NO], "in the domain's plist", file);

	((UISlider *) sizeCell.control).value = 0.75f;
	[sizeCell.control sendActionsForControlEvents:UIControlEventValueChanged];
	expect(fabs([stored(@"size") doubleValue] - 0.75) < 0.001, "moving the slider stores its value", [stored(@"size") description]);
	((UISegmentedControl *) modeCell.control).selectedSegmentIndex = 2;
	[modeCell.control sendActionsForControlEvents:UIControlEventValueChanged];
	expect([stored(@"mode") isEqual:@2], "choosing a segment stores its value", [stored(@"mode") description]);
	nameCell.textField.text = @"Ada";
	[nameCell textFieldShouldReturn:nameCell.textField];
	expect([stored(@"name") isEqual:@"Ada"], "return in the text field stores the text", [stored(@"name") description]);

	tap(cellOf(list, @"fast"));
	spinUntil(^BOOL { return [stored(@"speed") isEqual:@"fast"]; });
	expect([stored(@"speed") isEqual:@"fast"] && ((PSTableCell *) cellOf(list, @"fast")).checked
		&& !((PSTableCell *) cellOf(list, @"slow")).checked,
		"tapping a radio row stores its value under the group's key and moves the check", [stored(@"speed") description]);

	tap(cellOf(list, @"respring"));
	spinUntil(^BOOL { return list.buttonPresses > 0; });
	expect(list.buttonPresses == 1 && list.pressed == [list specifierForID:@"respring"], "tapping a button calls its action with the specifier", nil);

	// The choices of a link list, on a page of their own.
	tap(themeCell);
	spinUntil(^BOOL { return root.viewControllers.count == 2; });
	PSListItemsController *items = (PSListItemsController *) root.topViewController;
	expect([items isKindOfClass:[PSListItemsController class]] && [items.title isEqual:@"Colour theme"] && items.specifier == theme,
		"tapping the link list pushes its choices", NSStringFromClass([items class]));
	spinUntil(^BOOL { return items.table.window != nil; });
	expect([items.table numberOfRowsInSection:0] == 3, "one row per value", nil);
	UITableViewCell *dark = [items.table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
	UITableViewCell *automatic = [items.table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]];
	expect(dark.accessoryType == UITableViewCellAccessoryCheckmark && [automatic.textLabel.text isEqual:@"Automatic"],
		"the current value is checked", nil);
	tap(automatic);
	spinUntil(^BOOL { return [stored(@"theme") isEqual:@"auto"]; });
	expect([stored(@"theme") isEqual:@"auto"] && automatic.accessoryType == UITableViewCellAccessoryCheckmark
		&& dark.accessoryType == UITableViewCellAccessoryNone,
		"tapping a choice stores it and moves the check", [stored(@"theme") description]);
	[root popViewControllerAnimated:NO];
	spinUntil(^BOOL { return [themeCell.detailTextLabel.text isEqual:@"Automatic"]; });
	expect([themeCell.detailTextLabel.text isEqual:@"Automatic"], "back on the page, the row shows the new choice", themeCell.detailTextLabel.text);

	// A link to a page of the app's own class.
	tap(cellOf(list, @"more"));
	spinUntil(^BOOL { return root.viewControllers.count == 2; });
	TestDetailController *detail = (TestDetailController *) root.topViewController;
	spinUntil(^BOOL { return detail.table.window != nil; });
	expect([detail isKindOfClass:[TestDetailController class]] && detail.parentController == list
		&& [detail.specifier.identifier isEqual:@"more"] && [detail.title isEqual:@"Detail"],
		"a link pushes its detail controller, with its parent and specifier; its plist names the page",
		[NSString stringWithFormat:@"%@ %@", NSStringFromClass([detail class]), detail.title]);
	[root popViewControllerAnimated:NO];

	// Changing the page's specifiers.
	PSSpecifier *added = [PSSpecifier preferenceSpecifierNamed:@"Added" target:list set:NULL get:NULL detail:Nil cell:PSStaticTextCell edit:Nil];
	added.identifier = @"added";
	[list insertSpecifier:added afterSpecifierID:@"respring" animated:YES];
	expect([table numberOfRowsInSection:3] == 4 && [[list indexPathForSpecifier:added] isEqual:[NSIndexPath indexPathForRow:2 inSection:3]]
		&& [cellOf(list, @"added").textLabel.text isEqual:@"Added"],
		"inserting a specifier adds its row", nil);
	[list removeSpecifierID:@"added" animated:YES];
	[list removeSpecifierID:@"version"];
	expect([table numberOfRowsInSection:3] == 2 && ![list containsSpecifier:added], "removing specifiers removes their rows", nil);
	[list addSpecifier:[PSSpecifier groupSpecifierWithHeader:@"New" footer:nil]];
	expect([table numberOfSections] == 5 && [[list tableView:table titleForHeaderInSection:4] isEqual:@"New"], "adding a group adds a section", nil);
	PSSpecifier *enabled = [list specifierForID:@"enabled"];
	[enabled setProperty:@NO forKey:PSEnabledKey];
	[list reloadSpecifier:enabled];
	expect(!enabledCell.cellEnabled && !toggle.enabled, "a specifier disabled and reloaded disables its control", nil);
	[list reloadSpecifiers];
	expect([list specifiers] == specifiers && [table numberOfSections] == 5, "reloadSpecifiers keeps the loaded specifiers", nil);

	NSArray *loaded = SpecifiersFromPlist(@{ @"items": @[ @{ @"cell": @"PSGroupCell", @"label": @"G" }, @{ @"cell": @"PSSwitchCell", @"label": @"S" } ] },
		nil, list, @"Root", sBundle, NULL, NULL, list, NULL);
	expect(loaded.count == 2 && [loaded[1] cellType] == PSSwitchCell && [loaded[1] target] == list, "SpecifiersFromPlist", nil);

	spin(3); // for a screenshot
	clearPreferences();
	[[NSFileManager defaultManager] removeItemAtPath:sBundle.bundlePath error:NULL];
	printf("%d failures\n", failures);
	exit(failures ? 1 : 0);
}

@end

int main(int argc, char *argv[])
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
