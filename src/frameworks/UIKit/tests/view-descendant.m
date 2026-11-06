#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdio.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        if (!dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL)) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class viewClass = NSClassFromString(@"UIView");
        CHECK(viewClass != Nil);
        UIView *root = [[viewClass alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        UIView *child = [[viewClass alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
        UIView *grandchild = [[viewClass alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
        UIView *other = [[viewClass alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
        [root addSubview:child];
        [child addSubview:grandchild];

        CHECK([root isDescendantOfView:root]);
        CHECK([child isDescendantOfView:root]);
        CHECK([grandchild isDescendantOfView:root]);
        CHECK(![root isDescendantOfView:child]);
        CHECK(![other isDescendantOfView:root]);
        [child removeFromSuperview];
        CHECK(![grandchild isDescendantOfView:root]);
        CHECK([grandchild isDescendantOfView:child]);
        puts("PASS UIKit UIView isDescendantOfView");
    }
    return 0;
}
