#import <Foundation/Foundation.h>
extern int authored_sort_probe(int);
int main(int argc, char **argv) {
    (void)argv;
    @autoreleasepool {
        @try { return authored_sort_probe(argc > 1); }
        @catch (id exception) { (void)exception; return 40; }
    }
}
