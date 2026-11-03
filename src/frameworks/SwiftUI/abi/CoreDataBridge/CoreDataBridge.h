#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN
void DarlingSwiftUIEntry(void);
void DarlingSwiftUIPhase(int phase);
@interface DarlingContextObservation : NSObject
- (instancetype)initWithContext:(NSManagedObjectContext *)context change:(void (^)(void))change;
- (void)cancel;
@end
NSArray * _Nullable DarlingContextFetch(NSManagedObjectContext *context, NSEntityDescription *entity,
    NSArray<NSSortDescriptor *> *sortDescriptors, NSPredicate * _Nullable predicate);
NS_ASSUME_NONNULL_END
