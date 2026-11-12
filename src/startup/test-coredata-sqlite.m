#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#include "darling-boundary-diagnostics.h"

@interface AuthoredRecord : NSManagedObject
@property(nonatomic, retain) NSString *label;
@property(nonatomic) BOOL enabled;
@property(nonatomic) int64_t sequence;
@property(nonatomic) double ratio;
@end
@implementation AuthoredRecord
@dynamic label, enabled, sequence, ratio;
@end

static NSManagedObjectModel *model(void) {
    NSEntityDescription *entity = [NSEntityDescription new];
    entity.name = @"Record";
    entity.managedObjectClassName = NSStringFromClass([AuthoredRecord class]);
    NSMutableArray *properties = [NSMutableArray array];
    NSArray *names = @[@"label", @"enabled", @"sequence", @"ratio"];
    const NSAttributeType types[] = {NSStringAttributeType, NSBooleanAttributeType, NSInteger64AttributeType, NSDoubleAttributeType};
    for (NSUInteger index = 0; index < names.count; index++) {
        NSAttributeDescription *attribute = [NSAttributeDescription new];
        attribute.name = names[index];
        attribute.attributeType = types[index];
        attribute.optional = YES;
        [properties addObject:attribute];
        [attribute release];
    }
    entity.properties = properties;
    NSManagedObjectModel *result = [NSManagedObjectModel new];
    result.entities = @[entity];
    [entity release];
    return [result autorelease];
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), DARLING_DIAG_FIXTURE_CASE_ENTER);
        @try {
            if (argc != 3) return 2;
            NSManagedObjectModel *schema = model();
            NSPersistentStoreCoordinator *coordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:schema] autorelease];
            NSError *error = nil;
            NSString *mode = [NSString stringWithUTF8String:argv[1]];
            NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]]];
            NSPersistentStore *store = [coordinator addPersistentStoreWithType:[mode isEqual:@"typed"] ? NSInMemoryStoreType : NSSQLiteStoreType configuration:nil URL:url options:nil error:&error];
            if (!store || error) return 20;
            NSManagedObjectContext *context = [[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease];
            context.persistentStoreCoordinator = coordinator;
            if ([mode isEqual:@"typed"]) {
                AuthoredRecord *record = [NSEntityDescription insertNewObjectForEntityForName:@"Record" inManagedObjectContext:context];
                record.label = @"typed λ";
                record.enabled = YES;
                record.sequence = INT64_MIN + 7;
                record.ratio = 3.125;
                if (![record.label isEqual:@"typed λ"] || !record.enabled || record.sequence != INT64_MIN + 7 || record.ratio != 3.125) return 21;
            }
            darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), DARLING_DIAG_FIXTURE_CASE_COMPLETE);
            return 0;
        } @catch (id exception) {
            return 30;
        }
    }
}
