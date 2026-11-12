#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

// A store reopened with a model that differs only in optionality, transience or defaults migrates when
// automatic lightweight migration is requested; one whose stored data the new model rejects does not.

static NSManagedObjectModel *model(BOOL valueOptional, BOOL noteOptional, BOOL noteTransient, NSAttributeType noteType) {
    NSAttributeDescription *value = [[NSAttributeDescription new] autorelease];
    value.name = @"value"; value.attributeType = NSStringAttributeType; value.optional = valueOptional;
    NSAttributeDescription *note = [[NSAttributeDescription new] autorelease];
    note.name = @"note"; note.attributeType = noteType; note.optional = noteOptional; note.transient = noteTransient;
    NSEntityDescription *entity = [[NSEntityDescription new] autorelease];
    entity.name = @"Item"; entity.properties = @[value, note];
    NSManagedObjectModel *result = [[NSManagedObjectModel new] autorelease];
    result.entities = @[entity];
    return result;
}
static NSDictionary *migrate(void) {
    return @{NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES};
}
static NSManagedObjectContext *openContext(NSManagedObjectModel *schema, NSString *path, NSDictionary *options) {
    NSPersistentStoreCoordinator *coordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:schema] autorelease];
    if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:path] options:options error:NULL])
        return nil;
    NSManagedObjectContext *context = [[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease];
    context.persistentStoreCoordinator = coordinator;
    return context;
}
static NSArray *items(NSManagedObjectContext *context) {
    return [context executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Item"] error:NULL];
}
static BOOL insert(NSManagedObjectContext *context, NSString *value, id note) {
    NSManagedObject *item = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:context];
    [item setValue:value forKey:@"value"];
    [item setValue:note forKey:@"note"];
    return [context save:NULL];
}
static BOOL unchanged(NSString *path, NSData *before) { return [[NSData dataWithContentsOfFile:path] isEqual:before]; }

static int run(NSString *root) {
    if (![NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL]) return 10;
    NSString *path = [root stringByAppendingPathComponent:@"migration.sqlite"];

    // Both attributes required: the stored item has both values.
    NSManagedObjectContext *context = openContext(model(NO, NO, NO, NSStringAttributeType), path, nil);
    if (!context || !insert(context, @"first", @"kept")) return 13;
    NSData *before = [NSData dataWithContentsOfFile:path];

    // A different model without migration options is refused and leaves the file alone.
    if (openContext(model(YES, NO, NO, NSStringAttributeType), path, nil) || !unchanged(path, before)) return 14;
    // An attribute type change is not a lightweight migration.
    if (openContext(model(NO, NO, NO, NSInteger64AttributeType), path, migrate()) || !unchanged(path, before)) return 15;

    // Making value optional migrates; an item without value then saves, and the migrated model opens plainly.
    context = openContext(model(YES, NO, NO, NSStringAttributeType), path, migrate());
    if (!context || [items(context) count] != 1 || !insert(context, nil, @"no value")) return 16;
    context = openContext(model(YES, NO, NO, NSStringAttributeType), path, nil);
    if (!context || [items(context) count] != 2) return 17;
    before = [NSData dataWithContentsOfFile:path];

    // Value required again: the item without one makes the migration fail, and nothing changes.
    if (openContext(model(NO, NO, NO, NSStringAttributeType), path, migrate()) || !unchanged(path, before)) return 18;

    // A note that becomes transient is dropped from the store.
    context = openContext(model(YES, YES, YES, NSStringAttributeType), path, migrate());
    if (!context || [items(context) count] != 2) return 19;
    for (NSManagedObject *item in items(context)) if ([item valueForKey:@"note"]) return 20;
    context = openContext(model(YES, YES, NO, NSStringAttributeType), path, migrate());
    if (!context || [items(context) count] != 2) return 21;
    for (NSManagedObject *item in items(context)) if ([item valueForKey:@"note"]) return 22;
    return 0;
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc != 2) return 2;
        @try { return run([NSString stringWithUTF8String:argv[1]]); }
        @catch (id exception) { NSLog(@"%@", exception); return 90; }
    }
}
