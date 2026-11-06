#import <UIKit/UIKit.h>
#import <AppKit/NSScreen.h>
#include <dlfcn.h>
#include <stdio.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

@interface UIScreen (ScreensTest)
- (NSScreen *)nativeScreen;
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        if (!dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL)) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class screenClass = NSClassFromString(@"UIScreen");
        CHECK(screenClass != Nil);
        CHECK([screenClass respondsToSelector:NSSelectorFromString(@"screens")]);

        // Documented: the main screen is the first element.
        NSArray *screens = [screenClass screens];
        CHECK(screens.count >= 1);
        CHECK(screens[0] == [screenClass mainScreen]);

        // Screens keep their identity across calls.
        NSArray *again = [screenClass screens];
        CHECK(again.count == screens.count);
        for (NSUInteger i = 0; i < screens.count; i++)
            CHECK(screens[i] == again[i]);

        // The main display is not listed twice, and no display ID repeats: Cocotron may hand
        // back new NSScreen objects for the same display, so identity is by display ID.
        NSMutableSet *ids = [NSMutableSet set];
        for (UIScreen *screen in screens) {
            NSNumber *displayID = @([[screen nativeScreen] cgDirectDisplayID]);
            CHECK(![ids containsObject:displayID]);
            [ids addObject:displayID];
        }

        // Every screen reports a positive size and scale.
        for (UIScreen *screen in screens) {
            CHECK(screen.bounds.size.width > 0 && screen.bounds.size.height > 0);
            CHECK(screen.scale > 0);
        }
        puts("PASS UIKit UIScreen screens");
    }
    return 0;
}
