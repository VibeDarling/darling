#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#include <stdint.h>

@interface AuthoredAccessorBase : NSManagedObject
@property(nonatomic,readonly) NSString *explicitLabel;
@property(nonatomic,getter=isActive,setter=setActiveFlag:) BOOL active;
@property(nonatomic) int16_t small;
@property(nonatomic) int32_t middle;
@property(nonatomic) int64_t huge;
@property(nonatomic) float fractional;
@property(nonatomic) double precise;
@property(nonatomic,retain) NSString *inheritedText;
@end
@implementation AuthoredAccessorBase
@dynamic active,small,middle,huge,fractional,precise,inheritedText;
- (NSString *)explicitLabel { return @"authored inherited method"; }
@end
@interface AuthoredAccessorChild : AuthoredAccessorBase
@end
@implementation AuthoredAccessorChild
@end
int main(void) {
    @autoreleasepool {
        @try {
            NSEntityDescription *entity=[NSEntityDescription new]; entity.name=@"Probe"; entity.managedObjectClassName=NSStringFromClass(AuthoredAccessorChild.class);
            NSArray *names=@[@"explicitLabel",@"active",@"small",@"middle",@"huge",@"fractional",@"precise",@"inheritedText"];
            const NSAttributeType types[]={NSStringAttributeType,NSBooleanAttributeType,NSInteger16AttributeType,NSInteger32AttributeType,NSInteger64AttributeType,NSFloatAttributeType,NSDoubleAttributeType,NSStringAttributeType};
            NSMutableArray *properties=[NSMutableArray array];
            for (NSUInteger index=0; index<names.count; index++) {
                NSAttributeDescription *attribute=[NSAttributeDescription new]; attribute.name=names[index]; attribute.attributeType=types[index]; attribute.optional=YES;
                if (!index) attribute.defaultValue=@"authored stored default";
                [properties addObject:attribute]; [attribute release];
            }
            entity.properties=properties;
            NSManagedObjectModel *model=[NSManagedObjectModel new]; model.entities=@[entity];
            NSPersistentStoreCoordinator *coordinator=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model] autorelease];
            NSError *error=nil;
            if (![coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:[NSURL fileURLWithPath:@"/authored-unused-memory"] options:nil error:&error] || error) return 10;
            NSManagedObjectContext *context=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; context.persistentStoreCoordinator=coordinator;
            AuthoredAccessorChild *object=[[[AuthoredAccessorChild alloc] initWithContext:context] autorelease];
            if (![object.explicitLabel isEqual:@"authored inherited method"]) return 12;
            object.active=YES; object.small=INT16_MIN; object.middle=INT32_MIN; object.huge=INT64_MAX; object.fractional=-0.375f; object.precise=2.625; object.inheritedText=@"inherited λ";
            if (!object.active || object.small!=INT16_MIN || object.middle!=INT32_MIN || object.huge!=INT64_MAX || object.fractional!=-0.375f || object.precise!=2.625 || ![object.inheritedText isEqual:@"inherited λ"]) return 13;
            object.active=NO;
            if (object.active || ![[object valueForKey:@"small"] isEqual:@(INT16_MIN)] || ![[object valueForKey:@"huge"] isEqual:@(INT64_MAX)]) return 14;
            [entity release]; [model release];
            return 0;
        } @catch (id exception) { return 90; }
    }
}
