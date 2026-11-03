#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN
@interface AuthoredFetchRow : NSManagedObject
@property(nonatomic, retain) NSString *label;
@property(nonatomic, retain) NSDate *moment;
@end
NSManagedObjectContext *AuthoredContext(void);
NSEntityDescription *AuthoredEntity(NSManagedObjectContext *context);
void AuthoredAdd(NSManagedObjectContext *context);
void AuthoredEdit(NSManagedObjectContext *context);
void AuthoredDelete(NSManagedObjectContext *context);
void AuthoredOther(NSManagedObjectContext *context);
void AuthoredReturn(NSManagedObjectContext *context);
NS_ASSUME_NONNULL_END
