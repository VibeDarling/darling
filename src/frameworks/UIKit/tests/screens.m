#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdio.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

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

        // Every screen reports a positive size and scale.
        for (UIScreen *screen in screens) {
            CHECK(screen.bounds.size.width > 0 && screen.bounds.size.height > 0);
            CHECK(screen.scale > 0);
        }
        puts("PASS UIKit UIScreen screens");
    }
    return 0;
}
