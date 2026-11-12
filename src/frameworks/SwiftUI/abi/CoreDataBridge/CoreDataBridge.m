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
        "swiftui.observer.enter\n", "swiftui.observer.ready\n",
        "swiftui.windowgroup.init.enter\n", "swiftui.windowgroup.init.ready\n",
        "swiftui.windowgroup.make.enter\n", "swiftui.windowgroup.content.ready\n",
        "swiftui.fetch.init.enter\n", "swiftui.fetch.init.ready\n",
        "swiftui.fetch.environment.context-missing\n", "swiftui.fetch.refresh.context-missing\n",
        "swiftui.fetch.refresh.failed\n", "swiftui.fetch.value.uninstalled\n",
        "swiftui.dynamic-property.unsupported\n",
        "swiftui.fetch.environment.setter.enter\n", "swiftui.environment.write.enter\n",
        "swiftui.environment.write.ready\n",
        "swiftui.uikit.runner.enter\n",
        "swiftui.uikit.main.enter\n",
        "swiftui.delegate.will.enter\n",
        "swiftui.delegate.will.forward.enter\n",
        "swiftui.delegate.will.forward.ready\n",
        "swiftui.delegate.did.enter\n",
        "swiftui.delegate.did.forward.enter\n",
        "swiftui.delegate.did.forward.ready\n",
        "swiftui.delegate.legacy.forward.enter\n",
        "swiftui.delegate.legacy.forward.ready\n",
        "swiftui.window.create.enter\n",
        "swiftui.window.create.ready\n",
        "swiftui.window.root.enter\n",
        "swiftui.window.root.ready\n",
        "swiftui.delegate.evaluate.enter\n"
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
