#import <Foundation/Foundation.h>
#include <darling-boundary-diagnostics.h>
static int checkpoint = 90;
void AuthoredDirectoryStage(int stage) {
    static const char *const events[] = {
        "fixture.directory.locator.enter\n", "fixture.directory.locator.ready\n",
        "fixture.directory.getter.enter\n", "fixture.directory.getter.ready\n"
    };
    if ((unsigned)stage >= sizeof(events)/sizeof(events[0])) return;
    checkpoint = 100 + stage;
    darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), events[stage], strlen(events[stage]));
}
extern int authored_directory_probe(void);
int main(void) {
    @autoreleasepool {
        @try { return authored_directory_probe(); }
        @catch (id exception) { (void)exception; return checkpoint; }
    }
}
