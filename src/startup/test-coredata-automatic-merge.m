#define main authoredMemoryMain
#include "test-coredata-memory-nil.m"
#undef main
#include <dispatch/dispatch.h>
#include <stdlib.h>
#include <string.h>

int main(int argc,const char **argv) {
    if (argc!=2 || (strcmp(argv[1],"enabled") && strcmp(argv[1],"disabled"))) return 2;
    BOOL enabled=strcmp(argv[1],"enabled")==0;
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            @try {
                NSPersistentStoreCoordinator *coordinator=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()] autorelease];
                NSError *error=nil;
                if (![coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error] || error) exit(10);
                NSManagedObjectContext *first=context(coordinator);
                AuthoredMemoryRow *row=[[[AuthoredMemoryRow alloc] initWithContext:first] autorelease]; row.label=@"authored row"; row.enabled=YES;
                if (![first save:&error] || error) exit(11);
                NSManagedObjectContext *second=context(coordinator); second.automaticallyMergesChangesFromParent=enabled;
                AuthoredMemoryRow *registered=rows(second).firstObject;
                if (!registered || rows(second).count!=1 || ![registered.label isEqual:@"authored row"] || !registered.enabled) exit(13);
                [first deleteObject:row];
                if (![first save:&error] || error) exit(14);
                dispatch_async(dispatch_get_main_queue(), ^{
                    @autoreleasepool {
                        @try {
                            if (enabled) {
                                NSError *fetchError=nil;
                                NSUInteger count=[second countForFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"MemoryRow"] error:&fetchError];
                                if (rows(second).count || count || fetchError || second.hasChanges || !registered.deleted) exit(12);
                            } else if (registered.deleted || ![registered.label isEqual:@"authored row"] || !registered.enabled || second.hasChanges) exit(12);
                            exit(0);
                        } @catch (id exception) { exit(90); }
                    }
                });
            } @catch (id exception) { exit(90); }
        }
    });
    dispatch_main();
}
