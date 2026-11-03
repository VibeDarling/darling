#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#include <string.h>

static NSManagedObjectModel *model(void) {
    NSAttributeDescription *label=[NSAttributeDescription new];
    label.name=@"label"; label.attributeType=NSStringAttributeType; label.optional=NO;
    NSEntityDescription *entity=[NSEntityDescription new];
    entity.name=@"CancelRow"; entity.managedObjectClassName=@"NSManagedObject"; entity.properties=@[label];
    NSManagedObjectModel *result=[NSManagedObjectModel new]; result.entities=@[entity];
    [label release]; [entity release]; return [result autorelease];
}
static NSManagedObjectContext *context(NSPersistentStoreCoordinator *coordinator) {
    NSManagedObjectContext *result=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease];
    result.persistentStoreCoordinator=coordinator; return result;
}
static NSArray *rows(NSManagedObjectContext *context,NSError **error) {
    return [context executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"CancelRow"] error:error];
}
static BOOL unchangedSibling(NSManagedObjectContext *context,NSString *reference) {
    NSError *error=nil; NSArray *values=rows(context,&error);
    return !error && values.count==1 && [[values[0] valueForKey:@"label"] isEqual:@"persisted sibling"] && [[[[values[0] objectID] URIRepresentation] absoluteString] isEqual:reference];
}
static int run(NSString *mode,NSString *path) {
    NSError *error=nil;
    NSPersistentStoreCoordinator *coordinator=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()] autorelease];
    if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:path] options:nil error:&error] || error) return 10;
    NSString *referencePath=[path stringByAppendingString:@".sibling.plist"];
    if ([mode isEqual:@"seed"]) {
        NSManagedObjectContext *initial=context(coordinator);
        if (rows(initial,&error).count || error) return 11;
        NSManagedObject *sibling=[NSEntityDescription insertNewObjectForEntityForName:@"CancelRow" inManagedObjectContext:initial];
        [sibling setValue:@"persisted sibling" forKey:@"label"];
        if (![initial save:&error] || error || initial.hasChanges || sibling.objectID.temporaryID) return 12;
        if (![@[sibling.objectID.URIRepresentation.absoluteString] writeToFile:referencePath atomically:YES]) return 13;
        return 0;
    }
    NSArray *saved=[NSArray arrayWithContentsOfFile:referencePath];
    if (saved.count!=1 || ![saved[0] isKindOfClass:NSString.class]) return 14;
    NSString *reference=saved[0];
    if ([mode isEqual:@"reopen"]) return unchangedSibling(context(coordinator),reference) ? 0 : 15;
    if (![mode isEqual:@"cancel"]) return 2;
    for (NSUInteger announced=0;announced<2;announced++) {
        NSManagedObjectContext *current=context(coordinator);
        if (!unchangedSibling(current,reference)) return 16;
        NSManagedObject *pending=[NSEntityDescription insertNewObjectForEntityForName:@"CancelRow" inManagedObjectContext:current];
        [pending setValue:@"valid canceled insertion" forKey:@"label"];
        if (!pending.objectID.temporaryID || !current.hasChanges || ![current.insertedObjects containsObject:pending]) return 17;
        if (announced) [current processPendingChanges];
        [current deleteObject:pending];
        if (announced) [current processPendingChanges];
        error=nil;
        if (![current save:&error] || error) return (int)(20+announced);
        if (current.hasChanges || current.insertedObjects.count || current.updatedObjects.count || current.deletedObjects.count) return (int)(30+announced);
        if (!unchangedSibling(current,reference) || !unchangedSibling(context(coordinator),reference)) return (int)(40+announced);
    }
    return 0;
}
int main(int argc,const char **argv) {
    @autoreleasepool {
        if (argc!=3) return 2;
        @try { return run([NSString stringWithUTF8String:argv[1]],[NSString stringWithUTF8String:argv[2]]); }
        @catch (id exception) { return 90; }
    }
}
