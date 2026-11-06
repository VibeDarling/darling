// Expected values come from the Apple documentation pages named in insets-offset.md,
// not from the implementation.
#import <UIKit/UIGeometry.h>
#include <dlfcn.h>
#include <stdio.h>

#define CHECK(cond, msg) do { if (!(cond)) { fprintf(stderr, "FAIL: %s\n", msg); return 1; } } while (0)

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: insets-offset <UIKit path>\n");
            return 2;
        }
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) {
            fprintf(stderr, "dlopen: %s\n", dlerror());
            return 2;
        }
        const UIEdgeInsets *zeroInsets = dlsym(library, "UIEdgeInsetsZero");
        const UIOffset *zeroOffset = dlsym(library, "UIOffsetZero");
        CHECK(zeroInsets && zeroOffset, "UIEdgeInsetsZero / UIOffsetZero not exported");
        CHECK(zeroInsets->top == 0 && zeroInsets->left == 0 && zeroInsets->bottom == 0 &&
              zeroInsets->right == 0, "UIEdgeInsetsZero fields are not all zero");
        CHECK(zeroOffset->horizontal == 0 && zeroOffset->vertical == 0, "UIOffsetZero not zero");

        UIEdgeInsets a = UIEdgeInsetsMake(1, 2, 3, 4);
        CHECK(a.top == 1 && a.left == 2 && a.bottom == 3 && a.right == 4, "UIEdgeInsetsMake field order");
        CHECK(UIEdgeInsetsEqualToEdgeInsets(a, UIEdgeInsetsMake(1, 2, 3, 4)), "equal insets");
        CHECK(!UIEdgeInsetsEqualToEdgeInsets(a, UIEdgeInsetsMake(1, 2, 3, 5)), "unequal right");
        CHECK(!UIEdgeInsetsEqualToEdgeInsets(a, UIEdgeInsetsMake(0, 2, 3, 4)), "unequal top");
        CHECK(!UIEdgeInsetsEqualToEdgeInsets(a, UIEdgeInsetsMake(1, 0, 3, 4)), "unequal left");
        CHECK(!UIEdgeInsetsEqualToEdgeInsets(a, UIEdgeInsetsMake(1, 2, 0, 4)), "unequal bottom");
        CHECK(UIEdgeInsetsEqualToEdgeInsets(*zeroInsets, UIEdgeInsetsMake(0, 0, 0, 0)), "zero equals make(0,0,0,0)");

        UIOffset o = UIOffsetMake(5, 6);
        CHECK(o.horizontal == 5 && o.vertical == 6, "UIOffsetMake field order");
        CHECK(UIOffsetEqualToOffset(o, UIOffsetMake(5, 6)), "equal offsets");
        CHECK(!UIOffsetEqualToOffset(o, UIOffsetMake(6, 5)), "swapped offsets differ");
        CHECK(!UIOffsetEqualToOffset(o, UIOffsetMake(5, 7)), "unequal vertical");

        // Documented: origin incremented, size decremented by the corresponding members.
        CGRect r = UIEdgeInsetsInsetRect(CGRectMake(10, 20, 100, 200), a);
        CHECK(r.origin.x == 12 && r.origin.y == 21, "InsetRect origin: x += left, y += top");
        CHECK(r.size.width == 94 && r.size.height == 196, "InsetRect size: w -= left+right, h -= top+bottom");
        r = UIEdgeInsetsInsetRect(CGRectMake(1, 2, 3, 4), *zeroInsets);
        CHECK(CGRectEqualToRect(r, CGRectMake(1, 2, 3, 4)), "zero insets leave rect unchanged");

        // Negative insets outset the rect (documented).
        r = UIEdgeInsetsInsetRect(CGRectMake(10, 20, 100, 200), UIEdgeInsetsMake(-1, -2, -3, -4));
        CHECK(CGRectEqualToRect(r, CGRectMake(8, 19, 106, 204)), "negative insets outset the rect");
        // Rung 6 (not documented Apple behaviour): no clamping of an over-inset rect.
        r = UIEdgeInsetsInsetRect(CGRectMake(0, 0, 4, 4), UIEdgeInsetsMake(3, 3, 3, 3));
        CHECK(r.origin.x == 3 && r.origin.y == 3 && r.size.width == -2 && r.size.height == -2,
              "over-inset rect keeps a negative size");
        puts("PASS UIEdgeInsets/UIOffset: zero constants, make, equality, inset rect");
    }
    return 0;
}
