/* The iOS 8–14 UIKit API apps built with a current Xcode expect: scenes
   (this app has a scene manifest), trait collections, UIAlertController,
   UIStackView, UIVisualEffectView, UIMenu/UIAction and key commands,
   haptics, UIFontMetrics, UIStepper, UIViewPropertyAnimator and the spring
   and keyframe animation methods, UISearchController, UILocalNotification
   (through a usernotificationsd of its own) and diffable data sources.
   One PASS/FAIL line per check; exits nonzero on any failure. It leaves
   its last screen up for a few seconds, for a screenshot. See
   ios-uikit-modern.md. */

#import <UIKit/UIKit.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSWindow.h>
#include <spawn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

extern char **environ;

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

static BOOL near(CGFloat a, CGFloat b)
{
	return fabs(a - b) < 0.5;
}

static NSString *rect(CGRect r)
{
	return [NSString stringWithFormat:@"{%g,%g %gx%g}", r.origin.x, r.origin.y, r.size.width, r.size.height];
}

static void spin(NSTimeInterval seconds)
{
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

/* Timers are late on a slow machine: wait for what is expected. */
static BOOL spinUntil(NSTimeInterval limit, BOOL (^done)(void))
{
	NSDate *end = [NSDate dateWithTimeIntervalSinceNow:limit];
	while (!done() && [end timeIntervalSinceNow] > 0)
		spin(0.05);
	return done();
}

static NSTimeInterval sClock = 1000;

static NSEvent *pointer(NSEventType type, UIView *view, CGPoint point)
{
	NSPoint inWindow = [view convertPoint:NSMakePoint(point.x, point.y) toView:nil];
	return [NSEvent mouseEventWithType:type location:inWindow modifierFlags:0 timestamp:(sClock += 0.01)
	                      windowNumber:[[view window] windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1];
}

static void press(UIView *view, CGPoint point, NSTimeInterval hold)
{
	[view mouseDown:pointer(NSLeftMouseDown, view, point)];
	if (hold > 0)
		spin(hold);
	[view mouseUp:pointer(NSLeftMouseUp, view, point)];
}

static void tap(UIView *view, CGPoint point)
{
	press(view, point, 0);
}

/* The first view of a class in the tree. */
static id findView(NSView *root, Class cls)
{
	if ([root isKindOfClass:cls])
		return root;
	for (NSView *subview in [root subviews]) {
		id found = findView(subview, cls);
		if (found != nil)
			return found;
	}
	return nil;
}

static UIWindow *keyWindow(void)
{
	return [[UIApplication sharedApplication] keyWindow];
}

#pragma mark - What the app and its scene heard

static BOOL sAppDidBecomeActive, sActiveNotification, sAskedForConfiguration;
static NSMutableArray<NSString *> *sSceneEvents;
static UIScene *sScene;
static UISceneSession *sSession;
static NSString *sLocalNotificationBody;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
		sActiveNotification = YES;
	}];
	return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
	sAskedForConfiguration = YES;
	return [UISceneConfiguration configurationWithName:@"Default Configuration" sessionRole:[session role]];
}

/* With scenes, the scene's delegate hears this instead. */
- (void)applicationDidBecomeActive:(UIApplication *)application
{
	sAppDidBecomeActive = YES;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
	sLocalNotificationBody = [notification alertBody];
}

@end

static void runChecks(void);

@interface RootController : UIViewController
@property (nonatomic) int keyCommandsSent;
@property (nonatomic) UIUserInterfaceStyle styleSeen;
@end

@implementation RootController

- (void)loadView
{
	UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[view setBackgroundColor:[UIColor whiteColor]];
	[self setView:view];
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
	return @[ [UIKeyCommand keyCommandWithInput:@"k" modifierFlags:UIKeyModifierCommand action:@selector(commandK:)] ];
}

- (void)commandK:(UIKeyCommand *)command
{
	self.keyCommandsSent++;
}

@end

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
	[sSceneEvents addObject:@"connect"];
	sScene = scene;
	sSession = session;
	self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
	[self.window setRootViewController:[[RootController alloc] init]];
	[self.window makeKeyAndVisible];
	/* From a timer, not a main-queue block: the checks wait for what UIKit
	   sends from the main queue, which a block on it would hold up. */
	[self performSelector:@selector(startChecks) withObject:nil afterDelay:0];
}

- (void)startChecks
{
	runChecks();
}

- (void)sceneWillEnterForeground:(UIScene *)scene { [sSceneEvents addObject:@"foreground"]; }
- (void)sceneDidBecomeActive:(UIScene *)scene { [sSceneEvents addObject:@"active"]; }

@end

#pragma mark - Scenes

static void checkScenes(void)
{
	spinUntil(10, ^BOOL { return [sSceneEvents containsObject:@"active"]; });
	expect(sAskedForConfiguration, "the app delegate is asked for the scene's configuration", nil);
	expect([sSceneEvents isEqualToArray:@[ @"connect", @"foreground", @"active" ]], "the scene connects, enters the foreground and becomes active",
		[sSceneEvents componentsJoinedByString:@","]);
	expect([sScene isKindOfClass:[UIWindowScene class]] && [sScene activationState] == UISceneActivationStateForegroundActive,
		"it is an active window scene", nil);
	expect([[sSession configuration] delegateClass] == [SceneDelegate class] && [[[sSession configuration] name] isEqualToString:@"Default Configuration"],
		"the configuration got its delegate class from the Info.plist", NSStringFromClass([[sSession configuration] delegateClass]));
	expect([[[UIApplication sharedApplication] connectedScenes] containsObject:sScene] && [[[UIApplication sharedApplication] openSessions] count] == 1,
		"the application lists the scene and its session", nil);
	UIWindow *window = keyWindow();
	expect([window windowScene] == sScene && [[(UIWindowScene *)sScene windows] containsObject:window] && [(UIWindowScene *)sScene keyWindow] == window,
		"the window belongs to the scene", nil);
	expect(!sAppDidBecomeActive && sActiveNotification, "the app delegate's activation goes to the scene, the notification is still posted", nil);
}

#pragma mark - Traits

@interface TraitView : UIView
@property (nonatomic) int changes;
@property (nonatomic, strong) UITraitCollection *previous;
@end

@implementation TraitView
- (void)traitCollectionDidChange:(UITraitCollection *)previous
{
	self.changes++;
	self.previous = previous;
}
@end

static void checkTraits(UIView *root)
{
	UITraitCollection *traits = [root traitCollection];
	expect([traits userInterfaceIdiom] == UIUserInterfaceIdiomPhone && [traits userInterfaceStyle] == UIUserInterfaceStyleLight,
		"a view's traits: a phone, light", [traits description]);
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	UIUserInterfaceSizeClass vertical = screen.width > screen.height ? UIUserInterfaceSizeClassCompact : UIUserInterfaceSizeClassRegular;
	expect([traits horizontalSizeClass] == UIUserInterfaceSizeClassCompact && [traits verticalSizeClass] == vertical
		&& [traits displayScale] == [[UIScreen mainScreen] scale], "size classes and scale from the screen", nil);
	expect([[[root window] contentView] isKindOfClass:[UIWindow class]] && [[keyWindow() rootViewController] traitCollection] != nil,
		"controllers have traits", nil);

	TraitView *outer = [[TraitView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
	TraitView *inner = [[TraitView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
	[outer addSubview:inner];
	[root addSubview:outer];
	[outer setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
	expect([[inner traitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark && [inner changes] == 1
		&& [[inner previous] userInterfaceStyle] == UIUserInterfaceStyleLight, "an override reaches subviews, which hear of it", nil);
	[outer removeFromSuperview];

	__block UIUserInterfaceStyle resolvedFor = UIUserInterfaceStyleUnspecified;
	UIColor *dynamic = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *collection) {
		resolvedFor = [collection userInterfaceStyle];
		return [UIColor redColor];
	}];
	expect(dynamic != nil && resolvedFor == UIUserInterfaceStyleLight, "dynamic colors resolve for the current traits", nil);

	UITraitCollection *merged = [UITraitCollection traitCollectionWithTraitsFromCollections:@[
		[UITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassRegular],
		[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark] ]];
	expect([merged horizontalSizeClass] == UIUserInterfaceSizeClassRegular && [merged userInterfaceStyle] == UIUserInterfaceStyleDark
		&& [merged containsTraitsInCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]]
		&& ![merged containsTraitsInCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight]],
		"trait collections merge and contain", nil);
}

#pragma mark - UIAlertController

static void checkAlerts(UIViewController *root)
{
	__block NSString *typed = nil;
	__block BOOL presented = NO;
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename" message:@"A new name" preferredStyle:UIAlertControllerStyleAlert];
	[alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
		[field setPlaceholder:@"Name"];
	}];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		typed = [[[alert textFields] firstObject] text];
	}];
	[ok setEnabled:NO];
	[alert addAction:ok];
	[alert setPreferredAction:ok];
	BOOL raised = NO;
	@try {
		[alert addAction:[UIAlertAction actionWithTitle:@"Again" style:UIAlertActionStyleCancel handler:nil]];
	} @catch (NSException *exception) {
		raised = YES;
	}
	expect(raised, "a second cancel action raises", nil);
	[root presentViewController:alert animated:YES completion:^{
		presented = YES;
	}];
	spinUntil(5, ^BOOL { return presented; });
	UIAlertView *shown = findView(keyWindow(), [UIAlertView class]);
	expect(presented && [root presentedViewController] == alert && shown != nil, "an alert is presented and shown", nil);
	expect([shown textFieldAtIndex:0] == [[alert textFields] firstObject] && [shown numberOfButtons] == 2
		&& [[shown buttonTitleAtIndex:0] isEqualToString:@"Cancel"], "it shows the app's text field and its actions, cancel first", nil);
	[[[alert textFields] firstObject] setText:@"hello"];
	CGRect bounds = NSRectToCGRect([shown bounds]);
	CGPoint okPoint = CGPointMake(bounds.size.width * 0.75, bounds.size.height - 22);
	tap(shown, okPoint);
	spin(0.3);
	expect(typed == nil && [root presentedViewController] == alert, "a disabled action does nothing", nil);
	[ok setEnabled:YES];
	tap(shown, okPoint);
	spinUntil(5, ^BOOL { return typed != nil; });
	expect([typed isEqualToString:@"hello"] && [root presentedViewController] == nil && findView(keyWindow(), [UIAlertView class]) == nil,
		"choosing an action dismisses the alert, then runs its handler", typed);

	__block NSString *chosen = nil;
	UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:@"Delete the file?" preferredStyle:UIAlertControllerStyleActionSheet];
	[sheet addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { chosen = [action title]; }]];
	[sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { chosen = [action title]; }]];
	[root presentViewController:sheet animated:YES completion:nil];
	spin(0.2);
	UIActionSheet *actionSheet = findView(keyWindow(), [UIActionSheet class]);
	expect(actionSheet != nil && [actionSheet destructiveButtonIndex] == 0 && [actionSheet cancelButtonIndex] == 1,
		"an action sheet shows, destructive first and cancel apart", nil);
	CGRect sheetBounds = NSRectToCGRect([actionSheet bounds]);
	tap(actionSheet, CGPointMake(sheetBounds.size.width / 2, sheetBounds.size.height - 28));
	spinUntil(5, ^BOOL { return chosen != nil; });
	expect([chosen isEqualToString:@"Cancel"] && [root presentedViewController] == nil, "its cancel button runs the cancel action", chosen);

	UIAlertController *dismissed = [UIAlertController alertControllerWithTitle:@"Gone" message:nil preferredStyle:UIAlertControllerStyleAlert];
	__block BOOL ran = NO;
	[dismissed addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { ran = YES; }]];
	[root presentViewController:dismissed animated:NO completion:nil];
	spin(0.1);
	[root dismissViewControllerAnimated:NO completion:nil];
	spin(0.2);
	expect(!ran && findView(keyWindow(), [UIAlertView class]) == nil && [root presentedViewController] == nil,
		"dismissed by the app, it goes without running an action", nil);
}

#pragma mark - UIStackView

static UIView *box(CGFloat width)
{
	UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
	[view setBackgroundColor:[UIColor colorWithHue:width / 100.0 saturation:0.5 brightness:0.9 alpha:1]];
	if (width > 0)
		[[[view widthAnchor] constraintEqualToConstant:width] setActive:YES];
	return view;
}

static void layOut(UIView *view)
{
	[view setNeedsLayout];
	[view layoutIfNeeded];
}

static UIStackView *checkStacks(UIView *root)
{
	UIView *a = box(50), *b = box(60), *c = box(0);
	UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ a, b, c ]];
	[row setFrame:CGRectMake(10, 300, 300, 50)];
	[row setSpacing:10];
	[root addSubview:row];
	layOut(row);
	expect(near([a frame].origin.x, 0) && near([b frame].origin.x, 60) && near([c frame].origin.x, 130) && near([c frame].size.width, 170)
		&& near([a frame].size.height, 50), "a filled row: fixed widths, spacing, the rest to the last view",
		[NSString stringWithFormat:@"%@ %@ %@", rect([a frame]), rect([b frame]), rect([c frame])]);
	[b setHidden:YES];
	layOut(row);
	expect(near([c frame].origin.x, 60) && near([c frame].size.width, 240), "a hidden view takes no room", rect([c frame]));
	[b setHidden:NO];
	[row removeFromSuperview];

	UIStackView *equal = [[UIStackView alloc] initWithArrangedSubviews:@[ box(0), box(0), box(0) ]];
	[equal setDistribution:UIStackViewDistributionFillEqually];
	[equal setSpacing:10];
	[equal setFrame:CGRectMake(10, 360, 300, 40)];
	[root addSubview:equal];
	layOut(equal);
	NSArray *views = [equal arrangedSubviews];
	expect(near([[views objectAtIndex:0] frame].size.width, 280.0 / 3) && near([[views objectAtIndex:2] frame].origin.x, 2 * (280.0 / 3 + 10)),
		"fill equally", rect([[views objectAtIndex:2] frame]));
	[equal removeFromSuperview];

	UIStackView *spaced = [[UIStackView alloc] initWithArrangedSubviews:@[ box(50), box(50), box(50) ]];
	[spaced setDistribution:UIStackViewDistributionEqualSpacing];
	[spaced setFrame:CGRectMake(10, 360, 300, 40)];
	[root addSubview:spaced];
	layOut(spaced);
	views = [spaced arrangedSubviews];
	expect(near([[views objectAtIndex:1] frame].origin.x, 125) && near([[views objectAtIndex:2] frame].origin.x, 250), "equal spacing",
		rect([[views objectAtIndex:1] frame]));
	[spaced removeFromSuperview];

	UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
	[title setText:@"Stacked"];
	UIStepper *stepper = [[UIStepper alloc] initWithFrame:CGRectZero];
	UIStackView *column = [[UIStackView alloc] initWithArrangedSubviews:@[ title, stepper ]];
	[column setAxis:UILayoutConstraintAxisVertical];
	[column setAlignment:UIStackViewAlignmentCenter];
	[column setSpacing:8];
	[column setFrame:CGRectMake(10, 420, 300, 80)];
	[root addSubview:column];
	layOut(column);
	expect(near(CGRectGetMidX([title frame]), 150) && near(CGRectGetMidX([stepper frame]), 150) && near([stepper frame].size.width, 94)
		&& near([stepper frame].origin.y, CGRectGetMaxY([title frame]) + 8), "a centered column of intrinsic sizes",
		[NSString stringWithFormat:@"%@ %@", rect([title frame]), rect([stepper frame])]);
	return column;
}

#pragma mark - Small classes

static void checkSmallClasses(UIView *root)
{
	UIVisualEffectView *effect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
	UILabel *onEffect = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
	[effect addSubview:onEffect];
	expect([onEffect superview] == [effect contentView] && [[effect effect] isKindOfClass:[UIBlurEffect class]],
		"an effect view's subviews go in its content view", nil);

	UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
	[impact prepare];
	[impact impactOccurred];
	[[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
	[[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
	expect(YES, "feedback generators accept requests", nil);

	UIFont *body = [UIFont systemFontOfSize:17];
	UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
	expect([[metrics scaledFontForFont:body] pointSize] == 17 && [[metrics scaledFontForFont:body maximumPointSize:12] pointSize] == 12
		&& [[UIFontMetrics defaultMetrics] scaledValueForValue:20] == 20, "font metrics at the default size", nil);

	UIStepper *stepper = [[UIStepper alloc] initWithFrame:CGRectMake(20, 520, 0, 0)];
	[root addSubview:stepper];
	__block int changes = 0;
	[stepper addAction:[UIAction actionWithHandler:^(UIAction *action) { changes++; }] forControlEvents:UIControlEventValueChanged];
	[stepper setAutorepeat:NO];
	[stepper setMaximumValue:2];
	tap(stepper, CGPointMake(70, 16));
	tap(stepper, CGPointMake(70, 16));
	tap(stepper, CGPointMake(70, 16));
	expect([stepper value] == 2 && changes == 2, "a stepper steps up to its maximum", [NSString stringWithFormat:@"%g, %d changes", [stepper value], changes]);
	[stepper setWraps:YES];
	tap(stepper, CGPointMake(70, 16));
	tap(stepper, CGPointMake(20, 16));
	expect([stepper value] == 2, "a wrapping stepper goes round both ways", [NSString stringWithFormat:@"%g", [stepper value]]);
	[stepper setValue:-5];
	expect([stepper value] == 0 && near([stepper frame].size.width, 94), "its value is clamped and its size is iOS's", nil);
	[stepper removeFromSuperview];
}

#pragma mark - Animations

static void checkAnimations(UIView *root)
{
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
	[root addSubview:view];
	__block BOOL sprung = NO;
	[UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		[view setAlpha:0.5];
	} completion:^(BOOL finished) {
		sprung = finished;
	}];
	spinUntil(3, ^BOOL { return sprung; });
	expect(near([view alpha] * 10, 5) && sprung, "spring animations change and complete", nil);
	__block int keyframes = 0;
	[UIView animateKeyframesWithDuration:0.2 delay:0 options:0 animations:^{
		[UIView addKeyframeWithRelativeStartTime:0 relativeDuration:0.5 animations:^{ keyframes++; }];
		[UIView addKeyframeWithRelativeStartTime:0.5 relativeDuration:0.5 animations:^{ keyframes++; }];
	} completion:nil];
	expect(keyframes == 2, "keyframes run", nil);

	__block UIViewAnimatingPosition finishedAt = -1;
	UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.3 curve:UIViewAnimationCurveEaseInOut animations:^{
		[view setAlpha:0.2];
	}];
	[animator addCompletion:^(UIViewAnimatingPosition position) {
		finishedAt = position;
	}];
	BOOL before = near([view alpha] * 10, 5) && [animator state] == UIViewAnimatingStateInactive;
	[animator startAnimation];
	BOOL running = near([view alpha] * 10, 2) && [animator isRunning] && [animator state] == UIViewAnimatingStateActive;
	spinUntil(5, ^BOOL { return finishedAt != (UIViewAnimatingPosition)-1; });
	expect(before && running && finishedAt == UIViewAnimatingPositionEnd && [animator state] == UIViewAnimatingStateInactive,
		"a property animator applies its animations when started and finishes at the end", nil);

	__block UIViewAnimatingPosition stoppedAt = -1;
	UIViewPropertyAnimator *paused = [[UIViewPropertyAnimator alloc] initWithDuration:10 dampingRatio:0.8 animations:^{
		[view setAlpha:1];
	}];
	[paused addCompletion:^(UIViewAnimatingPosition position) { stoppedAt = position; }];
	[paused startAnimation];
	spin(0.2);
	[paused pauseAnimation];
	CGFloat fraction = [paused fractionComplete];
	[paused stopAnimation:NO];
	UIViewAnimatingState stoppedState = [paused state];
	[paused finishAnimationAtPosition:UIViewAnimatingPositionCurrent];
	expect(fraction > 0 && fraction < 0.5 && stoppedState == UIViewAnimatingStateStopped && stoppedAt == UIViewAnimatingPositionCurrent,
		"pausing keeps its progress; stopping and finishing at the current position", [NSString stringWithFormat:@"%g", fraction]);

	__block BOOL ranCompletion = NO;
	[UIViewPropertyAnimator runningPropertyAnimatorWithDuration:0.1 delay:0 options:0 animations:^{
		[view setAlpha:0.9];
	} completion:^(UIViewAnimatingPosition position) {
		ranCompletion = position == UIViewAnimatingPositionEnd;
	}];
	spinUntil(3, ^BOOL { return ranCompletion; });
	expect(ranCompletion && near([view alpha] * 10, 9), "a running property animator completes", nil);
	[view removeFromSuperview];
}

#pragma mark - Menus and key commands

@interface MenuProvider : NSObject <UIContextMenuInteractionDelegate>
@property (nonatomic, strong) UIMenu *menu;
@end

@implementation MenuProvider
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
	UIMenu *menu = self.menu;
	return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray *suggested) {
		return menu;
	}];
}
@end

static void checkMenus(UIViewController *controller)
{
	UIView *root = [controller view];
	__block id sentBy = nil;
	UIAction *primary = [UIAction actionWithTitle:@"Go" image:nil identifier:nil handler:^(UIAction *action) {
		sentBy = [action sender];
	}];
	UIButton *button = [UIButton systemButtonWithPrimaryAction:primary];
	[button setFrame:CGRectMake(20, 560, 100, 44)];
	[root addSubview:button];
	[button sendActionsForControlEvents:UIControlEventTouchUpInside];
	expect(sentBy == button && [[button titleForState:UIControlStateNormal] isEqualToString:@"Go"], "a button's primary action, sent by it", nil);
	sentBy = nil;
	[button removeAction:primary forControlEvents:UIControlEventTouchUpInside];
	[button sendActionsForControlEvents:UIControlEventTouchUpInside];
	expect(sentBy == nil, "a removed action is not sent", nil);

	__block NSString *picked = nil;
	UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[
		[UIAction actionWithTitle:@"Copy" image:nil identifier:nil handler:^(UIAction *action) { picked = [action title]; }],
		[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[
			[UIAction actionWithTitle:@"Share" image:nil identifier:nil handler:^(UIAction *action) { picked = [action title]; }] ]],
	]];
	UIAction *remove = [UIAction actionWithTitle:@"Delete" image:nil identifier:nil handler:^(UIAction *action) { picked = [action title]; }];
	[remove setAttributes:UIMenuElementAttributesDestructive];
	menu = [menu menuByReplacingChildren:[[menu children] arrayByAddingObject:remove]];
	UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
	[menuButton setMenu:menu];
	[menuButton setShowsMenuAsPrimaryAction:YES];
	[menuButton setFrame:CGRectMake(140, 560, 100, 44)];
	[root addSubview:menuButton];
	[menuButton sendActionsForControlEvents:UIControlEventTouchUpInside];
	UIActionSheet *sheet = findView(keyWindow(), [UIActionSheet class]);
	expect(sheet != nil && [sheet numberOfButtons] == 4 && [[sheet buttonTitleAtIndex:1] isEqualToString:@"Share"] && [sheet destructiveButtonIndex] == 2,
		"a button's menu shows, inline menus in line", [NSString stringWithFormat:@"%ld buttons", (long)[sheet numberOfButtons]]);
	tap(sheet, CGPointMake(50, 57 + 28));
	spinUntil(3, ^BOOL { return picked != nil; });
	expect([picked isEqualToString:@"Share"] && findView(keyWindow(), [UIActionSheet class]) == nil, "choosing a menu row runs its action", picked);

	picked = nil;
	UIView *target = [[UIView alloc] initWithFrame:CGRectMake(260, 560, 44, 44)];
	[root addSubview:target];
	MenuProvider *provider = [[MenuProvider alloc] init];
	[provider setMenu:menu];
	UIContextMenuInteraction *interaction;
	interaction = [[UIContextMenuInteraction alloc] initWithDelegate:provider];
	[target addInteraction:interaction];
	press(target, CGPointMake(22, 22), 0.9);
	sheet = findView(keyWindow(), [UIActionSheet class]);
	expect([[target interactions] containsObject:interaction] && sheet != nil, "a long press shows a context menu", nil);
	if (sheet != nil)
		tap(sheet, CGPointMake(50, 28));
	spinUntil(3, ^BOOL { return picked != nil; });
	expect([picked isEqualToString:@"Copy"], "its action runs", picked);
	[target removeInteraction:interaction];
	expect([[target interactions] count] == 0, "interactions come off", nil);

	RootController *rootController = (RootController *)controller;
	NSEvent *key = [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:(sClock += 0.01)
		windowNumber:[[root window] windowNumber] context:nil characters:@"k" charactersIgnoringModifiers:@"k" isARepeat:NO keyCode:40];
	[NSApp sendEvent:key];
	NSEvent *plain = [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:0 timestamp:(sClock += 0.01)
		windowNumber:[[root window] windowNumber] context:nil characters:@"k" charactersIgnoringModifiers:@"k" isARepeat:NO keyCode:40];
	[NSApp sendEvent:plain];
	expect([rootController keyCommandsSent] == 1, "a key command is sent for its key and modifiers only",
		[NSString stringWithFormat:@"%d", [rootController keyCommandsSent]]);
	[button removeFromSuperview];
	[menuButton removeFromSuperview];
	[target removeFromSuperview];
}

#pragma mark - UISearchController

@interface SearchUpdater : NSObject <UISearchResultsUpdating>
@property (nonatomic) int updates;
@property (nonatomic, copy) NSString *lastText;
@end

@implementation SearchUpdater
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
	self.updates++;
	self.lastText = [[searchController searchBar] text];
}
@end

static void checkSearch(UIWindow *window)
{
	UIViewController *previousRoot = [window rootViewController];
	UIViewController *list = [[UIViewController alloc] init];
	[[list view] setBackgroundColor:[UIColor whiteColor]];
	UIViewController *results = [[UIViewController alloc] init];
	[[results view] setBackgroundColor:[UIColor colorWithRed:0.9 green:0.95 blue:1 alpha:1]];
	UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:results];
	SearchUpdater *updater = [[SearchUpdater alloc] init];
	[search setSearchResultsUpdater:updater];
	[[list navigationItem] setSearchController:search];
	[list setTitle:@"Search"];
	UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:list];
	[window setRootViewController:navigation];
	[[navigation view] layoutSubtreeIfNeeded];
	spin(0.2);
	UISearchBar *bar = [search searchBar];
	CGRect navigationBar = NSRectToCGRect([[navigation navigationBar] frame]);
	CGRect barFrame = NSRectToCGRect([bar frame]);
	expect([bar superview] == [navigation view] && near(barFrame.origin.y, CGRectGetMaxY(navigationBar))
		&& near([[list view] frame].origin.y, CGRectGetMaxY(barFrame)), "the search bar sits under the navigation bar, the content under it",
		[NSString stringWithFormat:@"%@ %@ %@", rect(navigationBar), rect(barFrame), rect([[list view] frame])]);
	[bar becomeFirstResponder];
	spin(0.1);
	if (![search isActive])
		[search setActive:YES];
	expect([search isActive] && [updater updates] >= 1 && [bar showsCancelButton], "editing the bar activates the search", nil);
	expect([[results view] window] == [bar window] && near([[results view] frame].origin.y, NSMaxY([[[bar window] contentView] convertRect:[bar bounds] fromView:bar])),
		"the results cover the window below the bar", rect([[results view] frame]));
	[[bar searchField] setText:@"abc"];
	[[bar searchField] sendActionsForControlEvents:UIControlEventEditingChanged];
	expect([[updater lastText] isEqualToString:@"abc"], "the updater hears of each change", [updater lastText]);
	UIButton *cancel = nil;
	for (NSView *subview in [bar subviews])
		if ([subview isKindOfClass:[UIButton class]])
			cancel = (UIButton *)subview;
	[cancel sendActionsForControlEvents:UIControlEventTouchUpInside];
	expect(![search isActive] && [[results view] superview] == nil && [[bar text] length] == 0, "cancel ends the search", nil);
	[window setRootViewController:previousRoot];
}

#pragma mark - UILocalNotification

static void checkLocalNotifications(void)
{
	UIApplication *application = [UIApplication sharedApplication];
	[application cancelAllLocalNotifications];
	UILocalNotification *later = [[UILocalNotification alloc] init];
	[later setFireDate:[NSDate dateWithTimeIntervalSinceNow:3600]];
	[later setAlertBody:@"Later"];
	[later setUserInfo:@{ @"id": @7 }];
	[application scheduleLocalNotification:later];
	__block NSArray *scheduled = nil;
	spinUntil(5, ^BOOL {
		scheduled = [application scheduledLocalNotifications];
		return [scheduled count] > 0;
	});
	UILocalNotification *back = [scheduled firstObject];
	expect([scheduled count] == 1 && [[back alertBody] isEqualToString:@"Later"] && [[back userInfo] isEqual:@{ @"id": @7 }] && [back isEqual:later]
		&& fabs([[back fireDate] timeIntervalSinceDate:[later fireDate]]) < 2, "a scheduled notification comes back as it was", [back description]);
	[application cancelLocalNotification:later];
	spinUntil(5, ^BOOL { return [[application scheduledLocalNotifications] count] == 0; });
	expect([[application scheduledLocalNotifications] count] == 0, "cancelling it", nil);

	UILocalNotification *now = [[UILocalNotification alloc] init];
	[now setAlertBody:@"Now"];
	[application presentLocalNotificationNow:now];
	spinUntil(10, ^BOOL { return sLocalNotificationBody != nil; });
	expect([sLocalNotificationBody isEqualToString:@"Now"], "one presented now reaches application:didReceiveLocalNotification:", sLocalNotificationBody);
}

#pragma mark - Diffable data sources

static void checkDiffable(UIView *root)
{
	UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 300, 300) style:UITableViewStylePlain];
	[table registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
	UITableViewDiffableDataSource *source = [[UITableViewDiffableDataSource alloc] initWithTableView:table cellProvider:^UITableViewCell *(UITableView *tableView, NSIndexPath *indexPath, id item) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
		[[cell textLabel] setText:[item description]];
		return cell;
	}];
	expect([table dataSource] == source, "the data source makes itself the table's", nil);
	NSDiffableDataSourceSnapshot *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
	[snapshot appendSectionsWithIdentifiers:@[ @"fruit", @"veg" ]];
	[snapshot appendItemsWithIdentifiers:@[ @"apple", @"cherry" ] intoSectionWithIdentifier:@"fruit"];
	[snapshot insertItemsWithIdentifiers:@[ @"banana" ] afterItemWithIdentifier:@"apple"];
	[snapshot appendItemsWithIdentifiers:@[ @"leek" ]];
	BOOL raised = NO;
	@try {
		[snapshot appendItemsWithIdentifiers:@[ @"apple" ]];
	} @catch (NSException *exception) {
		raised = YES;
	}
	expect(raised && [snapshot numberOfItems] == 4 && [[snapshot itemIdentifiersInSectionWithIdentifier:@"fruit"] isEqualToArray:(@[ @"apple", @"banana", @"cherry" ])]
		&& [[snapshot sectionIdentifierForSectionContainingItemIdentifier:@"leek"] isEqual:@"veg"] && [snapshot indexOfItemIdentifier:@"leek"] == 3,
		"a snapshot keeps sections and unique items in order", nil);
	[snapshot moveItemWithIdentifier:@"cherry" beforeItemWithIdentifier:@"apple"];
	[snapshot deleteItemsWithIdentifiers:@[ @"banana" ]];
	expect([[snapshot itemIdentifiers] isEqualToArray:(@[ @"cherry", @"apple", @"leek" ])], "moving and deleting items", [[snapshot itemIdentifiers] componentsJoinedByString:@","]);
	__block BOOL applied = NO;
	[source applySnapshot:snapshot animatingDifferences:YES completion:^{ applied = YES; }];
	spinUntil(3, ^BOOL { return applied; });
	NSIndexPath *leek = [source indexPathForItemIdentifier:@"leek"];
	UITableViewCell *cell = [source tableView:table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
	expect(applied && [source numberOfSectionsInTableView:table] == 2 && [source tableView:table numberOfRowsInSection:0] == 2
		&& [leek section] == 1 && [leek row] == 0 && [[source itemIdentifierForIndexPath:leek] isEqual:@"leek"]
		&& [[[cell textLabel] text] isEqualToString:@"apple"] && [[[source snapshot] itemIdentifiers] count] == 3,
		"applying a snapshot: sections, rows and cells from it", [[cell textLabel] text]);

	UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
	UICollectionView *collection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 300, 300) collectionViewLayout:layout];
	[collection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
	UICollectionViewDiffableDataSource *grid = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:collection cellProvider:^UICollectionViewCell *(UICollectionView *view, NSIndexPath *indexPath, id item) {
		return [view dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
	}];
	NSDiffableDataSourceSnapshot *tiles = [[NSDiffableDataSourceSnapshot alloc] init];
	[tiles appendSectionsWithIdentifiers:@[ @0 ]];
	[tiles appendItemsWithIdentifiers:@[ @1, @2, @3 ]];
	[grid applySnapshotUsingReloadData:tiles];
	expect([collection dataSource] == grid && [grid collectionView:collection numberOfItemsInSection:0] == 3
		&& [[grid itemIdentifierForIndexPath:[NSIndexPath indexPathForItem:2 inSection:0]] isEqual:@3], "a collection view's diffable data source", nil);
}

#pragma mark - Running them

static void runChecks(void)
{
	UIWindow *window = keyWindow();
	RootController *root = (RootController *)[window rootViewController];
	checkScenes();
	checkTraits([root view]);
	checkAlerts(root);
	UIStackView *column = checkStacks([root view]);
	checkSmallClasses([root view]);
	checkAnimations([root view]);
	checkMenus(root);
	checkSearch(window);
	checkLocalNotifications();
	checkDiffable([root view]);

	/* Something to look at: a blurred band over the stack, and an alert. */
	UIVisualEffectView *band = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
	[band setFrame:CGRectMake(0, 120, [[root view] bounds].size.width, 120)];
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, 300, 40)];
	[label setText:[NSString stringWithFormat:@"%d failures", failures]];
	[label setTextColor:[UIColor whiteColor]];
	[band addSubview:label];
	[[root view] addSubview:band];
	[column setFrame:CGRectMake(10, 300, [[root view] bounds].size.width - 20, 80)];
	UIAlertController *done = [UIAlertController alertControllerWithTitle:@"Modern UIKit" message:[NSString stringWithFormat:@"%d failures", failures]
		preferredStyle:UIAlertControllerStyleAlert];
	[done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[root presentViewController:done animated:YES completion:nil];
	printf("%d failures\n", failures);
	fflush(stdout);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		exit(failures ? 1 : 0);
	});
}

static pid_t sDaemon;

static void stopDaemon(void)
{
	if (sDaemon > 0)
		kill(sDaemon, SIGTERM);
}

int main(int argc, char **argv)
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		sSceneEvents = [NSMutableArray array];
		/* A usernotificationsd of its own, as ios-usernotifications.m runs. */
		NSString *home = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"modern-%d", getpid()]];
		[[NSFileManager defaultManager] createDirectoryAtPath:home withIntermediateDirectories:YES attributes:nil error:NULL];
		NSString *socket = [home stringByAppendingPathComponent:@"un.sock"];
		setenv("USERNOTIFICATIONS_SOCKET", [socket fileSystemRepresentation], 1);
		setenv("USERNOTIFICATIONS_STORE", [[home stringByAppendingPathComponent:@"Notifications.plist"] fileSystemRepresentation], 1);
		setenv("FRONTBOARD_SOCKET", [[home stringByAppendingPathComponent:@"none.sock"] fileSystemRepresentation], 1);
		char *daemonArgv[] = { "/usr/libexec/usernotificationsd", NULL };
		posix_spawn(&sDaemon, daemonArgv[0], NULL, NULL, daemonArgv, environ);
		atexit(stopDaemon);
		spinUntil(10, ^BOOL { return [[NSFileManager defaultManager] fileExistsAtPath:socket]; });
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
