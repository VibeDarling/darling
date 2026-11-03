#import "FixtureBridge.h"
#include <darling-boundary-diagnostics.h>

@implementation AuthoredFetchRow
@dynamic label, moment;
@end

static int checkpoint;
static NSArray *fetch(NSManagedObjectContext *context);
#define MARKER(literal) darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), literal, sizeof(literal)-1)
NSManagedObjectContext *AuthoredContext(void) {
    checkpoint = 101;
    NSEntityDescription *entity = [[[NSEntityDescription alloc] init] autorelease];
    entity.name = @"AuthoredRow";
    entity.managedObjectClassName = NSStringFromClass(AuthoredFetchRow.class);
    NSAttributeDescription *label = [[[NSAttributeDescription alloc] init] autorelease];
    label.name = @"label"; label.attributeType = NSStringAttributeType; label.optional = NO; label.defaultValue = @"new";
    NSAttributeDescription *moment = [[[NSAttributeDescription alloc] init] autorelease];
    moment.name = @"moment"; moment.attributeType = NSDateAttributeType; moment.optional = NO;
    moment.defaultValue = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    entity.properties = @[label, moment];
    NSManagedObjectModel *model = [[[NSManagedObjectModel alloc] init] autorelease];
    model.entities = @[entity];
    checkpoint = 102;
    NSPersistentStoreCoordinator *coordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model] autorelease];
    NSError *error = nil;
    if (![coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil
            URL:[NSURL fileURLWithPath:@"/authored-fetch-memory"] options:nil error:&error] || error)
        [NSException raise:NSInternalInconsistencyException format:@"Authored Memory store failed"];
    checkpoint = 103;
    NSManagedObjectContext *context = [[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease];
    context.persistentStoreCoordinator = coordinator;
    if (fetch(context).count != 0)
        [NSException raise:NSInternalInconsistencyException format:@"Authored initial fetch failed"];
    MARKER("fixture.fetch.context.ok\n");
    return context;
}
NSEntityDescription *AuthoredEntity(NSManagedObjectContext *context) {
    return context.persistentStoreCoordinator.managedObjectModel.entitiesByName[@"AuthoredRow"];
}
static NSArray *fetch(NSManagedObjectContext *context) {
    NSFetchRequest *request = [[[NSFetchRequest alloc] initWithEntityName:@"AuthoredRow"] autorelease];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"moment" ascending:NO]];
    NSError *error = nil;
    NSArray *rows = [context executeFetchRequest:request error:&error];
    if (!rows || error)
        [NSException raise:NSInternalInconsistencyException format:@"Authored direct fetch failed"];
    return rows;
}
void AuthoredAdd(NSManagedObjectContext *context) {
    checkpoint = 111;
    AuthoredFetchRow *alpha = [[[AuthoredFetchRow alloc] initWithContext:context] autorelease];
    alpha.label = @"Alpha"; alpha.moment = [NSDate dateWithTimeIntervalSinceReferenceDate:10];
    AuthoredFetchRow *beta = [[[AuthoredFetchRow alloc] initWithContext:context] autorelease];
    beta.label = @"Beta"; beta.moment = [NSDate dateWithTimeIntervalSinceReferenceDate:20];
    [context processPendingChanges];
    NSArray *rows = fetch(context);
    if (rows.count != 2 || ![[rows[0] label] isEqual:@"Beta"] || ![[rows[1] label] isEqual:@"Alpha"])
        [NSException raise:NSInternalInconsistencyException format:@"Authored insert assertion failed"];
    MARKER("fixture.fetch.add.ok\n");
}
void AuthoredEdit(NSManagedObjectContext *context) {
    checkpoint = 112;
    NSArray *rows = fetch(context);
    if (rows.count != 2)
        [NSException raise:NSInternalInconsistencyException format:@"Authored edit precondition failed"];
    AuthoredFetchRow *alpha = rows[1]; alpha.label = @"Alpha edited";
    alpha.moment = [NSDate dateWithTimeIntervalSinceReferenceDate:30];
    NSError *error = nil;
    if (![context save:&error] || error || ![[fetch(context)[0] label] isEqual:@"Alpha edited"])
        [NSException raise:NSInternalInconsistencyException format:@"Authored edit assertion failed"];
    MARKER("fixture.fetch.edit.ok\n");
}
void AuthoredDelete(NSManagedObjectContext *context) {
    checkpoint = 113;
    NSArray *rows = fetch(context);
    if (rows.count != 2)
        [NSException raise:NSInternalInconsistencyException format:@"Authored delete precondition failed"];
    [context deleteObject:rows[0]]; [context processPendingChanges];
    if (fetch(context).count != 1 || ![[fetch(context)[0] label] isEqual:@"Beta"])
        [NSException raise:NSInternalInconsistencyException format:@"Authored delete assertion failed"];
    MARKER("fixture.fetch.delete.ok\n");
}
void AuthoredOther(NSManagedObjectContext *context) {
    checkpoint = 114;
    if (fetch(context).count != 0)
        [NSException raise:NSInternalInconsistencyException format:@"Authored second context assertion failed"];
    MARKER("fixture.fetch.other.ok\n");
}
void AuthoredReturn(NSManagedObjectContext *context) {
    checkpoint = 115;
    if (fetch(context).count != 1 || ![[fetch(context)[0] label] isEqual:@"Beta"])
        [NSException raise:NSInternalInconsistencyException format:@"Authored context return assertion failed"];
    MARKER("fixture.fetch.return.ok\n");
}
extern void authored_fetch_app_main(void);
int main(void) {
    @autoreleasepool {
        @try { authored_fetch_app_main(); return 0; }
        @catch (NSException *exception) { (void)exception; return checkpoint; }
    }
}
