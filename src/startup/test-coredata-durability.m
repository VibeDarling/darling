#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#include <sqlite3.h>
#include <limits.h>

@interface AuthoredLedger : NSManagedObject
@property(nonatomic,retain) NSString *label;
@property(nonatomic) BOOL enabled;
@property(nonatomic) int64_t sequence;
@property(nonatomic) double ratio;
@property(nonatomic) float sample;
@property(nonatomic,retain) NSDate *moment;
@property(nonatomic,retain) NSURL *link;
@property(nonatomic,retain) NSData *payload;
@property(nonatomic,retain) NSManagedObject *owner;
@end
@implementation AuthoredLedger
@dynamic label,enabled,sequence,ratio,sample,moment,link,payload,owner;
@end
@interface AuthoredCollection : NSManagedObject
@property(nonatomic,retain) NSString *label;
@property(nonatomic,retain) NSSet *entries;
@end
@implementation AuthoredCollection
@dynamic label,entries;
@end
@interface SaveCounter : NSObject
@property(nonatomic) NSUInteger saves;
@end
@implementation SaveCounter
- (void)saved:(NSNotification *)note { (void)note; self.saves++; }
@end

static NSManagedObjectModel *schema(void) {
    NSEntityDescription *entry = [NSEntityDescription new], *collection = [NSEntityDescription new];
    entry.name = @"Ledger"; entry.managedObjectClassName = NSStringFromClass(AuthoredLedger.class);
    collection.name = @"Collection"; collection.managedObjectClassName = NSStringFromClass(AuthoredCollection.class);
    NSArray *names = @[@"label",@"enabled",@"sequence",@"ratio",@"sample",@"moment",@"link",@"payload"];
    const NSAttributeType types[] = {NSStringAttributeType,NSBooleanAttributeType,NSInteger64AttributeType,NSDoubleAttributeType,NSFloatAttributeType,NSDateAttributeType,NSURIAttributeType,NSBinaryDataAttributeType};
    NSMutableArray *attributes = [NSMutableArray array];
    for (NSUInteger index=0; index<names.count; index++) {
        NSAttributeDescription *attribute = [NSAttributeDescription new];
        attribute.name = names[index]; attribute.attributeType = types[index]; attribute.optional = YES;
        [attributes addObject:attribute]; [attribute release];
    }
    NSRelationshipDescription *owner = [NSRelationshipDescription new], *entries = [NSRelationshipDescription new];
    owner.name = @"owner"; owner.destinationEntity = collection; owner.maxCount = 1; owner.optional = YES; owner.deleteRule = NSNullifyDeleteRule;
    entries.name = @"entries"; entries.destinationEntity = entry; entries.maxCount = 0; entries.optional = YES; entries.deleteRule = NSNullifyDeleteRule;
    owner.inverseRelationship = entries; entries.inverseRelationship = owner;
    [attributes addObject:owner]; entry.properties = attributes;
    NSAttributeDescription *name = [NSAttributeDescription new]; name.name = @"label"; name.attributeType = NSStringAttributeType; name.optional = YES;
    collection.properties = @[name,entries];
    NSManagedObjectModel *model = [NSManagedObjectModel new]; model.entities = @[entry,collection];
    [entry release]; [collection release]; [owner release]; [entries release]; [name release];
    return [model autorelease];
}
static NSArray *fetch(NSManagedObjectContext *context, NSString *name) {
    NSError *error = nil;
    NSArray *result = [context executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:name] error:&error];
    return error ? nil : result;
}
static AuthoredLedger *row(NSManagedObjectContext *context, int64_t sequence) {
    for (AuthoredLedger *record in fetch(context,@"Ledger")) if (record.sequence == sequence) return record;
    return nil;
}
static AuthoredLedger *insert(NSManagedObjectContext *context, int64_t sequence) {
    AuthoredLedger *record = [[[AuthoredLedger alloc] initWithContext:context] autorelease];
    record.sequence = sequence; record.label = [NSString stringWithFormat:@"entry%lld",(long long)sequence];
    record.enabled = sequence == 1; record.ratio = -3.125; record.sample = 0.25f;
    record.moment = [NSDate dateWithTimeIntervalSinceReferenceDate:sequence*100.25];
    return record;
}
static int run(NSString *mode, NSString *path) {
    NSManagedObjectModel *model = schema();
    NSPersistentStoreCoordinator *coordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model] autorelease];
    NSError *error = nil;
    BOOL readonly = [mode isEqual:@"readonly"];
    NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:path] options:readonly ? @{NSReadOnlyPersistentStoreOption:@YES} : nil error:&error];
    if (!store || error) return 10;
    NSManagedObjectContext *context = [[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; context.persistentStoreCoordinator = coordinator;
    SaveCounter *counter = [[[SaveCounter alloc] init] autorelease];
    [NSNotificationCenter.defaultCenter addObserver:counter selector:@selector(saved:) name:NSManagedObjectContextDidSaveNotification object:context];
    if ([mode isEqual:@"create"]) {
        if ([fetch(context,@"Ledger") count] || !fetch(context,@"Ledger")) return 11;
        if ([AuthoredLedger entity] != model.entitiesByName[@"Ledger"]) return 12;
        AuthoredCollection *first = [[[AuthoredCollection alloc] initWithContext:context] autorelease], *second = [[[AuthoredCollection alloc] initWithContext:context] autorelease];
        first.label = @"first"; second.label = @"second";
        AuthoredLedger *a=insert(context,1), *b=insert(context,2), *c=insert(context,3);
        a.label = @"quote' λ 🐾"; a.sequence = INT64_MIN+7; a.link = [NSURL URLWithString:@"https://example.invalid/a%20b?q=%CE%BB#part"]; a.moment = [NSDate dateWithTimeIntervalSinceReferenceDate:-100.5];
        const unsigned char bytes[] = {0,1,0,255}; a.payload = [NSData dataWithBytes:bytes length:sizeof(bytes)];
        b.label = @""; b.link = [NSURL fileURLWithPath:@"/owned/a b"]; b.payload = [NSData data]; c.label = nil; c.payload = nil;
        a.owner = first; b.owner = first; c.owner = second;
        if (first.entries.count != 2 || second.entries.count != 1) return 13;
        a.owner = second;
        if (first.entries.count != 1 || second.entries.count != 2 || a.owner != second) return 14;
        [[first mutableSetValueForKey:@"entries"] addObject:a];
        if (a.owner != first || first.entries.count != 2 || second.entries.count != 1) return 15;
        if (!context.hasChanges || ![context save:&error] || error || context.hasChanges || counter.saves != 1) return 16;
        if (a.objectID.temporaryID || a.inserted || a.updated) return 17;
        NSDictionary *metadata = [coordinator metadataForPersistentStore:store];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSDictionary *diskMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:[NSURL fileURLWithPath:path] error:&error];
#pragma clang diagnostic pop
        if (![metadata[NSStoreTypeKey] isEqual:NSSQLiteStoreType] || ![metadata[NSStoreUUIDKey] isEqual:diskMetadata[NSStoreUUIDKey]]) return 18;
        NSDictionary *references = @{@"uuid":metadata[NSStoreUUIDKey], @"a":a.objectID.URIRepresentation.absoluteString, @"b":b.objectID.URIRepresentation.absoluteString, @"c":c.objectID.URIRepresentation.absoluteString};
        if (![references writeToFile:[path stringByAppendingString:@".references"] atomically:YES]) return 19;
    } else if ([mode isEqual:@"reopen"] || readonly) {
        NSArray *all = fetch(context,@"Ledger"); if (all.count != 3 || ![all[0] isKindOfClass:AuthoredLedger.class]) return 20;
        AuthoredLedger *a=row(context,INT64_MIN+7), *b=row(context,2), *c=row(context,3);
        const unsigned char bytes[] = {0,1,0,255};
        if (![a.label isEqual:@"quote' λ 🐾"] || !a.enabled || a.ratio != -3.125 || a.sample != 0.25f || ![a.payload isEqual:[NSData dataWithBytes:bytes length:sizeof(bytes)]] || a.moment.timeIntervalSinceReferenceDate != -100.5) return 21;
        if (![a.link.absoluteString isEqual:@"https://example.invalid/a%20b?q=%CE%BB#part"] || !b.link.fileURL || ![b.label isEqual:@""] || b.payload.length || !b.payload || c.label || c.payload || c.link) return 22;
        if (a.owner != b.owner || a.owner == c.owner || [[a.owner valueForKey:@"entries"] count] != 2) return 23;
        NSDictionary *references = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingString:@".references"]];
        if (![references[@"a"] isEqual:a.objectID.URIRepresentation.absoluteString] || ![references[@"uuid"] isEqual:[coordinator metadataForPersistentStore:store][NSStoreUUIDKey]]) return 24;
        NSFetchRequest *request = [AuthoredLedger fetchRequest]; request.predicate = [NSPredicate predicateWithFormat:@"label == %@",@"quote' λ 🐾"];
        if ([context countForFetchRequest:request error:&error] != 1) return 25;
        request = [[[NSFetchRequest alloc] initWithEntityName:@"Ledger"] autorelease]; request = [[request copy] autorelease]; request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"moment" ascending:YES]]; request.fetchLimit = 1;
        if ([[context executeFetchRequest:request error:&error] firstObject] != a) return 26;
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"moment" ascending:NO]];
        if ([[context executeFetchRequest:request error:&error] firstObject] != c) return 27;
        if (readonly) {
            a.label = @"blocked"; if ([context save:&error] || !error || !context.hasChanges || counter.saves) return 28;
            [context rollback]; if (context.hasChanges || ![a.label isEqual:@"quote' λ 🐾"]) return 29;
        }
    } else if ([mode isEqual:@"change"]) {
        AuthoredLedger *a=row(context,INT64_MIN+7), *b=row(context,2), *c=row(context,3);
        a.label = @"updated"; a.link = nil; a.payload = [NSData data];
        [context deleteObject:c.owner]; [context deleteObject:b];
        if (c.owner || [[a.owner valueForKey:@"entries"] count] != 1) return 30;
        if (![context save:&error] || error || context.hasChanges) return 31;
    } else if ([mode isEqual:@"changed"]) {
        AuthoredLedger *a=row(context,INT64_MIN+7), *c=row(context,3);
        if (fetch(context,@"Ledger").count != 2 || fetch(context,@"Collection").count != 1 || ![a.label isEqual:@"updated"] || a.link || !a.payload || a.payload.length || c.owner || [[a.owner valueForKey:@"entries"] count] != 1) return 32;
    } else if ([mode isEqual:@"retry"]) {
        AuthoredLedger *a=row(context,INT64_MIN+7); NSString *oldLabel = [[a.label copy] autorelease];
        sqlite3 *reader = NULL;
        if (sqlite3_open_v2(path.fileSystemRepresentation,&reader,SQLITE_OPEN_READONLY,NULL) != SQLITE_OK || sqlite3_exec(reader,"BEGIN; SELECT count(*) FROM sqlite_master",NULL,NULL,NULL) != SQLITE_OK) return 40;
        a.label = @"retry saved"; AuthoredLedger *added=insert(context,9);
        if ([context save:&error] || !error || !context.hasChanges || counter.saves || ![context.insertedObjects containsObject:added] || ![context.updatedObjects containsObject:a]) { sqlite3_close(reader); return 41; }
        sqlite3_exec(reader,"ROLLBACK",NULL,NULL,NULL); sqlite3_close(reader);
        NSManagedObjectContext *check = [[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; check.persistentStoreCoordinator=coordinator;
        if (![row(check,INT64_MIN+7).label isEqual:oldLabel] || row(check,9)) return 42;
        error = nil; if (![context save:&error] || error || context.hasChanges || counter.saves != 1) return 43;
    } else if ([mode isEqual:@"retried"]) {
        if (![row(context,INT64_MIN+7).label isEqual:@"retry saved"] || !row(context,9)) return 44;
    } else if ([mode isEqual:@"integrity"]) {
        sqlite3 *database = NULL; sqlite3_stmt *statement = NULL;
        BOOL valid = sqlite3_open_v2(path.fileSystemRepresentation,&database,SQLITE_OPEN_READONLY,NULL) == SQLITE_OK && sqlite3_prepare_v2(database,"PRAGMA integrity_check",-1,&statement,NULL) == SQLITE_OK && sqlite3_step(statement) == SQLITE_ROW && strcmp((const char *)sqlite3_column_text(statement,0),"ok") == 0;
        sqlite3_finalize(statement); sqlite3_close(database); if (!valid) return 45;
    } else return 3;
    [NSNotificationCenter.defaultCenter removeObserver:counter];
    return 0;
}
int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc != 3) return 2;
        @try { return run([NSString stringWithUTF8String:argv[1]],[NSString stringWithUTF8String:argv[2]]); }
        @catch (id exception) { return 90; }
    }
}
