#import <UIKit/UIGeometry.h>
#include <dlfcn.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: geometry <UIKit path>\n");
            return 2;
        }
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) {
            fprintf(stderr, "dlopen: %s\n", dlerror());
            return 2;
        }
        NSString *(*format)(CGSize) = dlsym(library, "NSStringFromCGSize");
        if (!format) {
            fprintf(stderr, "FAIL: NSStringFromCGSize absent\n");
            return 1;
        }
        if (![format(CGSizeMake(1.25, -2.5)) isEqualToString:@"{1.25, -2.5}"] ||
            ![format(CGSizeMake(0, 0)) isEqualToString:@"{0, 0}"] ||
            ![format(CGSizeMake(3, 20)) isEqualToString:@"{3, 20}"]) {
            fprintf(stderr, "FAIL: size formatting\n");
            return 1;
        }
        puts("PASS UIKit CGSize formatting: fractional, negative, zero and integer values");
    }
    return 0;
}
