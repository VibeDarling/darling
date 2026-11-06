#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class buttonClass = NSClassFromString(@"UIButton");
        Class colorClass = NSClassFromString(@"UIColor");
        CHECK(buttonClass != Nil && colorClass != Nil);
        CHECK([buttonClass isSubclassOfClass:NSClassFromString(@"UIControl")]);

        // Selector spellings from the Apple Objective-C declarations.
        CHECK([buttonClass respondsToSelector:NSSelectorFromString(@"buttonWithType:")]);
        const char *selectors[] = { "setTitle:forState:", "titleForState:", "setTitleColor:forState:",
                                    "titleColorForState:", "buttonType" };
        for (unsigned i = 0; i < sizeof selectors / sizeof *selectors; i++)
            CHECK([buttonClass instancesRespondToSelector:NSSelectorFromString([NSString stringWithUTF8String:selectors[i]])]);

        // A custom button starts with frame (0, 0, 0, 0) (documented) and reports its type.
        UIButton *custom = [buttonClass buttonWithType:UIButtonTypeCustom];
        CHECK([custom isKindOfClass:buttonClass]);
        CHECK(custom.buttonType == UIButtonTypeCustom);
        CHECK(CGRectEqualToRect(custom.frame, CGRectZero));
        CHECK(custom.enabled && custom.state == UIControlStateNormal);   // inherits UIControl defaults
        UIButton *contactAdd = [buttonClass buttonWithType:UIButtonTypeContactAdd];
        CHECK(contactAdd.buttonType == UIButtonTypeContactAdd);
        UIButton *system = [buttonClass buttonWithType:UIButtonTypeSystem];
        CHECK(system.buttonType == UIButtonTypeSystem && UIButtonTypeRoundedRect == UIButtonTypeSystem);

        // Nothing set: no title (rung 6: the "system value" is not modelled).
        CHECK([custom titleForState:UIControlStateNormal] == nil);

        // A state without its own title uses the Normal title (documented).
        [custom setTitle:@"Send" forState:UIControlStateNormal];
        CHECK([[custom titleForState:UIControlStateNormal] isEqualToString:@"Send"]);
        CHECK([[custom titleForState:UIControlStateHighlighted] isEqualToString:@"Send"]);
        CHECK([[custom titleForState:UIControlStateDisabled] isEqualToString:@"Send"]);
        CHECK([[custom titleForState:UIControlStateHighlighted | UIControlStateSelected] isEqualToString:@"Send"]);

        // A per-state title overrides only that state.
        [custom setTitle:@"Sending" forState:UIControlStateHighlighted];
        CHECK([[custom titleForState:UIControlStateHighlighted] isEqualToString:@"Sending"]);
        CHECK([[custom titleForState:UIControlStateNormal] isEqualToString:@"Send"]);
        CHECK([[custom titleForState:UIControlStateSelected] isEqualToString:@"Send"]);

        // The stored title is a copy (rung 6).
        NSMutableString *mutableTitle = [NSMutableString stringWithString:@"Done"];
        [custom setTitle:mutableTitle forState:UIControlStateSelected];
        [mutableTitle appendString:@"!"];
        CHECK([[custom titleForState:UIControlStateSelected] isEqualToString:@"Done"]);

        // nil clears a state's own title (rung 6), falling back to Normal again.
        [custom setTitle:nil forState:UIControlStateHighlighted];
        CHECK([[custom titleForState:UIControlStateHighlighted] isEqualToString:@"Send"]);

        // Title colors follow the same per-state rule.
        UIColor *red = [colorClass colorWithRed:1 green:0 blue:0 alpha:1];
        UIColor *blue = [colorClass colorWithRed:0 green:0 blue:1 alpha:1];
        CHECK([custom titleColorForState:UIControlStateNormal] == nil);
        [custom setTitleColor:red forState:UIControlStateNormal];
        CHECK([custom titleColorForState:UIControlStateDisabled] == red);
        [custom setTitleColor:blue forState:UIControlStateDisabled];
        CHECK([custom titleColorForState:UIControlStateDisabled] == blue);
        CHECK([custom titleColorForState:UIControlStateNormal] == red);

        // Buttons are independent.
        UIButton *other = [buttonClass buttonWithType:UIButtonTypeCustom];
        CHECK([other titleForState:UIControlStateNormal] == nil);
        printf("PASS button\n");
    }
    return 0;
}
