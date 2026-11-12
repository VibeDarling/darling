#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#include <stdint.h>

static NSUInteger GetterCalls, SetterCalls, BothGetterCalls, BothSetterCalls;
@interface AuthoredMixedBase : NSManagedObject
@property(nonatomic,retain) NSString *getterOnly;
@property(nonatomic,retain) NSString *setterOnly;
@property(nonatomic,retain) NSString *both;
@property(nonatomic) int16_t small;
@end
@implementation AuthoredMixedBase
@dynamic getterOnly,setterOnly,both,small;
- (NSString *)getterOnly { GetterCalls++; return @"authored getter"; }
- (void)setSetterOnly:(NSString *)value { SetterCalls++; [self setValue:value forKey:@"setterOnly"]; }
- (NSString *)both { BothGetterCalls++; return [self primitiveValueForKey:@"both"]; }
- (void)setBoth:(NSString *)value { BothSetterCalls++; [self setValue:value forKey:@"both"]; }
@end
@interface AuthoredMixedChild : AuthoredMixedBase
@end
@implementation AuthoredMixedChild
@end

static NSManagedObjectContext *makeContext(Class representedClass,BOOL bare) {
    NSArray *names=bare ? @[@"small"] : @[@"getterOnly",@"setterOnly",@"both",@"small"];
    NSMutableArray *properties=[NSMutableArray array];
    for (NSString *name in names) {
        NSAttributeDescription *attribute=[NSAttributeDescription new]; attribute.name=name; attribute.optional=YES;
        attribute.attributeType=[name isEqual:@"small"] ? NSInteger16AttributeType : NSStringAttributeType;
        if (attribute.attributeType==NSStringAttributeType) attribute.defaultValue=@"authored default";
        [properties addObject:attribute]; [attribute release];
    }
    NSEntityDescription *entity=[NSEntityDescription new]; entity.name=@"Mixed"; entity.managedObjectClassName=NSStringFromClass(representedClass); entity.properties=properties;
    NSManagedObjectModel *model=[NSManagedObjectModel new]; model.entities=@[entity];
    NSPersistentStoreCoordinator *coordinator=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model] autorelease];
    [entity release]; [model release];
    NSError *error=nil;
    if (![coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error] || error) return nil;
    NSManagedObjectContext *context=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; context.persistentStoreCoordinator=coordinator; return context;
}
static unsigned check(AuthoredMixedBase *object) {
    unsigned failures=0;
    NSUInteger getter=GetterCalls;
    if (![object.getterOnly isEqual:@"authored getter"] || GetterCalls!=getter+1) failures|=1;
    object.getterOnly=@"stored getter";
    if (![[object primitiveValueForKey:@"getterOnly"] isEqual:@"stored getter"]) failures|=1;
    NSUInteger setter=SetterCalls;
    object.setterOnly=@"authored setter";
    if (SetterCalls!=setter+1 || ![object.setterOnly isEqual:@"authored setter"]) failures|=2;
    NSUInteger bothSetter=BothSetterCalls;
    object.both=@"authored both";
    NSUInteger bothGetter=BothGetterCalls;
    if (BothSetterCalls!=bothSetter+1 || ![object.both isEqual:@"authored both"] || BothGetterCalls!=bothGetter+1) failures|=4;
    object.small=INT16_MIN;
    if (object.small!=INT16_MIN || ![[object valueForKey:@"small"] isEqual:@(INT16_MIN)]) failures|=8;
    return failures;
}
int main(void) {
    @autoreleasepool {
        @try {
            NSManagedObjectContext *bare=makeContext(NSManagedObject.class,YES);
            if (!bare) return 10;
            NSManagedObject *untyped=[[[NSManagedObject alloc] initWithContext:bare] autorelease]; [untyped setValue:@(-1) forKey:@"small"];
            NSManagedObjectContext *parent=makeContext(AuthoredMixedBase.class,NO);
            if (!parent) return 11;
            AuthoredMixedBase *control=[[[AuthoredMixedBase alloc] initWithContext:parent] autorelease];
            if (check(control)) return 12;
            NSManagedObjectContext *child=makeContext(AuthoredMixedChild.class,NO);
            if (!child) return 13;
            AuthoredMixedChild *object=[[[AuthoredMixedChild alloc] initWithContext:child] autorelease];
            unsigned failures=check(object); if (failures) return (int)(20+failures);
            NSError *error=nil;
            if (![child save:&error] || error) return 40;
            NSManagedObjectContext *reopened=[[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease]; reopened.persistentStoreCoordinator=child.persistentStoreCoordinator;
            NSArray *results=[reopened executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Mixed"] error:&error];
            if (error || results.count!=1 || ![results.firstObject isKindOfClass:AuthoredMixedChild.class]) return 41;
            failures=check(results.firstObject); if (failures) return (int)(40+failures);
            return 0;
        } @catch (id exception) { return 90; }
    }
}
