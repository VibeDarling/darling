#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
static int Phase=90;
@interface AuthoredMemoryRow : NSManagedObject
@property(nonatomic,retain) NSString *label;
@property(nonatomic) BOOL enabled;
@end
@implementation AuthoredMemoryRow
@dynamic label,enabled;
@end
static NSManagedObjectModel *model(void) {
    NSAttributeDescription *label=[NSAttributeDescription new], *enabled=[NSAttributeDescription new];
    label.name=@"label"; label.attributeType=NSStringAttributeType; label.optional=YES;
    enabled.name=@"enabled"; enabled.attributeType=NSBooleanAttributeType; enabled.optional=YES;
    NSEntityDescription *entity=[NSEntityDescription new]; entity.name=@"MemoryRow"; entity.managedObjectClassName=NSStringFromClass(AuthoredMemoryRow.class); entity.properties=@[label,enabled];
    NSManagedObjectModel *schema=[NSManagedObjectModel new]; schema.entities=@[entity];
    [label release]; [enabled release]; [entity release]; return [schema autorelease];
}
static NSArray *rows(NSManagedObjectContext *context) { return [context executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"MemoryRow"] error:NULL]; }
static NSManagedObjectContext *context(NSPersistentStoreCoordinator *coordinator) {
    NSManagedObjectContext *result=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; result.persistentStoreCoordinator=coordinator; return result;
}
static int run(NSString *directory) {
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL] || ![NSFileManager.defaultManager changeCurrentDirectoryPath:directory]) return 10;
    NSArray *before=[NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:NULL];
    NSString *identity=nil;
    @autoreleasepool {
        NSPersistentStoreCoordinator *coordinator=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()] autorelease];
        NSError *error=nil;
        Phase=21;
        NSPersistentStore *store=[coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error];
        Phase=22;
        if (!store || error || ![store.type isEqual:NSInMemoryStoreType] || ![coordinator.persistentStores containsObject:store]) return 11;
        NSDictionary *metadata=[coordinator metadataForPersistentStore:store]; identity=[metadata[NSStoreUUIDKey] copy];
        if (![metadata[NSStoreTypeKey] isEqual:NSInMemoryStoreType] || !identity.length) return 12;
        NSManagedObjectContext *first=context(coordinator);
        if (!rows(first) || rows(first).count) return 13;
        AuthoredMemoryRow *a=[[[AuthoredMemoryRow alloc] initWithContext:first] autorelease], *b=[[[AuthoredMemoryRow alloc] initWithContext:first] autorelease];
        a.label=@"first λ"; a.enabled=YES; b.label=@"second"; b.enabled=NO;
        Phase=23;
        if (![first save:&error] || error || first.hasChanges || a.objectID.temporaryID || b.objectID.temporaryID || [a.objectID.URIRepresentation isEqual:b.objectID.URIRepresentation]) return 14;
        NSURL *reference=a.objectID.URIRepresentation;
        NSManagedObjectContext *second=context(coordinator); NSArray *all=rows(second);
        if (all.count!=2) return 15;
        AuthoredMemoryRow *found=nil, *other=nil;
        for (AuthoredMemoryRow *row in all) { if ([row.label isEqual:@"first λ"]) found=row; else other=row; }
        if (!found.enabled || other.enabled || ![reference isEqual:found.objectID.URIRepresentation]) return 16;
        found.label=@"updated"; [second deleteObject:other];
        if (![second save:&error] || error || second.hasChanges) return 17;
        NSArray *changed=rows(context(coordinator));
        if (changed.count!=1 || ![[changed.firstObject label] isEqual:@"updated"]) return 18;
        Phase=24;
        if (![coordinator removePersistentStore:store error:&error] || error || coordinator.persistentStores.count) return 19;
    }
    @autoreleasepool {
        NSPersistentStoreCoordinator *coordinator=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()] autorelease];
        Phase=25;
        NSPersistentStore *store=[coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL];
        if (!store || !rows(context(coordinator)) || rows(context(coordinator)).count || [identity isEqual:[coordinator metadataForPersistentStore:store][NSStoreUUIDKey]]) return 20;
    }
    [identity release];
    if (![[NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:NULL] isEqual:before]) return 26;
    return 0;
}
int main(int argc,const char **argv) {
    @autoreleasepool {
        if (argc!=2) return 2;
        @try { return run([NSString stringWithUTF8String:argv[1]]); }
        @catch (id exception) { return Phase>=21 && Phase<=25 ? Phase : 90; }
    }
}
