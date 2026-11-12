#import <Foundation/Foundation.h>
#include <stdlib.h>
extern int authored_environment_probe(int);
int main(int argc, char **argv) {
    int mode = argc > 1 ? atoi(argv[1]) : 0;
    if (mode < 0 || mode > 2) return 91;
    @autoreleasepool {
        @try { return authored_environment_probe(mode); }
        @catch (id exception) { (void)exception; return 40; }
    }
}
