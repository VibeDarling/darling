#import <AppKit/NSApplication.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSView.h>
#import <AppKit/NSGraphicsContext.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSTimer.h>
#include <stdio.h>
#include <stdlib.h>

static BOOL fixtureFailed;
static id expectedDelegate;

static void checkFixture(BOOL condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        fixtureFailed = YES;
    }
}

@interface LaunchProbe : NSObject <NSApplicationDelegate> {
    unsigned willLaunchCount;
    unsigned didLaunchCount;
    unsigned shouldTerminateCount;
    BOOL timerFired;
    unsigned draws;
    NSWindow *window;
}
- (void)finish:(NSTimer *)timer;
- (void)recordDraw;
@end

@interface LaunchPaintView : NSView
@end

@implementation LaunchPaintView
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty
{
    checkFixture([NSApp delegate] == expectedDelegate, "delegate identity during draw");
    checkFixture([NSThread isMainThread], "draw is not on main thread");
    NSGraphicsContext *previous = [NSGraphicsContext currentContext];
    CGContextRef port = [previous graphicsPort];
    checkFixture(previous != nil && port != NULL, "drawing context absent");
    if (fixtureFailed)
        return;
    CGContextSaveGState(port);
    NSRect bounds = [self bounds];
    CGContextSetRGBFillColor(port, 1, 1, 1, 1);
    CGContextFillRect(port, CGRectMake(0, 0, bounds.size.width, bounds.size.height));
    CGContextSetRGBFillColor(port, 0, 1, 1, 1);
    CGContextFillRect(port, CGRectMake(20, 20, 64, 64));
    CGContextRestoreGState(port);
    checkFixture([NSGraphicsContext currentContext] == previous &&
                 [[NSGraphicsContext currentContext] graphicsPort] == port,
                 "drawing context identity/port not preserved");
    [(LaunchProbe *)expectedDelegate recordDraw];
}
@end

@implementation LaunchProbe
- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    checkFixture([NSThread isMainThread], "will-launch callback is not on main thread");
    checkFixture([notification object] == NSApp, "will-launch notification object");
    checkFixture([[notification name] isEqual:NSApplicationWillFinishLaunchingNotification],
                 "will-launch notification name");
    checkFixture(willLaunchCount == 0 && didLaunchCount == 0, "will-launch order/count");
    checkFixture([NSApp delegate] == expectedDelegate, "delegate identity during will-launch");
    ++willLaunchCount;
    puts("OK: applicationWillFinishLaunching");
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    checkFixture([NSThread isMainThread], "did-launch callback is not on main thread");
    checkFixture([notification object] == NSApp, "did-launch notification object");
    checkFixture([[notification name] isEqual:NSApplicationDidFinishLaunchingNotification],
                 "did-launch notification name");
    checkFixture(willLaunchCount == 1 && didLaunchCount == 0, "did-launch order/count");
    ++didLaunchCount;
    checkFixture([NSApp delegate] == expectedDelegate, "delegate identity during launch");
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 240, 180)
                    styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    checkFixture(window != nil, "synthetic window creation");
    LaunchPaintView *view = [[LaunchPaintView alloc] initWithFrame:NSMakeRect(0, 0, 240, 180)];
    [window setContentView:view];
    [view release];
    [window setTitle:@"AppKit synthetic launch lifecycle"];
    [window setReleasedWhenClosed:NO];
    [window makeKeyAndOrderFront:nil];
    puts("OK: applicationDidFinishLaunching; synthetic window ordered");
}
- (void)recordDraw
{
    checkFixture(willLaunchCount == 1 && didLaunchCount == 1, "draw before launch callbacks");
    ++draws;
    printf("OK: synthetic draw %u; cyan64x64; context preserved\n", draws);
}
- (void)finish:(NSTimer *)timer
{
    checkFixture([NSThread isMainThread], "timer is not on main thread");
    checkFixture([NSApp isRunning], "application run loop is not running");
    checkFixture(willLaunchCount == 1 && didLaunchCount == 1, "launch callbacks missing/duplicated");
    checkFixture([window isVisible], "synthetic window is not visible to AppKit");
    checkFixture([NSApp delegate] == expectedDelegate, "delegate identity during timer");
    checkFixture(draws > 0, "synthetic view never drew");
    if (fixtureFailed)
        exit(1);
    timerFired = YES;
    puts("OK: bounded timer fired; requesting application termination");
    [NSApp terminate:self];
    checkFixture(NO, "application termination returned");
    exit(1);
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)application
{
    checkFixture(application == NSApp && timerFired, "unexpected termination request");
    checkFixture(shouldTerminateCount == 0, "duplicate termination request");
    if (fixtureFailed)
        exit(1);
    ++shouldTerminateCount;
    puts("OK: applicationShouldTerminate");
    return NSTerminateNow;
}
- (void)applicationWillTerminate:(NSNotification *)notification
{
    checkFixture([NSThread isMainThread], "termination callback is not on main thread");
    checkFixture([notification object] == NSApp, "termination notification object");
    checkFixture([[notification name] isEqual:NSApplicationWillTerminateNotification],
                 "termination notification name");
    checkFixture(timerFired && shouldTerminateCount == 1, "termination callback order");
    if (fixtureFailed)
        exit(1);
    puts("PASS: AppKit launch callbacks, window, run-loop timer and termination");
}
@end

int main(int argc, char **argv)
{
    setbuf(stdout, NULL);
    checkFixture(argc == 1, "unexpected document arguments");
    if (fixtureFailed)
        return 1;
    @autoreleasepool {
        puts("BEGIN: authored AppKit launch lifecycle probe");
        NSApplication *application = [NSApplication sharedApplication];
        checkFixture(application != nil && application == NSApp, "application singleton");
        LaunchProbe *delegate = [[LaunchProbe alloc] init];
        expectedDelegate = delegate;
        [application setDelegate:delegate];
        checkFixture([application delegate] == delegate, "delegate identity");
        if (fixtureFailed)
            return 1;
        [NSTimer scheduledTimerWithTimeInterval:30 target:delegate selector:@selector(finish:)
                                     userInfo:nil repeats:NO];
        [application run];
        checkFixture(NO, "application run returned before termination");
    }
    return 1;
}
