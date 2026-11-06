#import <UIKit/UIKeyboardNotifications.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#include <dlfcn.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

static NSString *Symbol(void *library, const char *name)
{
    void *address = dlsym(library, name);
    return address ? *(__unsafe_unretained NSString **)address : nil;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        const char *names[] = {
            "UIKeyboardWillShowNotification", "UIKeyboardDidShowNotification",
            "UIKeyboardWillHideNotification", "UIKeyboardDidHideNotification",
            "UIKeyboardWillChangeFrameNotification", "UIKeyboardDidChangeFrameNotification",
        };
        NSMutableSet *seen = [NSMutableSet set];
        for (int i = 0; i < 6; i++) {
            NSString *value = Symbol(library, names[i]);
            CHECK(value != nil && [value length] > 0);
            CHECK(![seen containsObject:value]);
            [seen addObject:value];
        }
        // Delivery through NSNotificationCenter keyed by the exported constant.
        __block int delivered = 0;
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        id token = [center addObserverForName:Symbol(library, "UIKeyboardDidShowNotification")
                                       object:nil queue:nil
                                   usingBlock:^(NSNotification *n) { delivered++; }];
        [center postNotificationName:Symbol(library, "UIKeyboardWillShowNotification") object:nil];
        CHECK(delivered == 0);
        [center postNotificationName:Symbol(library, "UIKeyboardDidShowNotification") object:nil];
        CHECK(delivered == 1);
        [center removeObserver:token];
        // Keyboard user-info keys and the private render notification are not exported.
        CHECK(dlsym(library, "UIKeyboardFrameEndUserInfoKey") == NULL);
        CHECK(dlsym(library, "UIKeyboardRenderDidFinishNotification") == NULL);
        puts("PASS UIKit keyboard notification names");
    }
    return 0;
}
