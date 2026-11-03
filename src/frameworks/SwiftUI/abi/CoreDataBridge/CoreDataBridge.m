#import "CoreDataBridge.h"
#include <darling-boundary-diagnostics.h>

void DarlingSwiftUIEntry(void) {
    static const char event[] = "swiftui.app.main.enter\n";
    darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), event, sizeof(event)-1);
}

@implementation DarlingContextObservation {
    id _token;
}
- (instancetype)initWithContext:(NSManagedObjectContext *)context change:(void (^)(void))change {
    self = [super init];
    if (self) {
        _token = [[[NSNotificationCenter defaultCenter]
            addObserverForName:NSManagedObjectContextObjectsDidChangeNotification object:context queue:nil
            usingBlock:^(NSNotification *note) { (void)note; change(); }] retain];
    }
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
    return [values autorelease];
}
