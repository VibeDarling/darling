#import <Foundation/Foundation.h>
extern int authored_swift_managed_probe(void);
int main(void) {
    @autoreleasepool {
        @try { return authored_swift_managed_probe(); }
        @catch (id exception) { return 44; }
    }
}
