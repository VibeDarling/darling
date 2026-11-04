#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <math.h>
#include <stdio.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)
#define CLOSE(a, b) (fabs((a) - (b)) < 0.00001)

static int deallocCount;
static void countingDealloc(__unsafe_unretained id self, SEL _cmd)
{
    deallocCount++;
    struct objc_super super = {self, class_getSuperclass(objc_getClass("CountingColor"))};
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&super, _cmd);
}

/* Pass the guest path of the built UIKit dylib as the only argument. */
int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        if (!dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL)) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class colorClass = NSClassFromString(@"UIColor");
        CHECK(colorClass != Nil);
        CGFloat r, g, b, a, white;

        UIColor *rgb = [colorClass colorWithRed:0.25 green:0.5 blue:0.75 alpha:0.4];
        CHECK([rgb getRed:&r green:&g blue:&b alpha:&a]);
        CHECK(CLOSE(r, 0.25) && CLOSE(g, 0.5) && CLOSE(b, 0.75) && CLOSE(a, 0.4));
        CHECK([rgb getRed:NULL green:NULL blue:NULL alpha:NULL]);
        CHECK(![rgb getWhite:&white alpha:&a]);
        CHECK(CGColorSpaceGetModel(CGColorGetColorSpace(rgb.CGColor)) == kCGColorSpaceModelRGB);
        CHECK(CGColorGetNumberOfComponents(rgb.CGColor) == 4);
        CHECK(rgb.CGColor == rgb.CGColor);

        UIColor *gray = [colorClass colorWithWhite:0.35 alpha:0.7];
        CHECK([gray getWhite:&white alpha:&a] && CLOSE(white, 0.35) && CLOSE(a, 0.7));
        CHECK(CGColorSpaceGetModel(CGColorGetColorSpace(gray.CGColor)) == kCGColorSpaceModelMonochrome);
        CHECK([[colorClass whiteColor] getWhite:&white alpha:&a] && white == 1 && a == 1);
        CHECK([[colorClass redColor] getWhite:&white alpha:&a] == NO);

        UIColor *faded = [gray colorWithAlphaComponent:0.2];
        CHECK([faded getWhite:&white alpha:&a] && CLOSE(white, 0.35) && CLOSE(a, 0.2));

        UIColor *inited = [[colorClass alloc] initWithRed:0.1 green:0.2 blue:0.3 alpha:0.6];
        CHECK([inited getRed:&r green:&g blue:&b alpha:&a]);
        CHECK(CLOSE(r, 0.1) && CLOSE(g, 0.2) && CLOSE(b, 0.3) && CLOSE(a, 0.6));
        UIColor *initedGray = [[colorClass alloc] initWithWhite:0.5 alpha:0.9];
        CHECK([initedGray getWhite:&white alpha:&a] && CLOSE(white, 0.5) && CLOSE(a, 0.9));

        CGColorRef rawRGB = CGColorCreateGenericRGB(0.1, 0.2, 0.3, 0.6);
        UIColor *fromRGB = [colorClass colorWithCGColor:rawRGB];
        CGColorRelease(rawRGB);
        CHECK([fromRGB getRed:&r green:&g blue:&b alpha:&a]);
        CHECK(CLOSE(r, 0.1) && CLOSE(g, 0.2) && CLOSE(b, 0.3) && CLOSE(a, 0.6));
        CGColorRef rawGray = CGColorCreateGenericGray(0.35, 0.7);
        UIColor *fromGray = [colorClass colorWithCGColor:rawGray];
        CGColorRelease(rawGray);
        CHECK([fromGray getWhite:&white alpha:&a] && CLOSE(white, 0.35) && CLOSE(a, 0.7));

        UIColor *copy = [rgb copy];
        CHECK([copy getRed:&r green:&g blue:&b alpha:&a] && CLOSE(a, 0.4));

        BOOL raised = NO;
        @try { (void)[colorClass colorWithCGColor:NULL]; }
        @catch (NSException *e) { raised = [e.name isEqual:NSInvalidArgumentException]; }
        CHECK(raised);
        CGColorRef rawCMYK = CGColorCreateGenericCMYK(0.1, 0.2, 0.3, 0.4, 0.5);
        raised = NO;
        @try { (void)[colorClass colorWithCGColor:rawCMYK]; }
        @catch (NSException *e) { raised = [e.name isEqual:NSInvalidArgumentException]; }
        CGColorRelease(rawCMYK);
        CHECK(raised);

        CGColorRef rawCMYK2 = CGColorCreateGenericCMYK(0.1, 0.2, 0.3, 0.4, 0.5);
        /* NaN and infinity raise from every constructor; finite out-of-range values are stored unclamped. */
        CGFloat bad[] = {NAN, INFINITY, -INFINITY};
        for (unsigned i = 0; i < 3; i++) {
            raised = NO;
            @try { (void)[colorClass colorWithRed:bad[i] green:0 blue:0 alpha:1]; }
            @catch (NSException *e) { raised = [e.name isEqual:NSInvalidArgumentException]; }
            CHECK(raised);
            raised = NO;
            @try { (void)[colorClass colorWithWhite:0 alpha:bad[i]]; }
            @catch (NSException *e) { raised = [e.name isEqual:NSInvalidArgumentException]; }
            CHECK(raised);
            raised = NO;
            @try { (void)[[colorClass alloc] initWithRed:0 green:bad[i] blue:0 alpha:1]; }
            @catch (NSException *e) { raised = [e.name isEqual:NSInvalidArgumentException]; }
            CHECK(raised);
            raised = NO;
            @try { (void)[[colorClass alloc] initWithWhite:bad[i] alpha:1]; }
            @catch (NSException *e) { raised = [e.name isEqual:NSInvalidArgumentException]; }
            CHECK(raised);
        }
        UIColor *wide = [colorClass colorWithRed:1.5 green:-0.25 blue:0 alpha:2];
        CHECK([wide getRed:&r green:&g blue:&b alpha:&a] && r == 1.5 && g == -0.25 && a == 2);

        /* Raising initializers release self: a counting subclass sees exactly one dealloc each. */
        Class counting = objc_allocateClassPair(colorClass, "CountingColor", 0);
        CHECK(counting != Nil);
        class_addMethod(counting, sel_registerName("dealloc"), (IMP)countingDealloc, "v@:");
        objc_registerClassPair(counting);
        int before = deallocCount;
        @autoreleasepool {
            @try { (void)[[counting alloc] initWithCGColor:NULL]; } @catch (NSException *e) {}
            @try { (void)[[counting alloc] initWithRed:NAN green:0 blue:0 alpha:1]; } @catch (NSException *e) {}
            @try { (void)[[counting alloc] initWithWhite:0 alpha:INFINITY]; } @catch (NSException *e) {}
            raised = NO;
            @try { (void)[[counting alloc] initWithCGColor:rawCMYK2]; } @catch (NSException *e) { raised = YES; }
            CHECK(raised);
        }
        CGColorRelease(rawCMYK2);
        CHECK(deallocCount == before + 4);

        /* -CGColor is created once and stable across threads. */
        static CGColorRef seen[8];
        UIColor *shared = [colorClass colorWithRed:0.2 green:0.4 blue:0.6 alpha:1];
        dispatch_apply(8, dispatch_get_global_queue(0, 0), ^(size_t i) { seen[i] = shared.CGColor; });
        for (unsigned i = 1; i < 8; i++) CHECK(seen[i] == seen[0]);
        CHECK(seen[0] == shared.CGColor);

        /* Upstream's alloc/init construction still yields a usable color. */
        UIColor *plain = [[colorClass alloc] init];
        CHECK([plain getRed:&r green:&g blue:&b alpha:&a] && r == 0 && a == 0);
        puts("PASS UIKit UIColor CGColor bridge, getters, gray tracking, copies, non-finite raises, unclamped range, released self on raise and a stable CGColor across threads");
    }
    return 0;
}
