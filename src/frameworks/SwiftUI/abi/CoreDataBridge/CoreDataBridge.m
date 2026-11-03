#import "CoreDataBridge.h"
#include <darling-boundary-diagnostics.h>

void DarlingSwiftUIEntry(void) {
    static const char event[] = "swiftui.app.main.enter\n";
    darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), event, sizeof(event)-1);
}

void DarlingSwiftUIPhase(int phase) {
    static const char *const events[] = {
        "swiftui.app.self.ready\n", "swiftui.app.graph.ready\n", "swiftui.app.uikit.enter\n",
        "swiftui.app.launch.enter\n", "swiftui.app.render.enter\n", "swiftui.app.body.enter\n",
        "swiftui.fetch.enter\n", "swiftui.fetch.success\n", "swiftui.fetch.error\n",
        "swiftui.observer.enter\n", "swiftui.observer.ready\n"
    };
    if ((unsigned)phase < sizeof(events)/sizeof(events[0]))
        darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), events[phase], strlen(events[phase]));
}

@implementation DarlingContextObservation {
    id _token;
}
- (instancetype)initWithContext:(NSManagedObjectContext *)context change:(void (^)(void))change {
    DarlingSwiftUIPhase(9);
    self = [super init];
    if (self) {
        _token = [[[NSNotificationCenter defaultCenter]
            addObserverForName:NSManagedObjectContextObjectsDidChangeNotification object:context queue:nil
            usingBlock:^(NSNotification *note) { (void)note; change(); }] retain];
    }
    DarlingSwiftUIPhase(10);
    return self;
}
- (void)cancel {
    if (_token) {
        [[NSNotificationCenter defaultCenter] removeObserver:_token];
        [_token release];
        _token = nil;
    }
}
- (void)dealloc { [self cancel]; [super dealloc]; }
@end

NSArray *DarlingContextFetch(NSManagedObjectContext *context, NSEntityDescription *entity,
        NSArray<NSSortDescriptor *> *sortDescriptors, NSPredicate *predicate) {
    DarlingSwiftUIPhase(6);
    __block NSArray *values = nil;
    [context performBlockAndWait:^{
        NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
        request.entity = entity;
        request.sortDescriptors = sortDescriptors;
        request.predicate = predicate;
        NSError *error = nil;
        NSArray *result = [context executeFetchRequest:request error:&error];
        if (result && !error)
            values = [result copy];
    }];
    DarlingSwiftUIPhase(values ? 7 : 8);
    return [values autorelease];
}
