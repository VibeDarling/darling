#import <Foundation/Foundation.h>
#include <string.h>
#include <darling-boundary-diagnostics.h>
static int checkpoint = 90;
void AuthoredDelegateStage(int stage) {
    static const char *const events[] = {
        "fixture.delegate.will.enter\n", "fixture.delegate.will.ready\n",
        "fixture.delegate.did.enter\n", "fixture.delegate.did.ready\n", "fixture.delegate.active\n",
        "fixture.cache.create.enter\n", "fixture.cache.create.ready\n", "fixture.cache.capacity.ready\n",
        "fixture.session.config.enter\n", "fixture.session.config.ready\n",
        "fixture.session.cache.ready\n", "fixture.session.isolation.ready\n"
    };
    if ((unsigned)stage >= sizeof(events)/sizeof(events[0])) return;
    checkpoint = 100 + stage;
    darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), events[stage], strlen(events[stage]));
}
extern void authored_delegate_main(void);
extern int authored_cache_probe(void);
int main(int argc, char **argv) {
    @autoreleasepool {
        @try {
            if (argc > 1 && strcmp(argv[1], "cache") == 0) return authored_cache_probe();
            authored_delegate_main();
            return 0;
        }
        @catch (id exception) { (void)exception; return checkpoint; }
    }
}
