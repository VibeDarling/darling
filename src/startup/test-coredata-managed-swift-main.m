#import <Foundation/Foundation.h>
extern int authored_swift_managed_probe(void);
extern int authored_swift_managed_stage(void);
int main(void) {
    @autoreleasepool {
        @try { return authored_swift_managed_probe(); }
        @catch (id exception) {
            int stage = authored_swift_managed_stage();
            return stage >= 50 && stage <= 64 ? stage : 44;
        }
    }
}
