#import <Foundation/Foundation.h>
#include <darling-boundary-diagnostics.h>
#include <string.h>
static int checkpoint = 90;
void AuthoredPathStage(int stage) {
    static const char *const events[] = {
        "fixture.path.default.enter\n", "fixture.path.default.ready\n",
        "fixture.path.encoded.enter\n", "fixture.path.encoded.ready\n",
        "fixture.path.decoded.enter\n", "fixture.path.decoded.ready\n",
        "fixture.path.empty.enter\n", "fixture.path.empty.ready\n"
    };
    if ((unsigned)stage >= sizeof(events)/sizeof(events[0])) return;
    checkpoint = 100 + stage;
    darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), events[stage], strlen(events[stage]));
}
extern int authored_path_probe(void);
int main(void) {
    @autoreleasepool {
        @try { return authored_path_probe(); }
        @catch (id exception) { (void)exception; return checkpoint; }
    }
}
