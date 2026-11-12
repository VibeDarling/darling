#define main authoredDurabilityMain
#include "test-coredata-durability.m"
#undef main

static int writers(NSString *path, BOOL staleDelete) {
    NSManagedObjectModel *model=schema();
    NSPersistentStoreCoordinator *coordinator=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model] autorelease];
    NSError *error=nil;
    if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:path] options:nil error:&error] || error) return 10;
    NSManagedObjectContext *first=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease], *second=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease];
    first.persistentStoreCoordinator=coordinator; second.persistentStoreCoordinator=coordinator;
    AuthoredLedger *a=row(first,INT64_MIN+7), *b=row(second,INT64_MIN+7);
    if (!a || !b || a==b || a.objectID!=b.objectID) return 11;
    SaveCounter *counter=[[[SaveCounter alloc] init] autorelease];
    [NSNotificationCenter.defaultCenter addObserver:counter selector:@selector(saved:) name:NSManagedObjectContextDidSaveNotification object:second];
    a.label=@"first writer"; if (![first save:&error] || error) return 12;
    if (staleDelete) {
        [second deleteObject:b]; error=nil;
        if ([second save:&error] || !error || !second.hasChanges || ![second.deletedObjects containsObject:b] || counter.saves) return 13;
        NSManagedObjectContext *check=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; check.persistentStoreCoordinator=coordinator;
        if (![row(check,INT64_MIN+7).label isEqual:@"first writer"]) return 14;
        [second rollback];
    } else {
        second.mergePolicy=NSMergeByPropertyObjectTrumpMergePolicy; b.ratio=9.75;
        if (![second save:&error] || error || ![b.label isEqual:@"first writer"] || b.ratio!=9.75) return 15;
        first.mergePolicy=NSMergeByPropertyObjectTrumpMergePolicy; a.label=@"same first"; b.label=@"same second";
        if (![first save:&error] || ![second save:&error] || error || ![b.label isEqual:@"same second"]) return 16;
        AuthoredLedger *one=insert(first,10), *two=insert(second,11);
        if (![first save:&error] || ![second save:&error] || error || [one.objectID.URIRepresentation isEqual:two.objectID.URIRepresentation]) return 17;
        NSPersistentStoreCoordinator *stale=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:schema()] autorelease];
        if (![stale addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:path] options:nil error:&error]) return 18;
        NSManagedObjectContext *staleContext=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; staleContext.persistentStoreCoordinator=stale;
        insert(first,12); if (![first save:&error]) return 19;
        AuthoredLedger *pending=insert(staleContext,13); error=nil;
        if ([staleContext save:&error] || !error || !staleContext.hasChanges || ![staleContext.insertedObjects containsObject:pending]) return 20;
        NSManagedObjectContext *check=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; check.persistentStoreCoordinator=coordinator;
        if (!row(check,10) || !row(check,11) || !row(check,12) || row(check,13) || ![row(check,INT64_MIN+7).label isEqual:@"same second"] || row(check,INT64_MIN+7).ratio!=9.75) return 21;
    }
    [NSNotificationCenter.defaultCenter removeObserver:counter];
    return 0;
}
int main(int argc,const char **argv) {
    @autoreleasepool {
        if (argc!=3) return 2;
        @try { return writers([NSString stringWithUTF8String:argv[2]], strcmp(argv[1],"stale-delete")==0); }
        @catch (id exception) { return 90; }
    }
}
