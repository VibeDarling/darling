#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)
#define NEAR(a, b) (fabs((double)(a) - (double)(b)) < 1e-9)

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        if (!dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL)) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class viewClass = NSClassFromString(@"UIView");
        CHECK(viewClass != Nil);

        UIView *view = [[viewClass alloc] initWithFrame:CGRectMake(10, 20, 100, 50)];
        CHECK(NEAR(view.center.x, 60) && NEAR(view.center.y, 45));
        CHECK(CGAffineTransformIsIdentity(view.transform));
        CHECK(view.alpha == 1.0);
        CHECK(view.tag == 0);
        CHECK(!view.clipsToBounds);

        // center is the frame centre; setting it moves the origin and keeps the size.
        view.center = CGPointMake(0, 0);
        CHECK(CGRectEqualToRect(view.frame, CGRectMake(-50, -25, 100, 50)));
        view.frame = CGRectMake(5, 6, 20, 30);
        CHECK(NEAR(view.center.x, 15) && NEAR(view.center.y, 21));

        // alpha is NSView's alphaValue.
        view.alpha = 0.25;
        CHECK(view.alpha == 0.25 && view.alphaValue == 0.25);
        view.alphaValue = 0.5;
        CHECK(view.alpha == 0.5);

        // transform is stored and leaves the frame alone.
        CGAffineTransform scale = CGAffineTransformMakeScale(2, 0.5);
        view.transform = scale;
        CHECK(CGAffineTransformEqualToTransform(view.transform, scale));
        CHECK(CGRectEqualToRect(view.frame, CGRectMake(5, 6, 20, 30)));

        view.clipsToBounds = YES;
        CHECK(view.clipsToBounds);

        // A settable tag feeds NSView's viewWithTag:.
        UIView *child = [[viewClass alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
        child.tag = 42;
        CHECK(child.tag == 42);
        [view addSubview:child];
        CHECK([view viewWithTag:42] == child);

        CHECK([[[viewClass alloc] init] tag] == 0);
        // NSView's default tag is -1; a UIView must not match it.
        CHECK([view viewWithTag:-1] == nil);
        CHECK(CGAffineTransformIsIdentity([[[viewClass alloc] init] transform]));
        puts("PASS UIKit UIView additive members");
    }
    return 0;
}
