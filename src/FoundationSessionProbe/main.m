#import <Foundation/Foundation.h>
#include <string.h>
#include <darling-boundary-diagnostics.h>
static int checkpoint = 90;
void AuthoredSessionStage(int stage) {
    static const char *const events[] = {
        "fixture.session.setup.enter\n", "fixture.session.setup.ready\n",
        "fixture.session.queue.enter\n", "fixture.session.queue.ready\n",
        "fixture.session.create.enter\n", "fixture.session.create.ready\n",
        "fixture.session.properties.enter\n", "fixture.session.properties.ready\n",
        "fixture.session.description.enter\n", "fixture.session.description.ready\n",
        "fixture.session.invalidate.enter\n", "fixture.session.invalidate.ready\n"
    };
    if ((unsigned)stage >= sizeof(events)/sizeof(events[0])) return;
    checkpoint = 100 + stage;
    darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), events[stage], strlen(events[stage]));
}
extern int authored_session_probe(int);
int main(int argc, char **argv) {
    int nilCache = argc > 1 && strcmp(argv[1], "nil") == 0;
    @autoreleasepool {
        @try { return authored_session_probe(nilCache); }
        @catch (id exception) { (void)exception; return checkpoint; }
    }
}
