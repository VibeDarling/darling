#import <Foundation/Foundation.h>
#include <darling-boundary-diagnostics.h>
#include <string.h>
static int checkpoint = 90;
void AuthoredTemporaryStage(int stage) {
    static const char *const events[] = {
        "fixture.temporary.standard.enter\n", "fixture.temporary.standard.ready\n",
        "fixture.temporary.getter.enter\n", "fixture.temporary.getter.ready\n"
    };
    if ((unsigned)stage >= sizeof(events)/sizeof(events[0])) return;
    checkpoint = 100 + stage;
    darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), events[stage], strlen(events[stage]));
}
extern int authored_temporary_probe(void);
int main(void) {
    @autoreleasepool {
        @try { return authored_temporary_probe(); }
        @catch (id exception) { (void)exception; return checkpoint; }
    }
}
