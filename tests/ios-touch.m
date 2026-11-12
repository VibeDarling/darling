/* Touch screens: fingers reported the way a windowing backend reports them
   (NSTouchPost), through AppKit's event queue and NSWindow, to UIKit's
   views and gesture recognizers, and to plain AppKit views as the mouse.
   One PASS/FAIL line per check; exits nonzero on any failure. See
   ios-touch.md. */

#import <UIKit/UIKit.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSTouch.h>
#import <AppKit/NSView.h>
#import <AppKit/NSWindow.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

static BOOL near(CGFloat a, CGFloat b, CGFloat within)
{
	return fabs(a - b) <= within;
}

/* Hands every queued event to the application, as its run loop would. */
static void pump(void)
{
	NSEvent *event;
	while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]
	                                      inMode:NSDefaultRunLoopMode dequeue:YES]) != nil)
		[NSApp sendEvent:event];
}

static void spin(NSTimeInterval seconds)
{
	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
	while ([limit timeIntervalSinceNow] > 0) {
		pump();
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
	}
}

static NSTimeInterval sClock = 5000;

/* Finger n goes down, moves or lifts at a point of view. */
static void finger(NSInteger n, NSTouchPhase phase, NSView *view, CGPoint point)
{
	NSPoint inWindow = [view convertPoint:NSMakePoint(point.x, point.y) toView:nil];
	NSTouchPost([view window], n, phase, inWindow, sClock += 0.01);
	pump();
}

static void fingerTap(NSInteger n, NSView *view, CGPoint point)
{
	finger(n, NSTouchPhaseBegan, view, point);
	finger(n, NSTouchPhaseEnded, view, point);
}

/* Two fingers move together in steps, from a pair of points to another. */
static void twoFingers(NSView *view, CGPoint a0, CGPoint b0, CGPoint a1, CGPoint b1, int steps, BOOL lift)
{
	finger(1, NSTouchPhaseBegan, view, a0);
	finger(2, NSTouchPhaseBegan, view, b0);
	for (int i = 1; i <= steps; i++) {
		CGFloat t = (CGFloat)i / steps;
		finger(1, NSTouchPhaseMoved, view, CGPointMake(a0.x + (a1.x - a0.x) * t, a0.y + (a1.y - a0.y) * t));
		finger(2, NSTouchPhaseMoved, view, CGPointMake(b0.x + (b1.x - b0.x) * t, b0.y + (b1.y - b0.y) * t));
	}
	if (lift) {
		finger(1, NSTouchPhaseEnded, view, a1);
		finger(2, NSTouchPhaseEnded, view, b1);
	}
}

/* Records what it is sent. */
@interface Pad : UIView
@property (nonatomic) int began, moved, ended, cancelled;
@property (nonatomic) NSUInteger mostTouches, lastTapCount;
@property (nonatomic) CGPoint lastPoint;
@property (nonatomic) BOOL sawStationary;
@end

@implementation Pad
- (void)note:(NSSet *)touches event:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	_lastPoint = [touch locationInView:self];
	_mostTouches = MAX(_mostTouches, [[event allTouches] count]);
	for (UITouch *other in [event allTouches])
		if ([other phase] == UITouchPhaseStationary)
			_sawStationary = YES;
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	_began++;
	_lastTapCount = [[touches anyObject] tapCount];
	[self note:touches event:event];
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event { _moved++; [self note:touches event:event]; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { _ended++; [self note:touches event:event]; }
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event { _cancelled++; }
@end

/* A plain AppKit view: takes no touches, so fingers come as the mouse. */
@interface Plain : NSView
@property (nonatomic) int downs, drags, ups;
@property (nonatomic) NSInteger lastClicks;
@end

@implementation Plain
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event { _downs++; _lastClicks = [event clickCount]; }
- (void)mouseDragged:(NSEvent *)event { _drags++; }
- (void)mouseUp:(NSEvent *)event { _ups++; }
@end

/* An AppKit view that asks for direct touches. */
@interface Toucher : NSView
@property (nonatomic) int began, ended;
@property (nonatomic) NSPoint location;
@property (nonatomic) NSTouchType type;
@end

@implementation Toucher
- (void)touchesBeganWithEvent:(NSEvent *)event
{
	_began++;
	NSTouch *touch = [[event touchesMatchingPhase:NSTouchPhaseBegan inView:self] anyObject];
	_location = [touch locationInView:self];
	_type = [touch type];
}
- (void)touchesEndedWithEvent:(NSEvent *)event { _ended++; }
@end

@interface Recorder : NSObject
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic) CGFloat scale, rotation;
@property (nonatomic) CGPoint translation;
@property (nonatomic) CGFloat largestJump;
@end

@implementation Recorder
- (instancetype)init { if ((self = [super init])) _events = [NSMutableArray array]; return self; }
- (void)fired:(UIGestureRecognizer *)recognizer
{
	[_events addObject:[NSString stringWithFormat:@"%@:%ld", NSStringFromClass([recognizer class]), (long)[recognizer state]]];
}
- (void)pinched:(UIPinchGestureRecognizer *)recognizer { _scale = [recognizer scale]; [self fired:recognizer]; }
- (void)rotated:(UIRotationGestureRecognizer *)recognizer { _rotation = [recognizer rotation]; [self fired:recognizer]; }
- (void)panned:(UIPanGestureRecognizer *)recognizer
{
	CGPoint translation = [recognizer translationInView:[recognizer view]];
	if ([recognizer state] == UIGestureRecognizerStateChanged)
		_largestJump = MAX(_largestJump, hypot(translation.x - _translation.x, translation.y - _translation.y));
	_translation = translation;
	[self fired:recognizer];
}
- (void)button:(id)sender { [_events addObject:@"button"]; }
- (void)single:(UIGestureRecognizer *)recognizer { [_events addObject:@"single"]; }
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (Pad *)padIn:(UIView *)root
{
	for (UIView *view in [[root subviews] copy])
		[view removeFromSuperview];
	Pad *pad = [[Pad alloc] initWithFrame:CGRectMake(20, 20, 280, 280)];
	[root addSubview:pad];
	return pad;
}

- (void)checksIn:(UIView *)root
{
	/* One finger. */
	Pad *pad = [self padIn:root];
	finger(1, NSTouchPhaseBegan, pad, CGPointMake(50, 60));
	finger(1, NSTouchPhaseMoved, pad, CGPointMake(70, 90));
	expect([pad began] == 1 && [pad moved] == 1, "a finger begins and moves in the view under it",
	       [NSString stringWithFormat:@"began %d moved %d", [pad began], [pad moved]]);
	expect(near([pad lastPoint].x, 70, 0.5) && near([pad lastPoint].y, 90, 0.5), "its location, in the view's coordinates",
	       NSStringFromCGPoint([pad lastPoint]));
	finger(1, NSTouchPhaseEnded, pad, CGPointMake(70, 90));
	expect([pad ended] == 1 && [pad lastTapCount] == 1, "it ends, as one tap", nil);
	sClock += 1;
	fingerTap(1, pad, CGPointMake(100, 100));
	fingerTap(1, pad, CGPointMake(102, 101));
	expect([pad lastTapCount] == 2, "a quick second tap in the same place counts two",
	       [NSString stringWithFormat:@"%lu", (unsigned long)[pad lastTapCount]]);
	sClock += 1;

	/* Two fingers on a view with multiple touches. */
	pad = [self padIn:root];
	[pad setMultipleTouchEnabled:YES];
	finger(1, NSTouchPhaseBegan, pad, CGPointMake(50, 50));
	finger(2, NSTouchPhaseBegan, pad, CGPointMake(150, 150));
	finger(2, NSTouchPhaseMoved, pad, CGPointMake(160, 160));
	expect([pad began] == 2 && [pad mostTouches] == 2, "two fingers on a multiple-touch view, both in the event",
	       [NSString stringWithFormat:@"began %d, %lu in the event", [pad began], (unsigned long)[pad mostTouches]]);
	expect([pad sawStationary], "the finger that did not move is stationary", nil);
	finger(1, NSTouchPhaseEnded, pad, CGPointMake(50, 50));
	finger(2, NSTouchPhaseEnded, pad, CGPointMake(160, 160));
	expect([pad ended] == 2, "both end", nil);

	/* Without multiple touches, the view gets only the first finger. */
	pad = [self padIn:root];
	finger(1, NSTouchPhaseBegan, pad, CGPointMake(50, 50));
	finger(2, NSTouchPhaseBegan, pad, CGPointMake(150, 150));
	finger(2, NSTouchPhaseEnded, pad, CGPointMake(150, 150));
	finger(1, NSTouchPhaseEnded, pad, CGPointMake(50, 50));
	expect([pad began] == 1 && [pad ended] == 1, "a view without multiple touches gets only the first finger",
	       [NSString stringWithFormat:@"began %d ended %d", [pad began], [pad ended]]);

	/* An exclusive view shuts the others out. */
	pad = [self padIn:root];
	[pad setFrame:CGRectMake(0, 0, 150, 300)];
	Pad *other = [[Pad alloc] initWithFrame:CGRectMake(160, 0, 150, 300)];
	[root addSubview:other];
	[pad setExclusiveTouch:YES];
	finger(1, NSTouchPhaseBegan, pad, CGPointMake(50, 50));
	finger(2, NSTouchPhaseBegan, other, CGPointMake(50, 50));
	finger(2, NSTouchPhaseEnded, other, CGPointMake(50, 50));
	finger(1, NSTouchPhaseEnded, pad, CGPointMake(50, 50));
	expect([pad began] == 1 && [other began] == 0, "an exclusive view's finger shuts out another view's",
	       [NSString stringWithFormat:@"exclusive %d, other %d", [pad began], [other began]]);

	/* Cancelling, as when the compositor takes the touch screen. */
	pad = [self padIn:root];
	finger(1, NSTouchPhaseBegan, pad, CGPointMake(50, 50));
	NSTouchCancelAll(nil);
	pump();
	expect([pad cancelled] == 1, "a cancelled finger cancels the view's touch", nil);

	/* A two-finger tap, which a one-finger tap does not take. */
	Recorder *recorder = [[Recorder alloc] init];
	pad = [self padIn:root];
	UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:recorder action:@selector(fired:)];
	[twoTap setNumberOfTouchesRequired:2];
	UITapGestureRecognizer *oneTap = [[UITapGestureRecognizer alloc] initWithTarget:recorder action:@selector(single:)];
	[pad addGestureRecognizer:twoTap];
	[pad addGestureRecognizer:oneTap];
	finger(1, NSTouchPhaseBegan, pad, CGPointMake(100, 100));
	finger(2, NSTouchPhaseBegan, pad, CGPointMake(140, 100));
	finger(1, NSTouchPhaseEnded, pad, CGPointMake(100, 100));
	finger(2, NSTouchPhaseEnded, pad, CGPointMake(140, 100));
	expect([[recorder events] isEqual:@[@"UITapGestureRecognizer:3"]],
	       "a two-finger tap recognizes, and the one-finger tap does not", [[recorder events] componentsJoinedByString:@" "]);
	[[recorder events] removeAllObjects];
	sClock += 1;
	fingerTap(1, pad, CGPointMake(100, 100));
	expect([[recorder events] isEqual:@[@"single"]],
	       "one finger still taps the one-finger tap", [[recorder events] componentsJoinedByString:@" "]);
	sClock += 1;

	/* Pinch: the fingers end twice as far apart. */
	recorder = [[Recorder alloc] init];
	pad = [self padIn:root];
	UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:recorder action:@selector(pinched:)];
	[pad addGestureRecognizer:pinch];
	twoFingers(pad, CGPointMake(90, 140), CGPointMake(190, 140), CGPointMake(40, 140), CGPointMake(240, 140), 10, YES);
	expect(near([recorder scale], 2, 0.02), "pinching apart to twice the distance scales by two",
	       [NSString stringWithFormat:@"%.3f", [recorder scale]]);
	expect([[[recorder events] firstObject] isEqual:@"UIPinchGestureRecognizer:1"]
	           && [[[recorder events] lastObject] isEqual:@"UIPinchGestureRecognizer:3"] && [[recorder events] count] > 3,
	       "the pinch begins, changes and ends", [[recorder events] componentsJoinedByString:@" "]);
	expect([pad began] == 1 && [pad cancelled] == 1, "a recognized pinch cancels the view's touch",
	       [NSString stringWithFormat:@"began %d cancelled %d", [pad began], [pad cancelled]]);

	/* A pinch whose app resets the scale reports changes from there. */
	recorder = [[Recorder alloc] init];
	pad = [self padIn:root];
	pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:recorder action:@selector(pinched:)];
	[pad addGestureRecognizer:pinch];
	twoFingers(pad, CGPointMake(40, 140), CGPointMake(240, 140), CGPointMake(90, 140), CGPointMake(190, 140), 10, NO);
	CGFloat closed = [pinch scale];
	[pinch setScale:1];
	finger(1, NSTouchPhaseMoved, pad, CGPointMake(115, 140));
	finger(2, NSTouchPhaseMoved, pad, CGPointMake(165, 140));
	expect(near(closed, 0.5, 0.02) && near([pinch scale], 0.5, 0.02), "pinching in halves the scale, and again from a reset scale",
	       [NSString stringWithFormat:@"%.3f then %.3f", closed, [pinch scale]]);
	finger(1, NSTouchPhaseEnded, pad, CGPointMake(115, 140));
	finger(2, NSTouchPhaseEnded, pad, CGPointMake(165, 140));

	/* Rotation: a quarter turn clockwise on screen. */
	recorder = [[Recorder alloc] init];
	pad = [self padIn:root];
	UIRotationGestureRecognizer *rotation = [[UIRotationGestureRecognizer alloc] initWithTarget:recorder action:@selector(rotated:)];
	[pad addGestureRecognizer:rotation];
	finger(1, NSTouchPhaseBegan, pad, CGPointMake(140, 140));
	finger(2, NSTouchPhaseBegan, pad, CGPointMake(240, 140));
	for (int i = 1; i <= 12; i++) {
		CGFloat angle = M_PI_2 * i / 12;
		/* Down the screen is clockwise from the right. */
		finger(2, NSTouchPhaseMoved, pad, CGPointMake(140 + 100 * cos(angle), 140 + 100 * sin(angle)));
	}
	finger(1, NSTouchPhaseEnded, pad, CGPointMake(140, 140));
	finger(2, NSTouchPhaseEnded, pad, CGPointMake(140, 240));
	expect(near([recorder rotation], M_PI_2, 0.02), "a quarter turn clockwise is a rotation of +pi/2",
	       [NSString stringWithFormat:@"%.3f", [recorder rotation]]);
	expect([[[recorder events] lastObject] isEqual:@"UIRotationGestureRecognizer:3"], "the rotation ends",
	       [[recorder events] componentsJoinedByString:@" "]);

	/* A two-finger pan: one finger does not move it. */
	recorder = [[Recorder alloc] init];
	pad = [self padIn:root];
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:recorder action:@selector(panned:)];
	[pan setMinimumNumberOfTouches:2];
	[pad addGestureRecognizer:pan];
	finger(1, NSTouchPhaseBegan, pad, CGPointMake(100, 100));
	finger(1, NSTouchPhaseMoved, pad, CGPointMake(100, 160));
	finger(1, NSTouchPhaseEnded, pad, CGPointMake(100, 160));
	expect([[recorder events] count] == 0, "a two-finger pan ignores one finger", [[recorder events] componentsJoinedByString:@" "]);
	twoFingers(pad, CGPointMake(100, 100), CGPointMake(150, 100), CGPointMake(100, 160), CGPointMake(150, 160), 6, YES);
	expect(near([recorder translation].x, 0, 0.5) && near(fabs([recorder translation].y), 60, 0.5)
	           && [[[recorder events] lastObject] isEqual:@"UIPanGestureRecognizer:3"],
	       "two fingers pan it by the distance they moved", NSStringFromCGPoint([recorder translation]));

	/* A second finger joining a pan does not make it jump. */
	recorder = [[Recorder alloc] init];
	pad = [self padIn:root];
	pan = [[UIPanGestureRecognizer alloc] initWithTarget:recorder action:@selector(panned:)];
	[pad addGestureRecognizer:pan];
	finger(1, NSTouchPhaseBegan, pad, CGPointMake(50, 50));
	for (int i = 1; i <= 5; i++)
		finger(1, NSTouchPhaseMoved, pad, CGPointMake(50 + 10 * i, 50));
	finger(2, NSTouchPhaseBegan, pad, CGPointMake(250, 250));
	for (int i = 1; i <= 5; i++) {
		finger(1, NSTouchPhaseMoved, pad, CGPointMake(100 + 10 * i, 50));
		finger(2, NSTouchPhaseMoved, pad, CGPointMake(250 + 10 * i, 250));
	}
	finger(1, NSTouchPhaseEnded, pad, CGPointMake(150, 50));
	finger(2, NSTouchPhaseEnded, pad, CGPointMake(300, 250));
	expect([recorder largestJump] <= 10.5 && near(fabs([recorder translation].x), 100, 1),
	       "a finger joining a pan moves it on smoothly",
	       [NSString stringWithFormat:@"largest step %.1f, translation %@", [recorder largestJump], NSStringFromCGPoint([recorder translation])]);

	/* Controls take fingers like the mouse. */
	recorder = [[Recorder alloc] init];
	[self padIn:root];
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	[button setFrame:CGRectMake(20, 20, 120, 44)];
	[button setTitle:@"Tap" forState:UIControlStateNormal];
	[button addTarget:recorder action:@selector(button:) forControlEvents:UIControlEventTouchUpInside];
	[root addSubview:button];
	fingerTap(1, button, CGPointMake(60, 22));
	expect([[recorder events] isEqual:@[@"button"]], "a finger taps a button", [[recorder events] componentsJoinedByString:@" "]);
	sClock += 1;

	/* Plain AppKit views get the first finger as the mouse. */
	[self padIn:root];
	Plain *plain = [[Plain alloc] initWithFrame:NSMakeRect(20, 20, 200, 200)];
	[root addSubview:plain];
	finger(1, NSTouchPhaseBegan, plain, CGPointMake(50, 50));
	finger(2, NSTouchPhaseBegan, plain, CGPointMake(100, 100));
	finger(1, NSTouchPhaseMoved, plain, CGPointMake(60, 60));
	finger(2, NSTouchPhaseEnded, plain, CGPointMake(100, 100));
	finger(1, NSTouchPhaseEnded, plain, CGPointMake(60, 60));
	expect([plain downs] == 1 && [plain drags] == 1 && [plain ups] == 1, "a plain AppKit view gets the first finger as the mouse",
	       [NSString stringWithFormat:@"down %d drag %d up %d", [plain downs], [plain drags], [plain ups]]);
	fingerTap(1, plain, CGPointMake(80, 80));
	fingerTap(1, plain, CGPointMake(82, 80));
	expect([plain lastClicks] == 2, "a double tap is a double click", [NSString stringWithFormat:@"%ld", (long)[plain lastClicks]]);
	sClock += 1;

	/* And AppKit views that ask for direct touches get NSTouches. */
	Toucher *toucher = [[Toucher alloc] initWithFrame:NSMakeRect(20, 230, 200, 60)];
	[toucher setAllowedTouchTypes:NSTouchTypeMaskDirect];
	[root addSubview:toucher];
	NSPoint inside = NSMakePoint(30, 20);
	fingerTap(1, toucher, CGPointMake(inside.x, inside.y));
	expect([toucher began] == 1 && [toucher ended] == 1 && [toucher type] == NSTouchTypeDirect
	           && near([toucher location].x, inside.x, 0.5) && near([toucher location].y, inside.y, 0.5),
	       "an AppKit view asking for direct touches gets NSTouches", NSStringFromPoint([toucher location]));

	/* The mouse is still a finger. */
	pad = [self padIn:root];
	NSPoint at = [pad convertPoint:NSMakePoint(30, 30) toView:nil];
	[NSApp postEvent:[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:at modifierFlags:0 timestamp:sClock
	                                windowNumber:[[pad window] windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1] atStart:NO];
	[NSApp postEvent:[NSEvent mouseEventWithType:NSEventTypeLeftMouseUp location:at modifierFlags:0 timestamp:sClock + 0.05
	                                windowNumber:[[pad window] windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1] atStart:NO];
	pump();
	expect([pad began] == 1 && [pad ended] == 1, "the mouse still touches", [NSString stringWithFormat:@"began %d ended %d", [pad began], [pad ended]]);
}

/* With DARLING_TOUCH_SCREEN set, waits for real fingers instead: a full
   screen pad with a pinch and a two-finger tap, for a touch screen driven
   from outside (see ios-touch.md). Prints what it gets, and exits once it
   has seen both gestures, or after two minutes. */
- (void)screenIn:(UIView *)root
{
	Recorder *recorder = [[Recorder alloc] init];
	Pad *pad = [[Pad alloc] initWithFrame:[root bounds]];
	[pad setMultipleTouchEnabled:YES];
	[root addSubview:pad];
	__block BOOL pinched = NO, tapped = NO;
	UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:recorder action:@selector(pinched:)];
	UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:recorder action:@selector(fired:)];
	[twoTap setNumberOfTouchesRequired:2];
	[pad addGestureRecognizer:pinch];
	[pad addGestureRecognizer:twoTap];
	printf("ready %s\n", [NSStringFromCGRect([pad convertRect:[pad bounds] toView:nil]) UTF8String]);
	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:120];
	NSUInteger seen = 0;
	while ((!pinched || !tapped) && [limit timeIntervalSinceNow] > 0) {
		spin(0.1);
		for (; seen < [[recorder events] count]; seen++) {
			NSString *line = [[recorder events] objectAtIndex:seen];
			printf("%s scale %.3f, %d began, %lu fingers at most\n", [line UTF8String], [recorder scale], [pad began], (unsigned long)[pad mostTouches]);
			if ([line isEqual:@"UIPinchGestureRecognizer:3"])
				pinched = YES;
			if ([line isEqual:@"UITapGestureRecognizer:3"])
				tapped = YES;
		}
	}
	expect(pinched && near([recorder scale], 2, 0.15), "a real two-finger pinch on the touch screen scales by about two",
	       [NSString stringWithFormat:@"%.3f", [recorder scale]]);
	expect(tapped, "a real two-finger tap on the touch screen", nil);
	expect([pad mostTouches] == 2, "the view saw both fingers at once", [NSString stringWithFormat:@"%lu", (unsigned long)[pad mostTouches]]);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	UIViewController *controller = [[UIViewController alloc] init];
	UIView *view = [controller view];
	[view setBackgroundColor:[UIColor whiteColor]];
	_window.rootViewController = controller;
	[_window makeKeyAndVisible];
	/* Let the window come up before fingers go down on it. */
	spin(1);
	if (getenv("DARLING_TOUCH_SCREEN"))
		[self screenIn:view];
	else
		[self checksIn:view];
	printf("%d failure(s)\n", failures);
	fflush(stdout);
	exit(failures != 0);
	return YES;
}

@end

int main(int argc, char *argv[])
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
