#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdio.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

/* Needs a display: UIWindow hosts an NSWindow. */
int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        if (!dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL)) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class sceneClass = NSClassFromString(@"UIWindowScene");
        CHECK(sceneClass != Nil);
        CHECK(![sceneClass instancesRespondToSelector:@selector(screen)]);

        UIWindowScene *scene = [[sceneClass alloc] init];
        UIWindowScene *other = [[sceneClass alloc] init];
        CHECK(scene.windows.count == 0 && scene.keyWindow == nil);

        UIWindow *first = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        UIWindow *second = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        CHECK(first.windowScene == nil);
        first.windowScene = scene;
        second.windowScene = scene;
        NSArray *both = @[first, second];
        CHECK([scene.windows isEqualToArray:both]);
        CHECK(first.windowScene == scene);

        // Setting the same scene again does not duplicate; moving a window leaves the old scene.
        first.windowScene = scene;
        CHECK(scene.windows.count == 2);
        second.windowScene = other;
        NSArray *inScene = @[first], *inOther = @[second];
        CHECK([scene.windows isEqualToArray:inScene] && [other.windows isEqualToArray:inOther]);
        first.windowScene = nil;
        CHECK(scene.windows.count == 0 && first.windowScene == nil);

        // A window that is not key is not the scene's keyWindow.
        CHECK(!first.keyWindow);
        CHECK(scene.keyWindow == nil);
        puts("PASS UIKit UIWindowScene");
    }
    return 0;
}
