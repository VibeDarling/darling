#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface AuthoredUpdateRow : NSManagedObject
@property(nonatomic,retain) NSString *label;
@property(nonatomic,retain) NSDate *moment;
@end
@implementation AuthoredUpdateRow
@dynamic label,moment;
@end
@interface AuthoredChangeCounter : NSObject
@property(nonatomic) NSUInteger changes;
@property(nonatomic) NSUInteger saves;
@end
@implementation AuthoredChangeCounter
- (void)changed:(NSNotification *)note { (void)note; self.changes++; }
- (void)saved:(NSNotification *)note { (void)note; self.saves++; }
@end
int main(void) {
    @autoreleasepool {
        @try {
            NSAttributeDescription *label=[NSAttributeDescription new], *moment=[NSAttributeDescription new];
            label.name=@"label"; label.attributeType=NSStringAttributeType; label.optional=YES;
            moment.name=@"moment"; moment.attributeType=NSDateAttributeType; moment.optional=YES;
            NSEntityDescription *entity=[NSEntityDescription new]; entity.name=@"UpdateRow"; entity.managedObjectClassName=NSStringFromClass(AuthoredUpdateRow.class); entity.properties=@[label,moment];
            NSManagedObjectModel *model=[NSManagedObjectModel new]; model.entities=@[entity];
            NSPersistentStoreCoordinator *coordinator=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model] autorelease];
            NSError *error=nil;
            if (![coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error] || error) return 10;
            NSManagedObjectContext *context=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; context.persistentStoreCoordinator=coordinator;
            AuthoredChangeCounter *counter=[[[AuthoredChangeCounter alloc] init] autorelease];
            [NSNotificationCenter.defaultCenter addObserver:counter selector:@selector(changed:) name:NSManagedObjectContextObjectsDidChangeNotification object:context];
            [NSNotificationCenter.defaultCenter addObserver:counter selector:@selector(saved:) name:NSManagedObjectContextDidSaveNotification object:context];
            __block NSUInteger blockChanges=0;
            id token=[[NSNotificationCenter.defaultCenter addObserverForName:NSManagedObjectContextObjectsDidChangeNotification object:context queue:nil usingBlock:^(NSNotification *note) { (void)note; blockChanges++; }] retain];
            AuthoredUpdateRow *a=[[[AuthoredUpdateRow alloc] initWithContext:context] autorelease], *b=[[[AuthoredUpdateRow alloc] initWithContext:context] autorelease];
            a.label=@"first"; a.moment=[NSDate dateWithTimeIntervalSinceReferenceDate:1];
            b.label=@"second"; b.moment=[NSDate dateWithTimeIntervalSinceReferenceDate:2];
            [context processPendingChanges];
            if (!counter.changes || !blockChanges || counter.saves || !a.inserted || context.insertedObjects.count!=2) return 11;
            counter.changes=counter.saves=blockChanges=0;
            a.label=@"edited first"; a.moment=[NSDate dateWithTimeIntervalSinceReferenceDate:30];
            if (!a.inserted || ![context.insertedObjects containsObject:a] || [context.updatedObjects containsObject:a]) return 12;
            error=nil;
            if (![context save:&error] || error) return 13;
            [context processPendingChanges];
            unsigned failure=0;
            if (!counter.changes) failure|=1;
            if (!blockChanges) failure|=2;
            if (!counter.saves) failure|=4;
            if (context.hasChanges || a.inserted || context.insertedObjects.count) return 14;
            NSFetchRequest *request=[NSFetchRequest fetchRequestWithEntityName:@"UpdateRow"];
            request.sortDescriptors=@[[NSSortDescriptor sortDescriptorWithKey:@"moment" ascending:NO]];
            NSArray *values=[context executeFetchRequest:request error:&error];
            if (error || values.count!=2 || values.firstObject!=a || ![a.label isEqual:@"edited first"]) return 15;
            counter.changes=counter.saves=blockChanges=0;
            a.label=@"committed edit"; a.moment=[NSDate dateWithTimeIntervalSinceReferenceDate:40];
            error=nil; if (![context save:&error] || error) return 16;
            [context processPendingChanges];
            if (!counter.changes) failure|=8;
            if (!blockChanges) failure|=16;
            if (!counter.saves) failure|=32;
            [NSNotificationCenter.defaultCenter removeObserver:token]; [token release];
            [NSNotificationCenter.defaultCenter removeObserver:counter];
            [label release]; [moment release]; [entity release]; [model release];
            return failure ? (int)(64+failure) : 0;
        } @catch (id exception) { return 90; }
    }
}
