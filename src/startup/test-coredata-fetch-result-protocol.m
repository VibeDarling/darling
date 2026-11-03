#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

int main(void) {
    @autoreleasepool {
        @try {
            Protocol *marker=@protocol(NSFetchRequestResult);
            if (![NSManagedObject conformsToProtocol:marker]) return 11;
            if (![NSManagedObjectID conformsToProtocol:marker]) return 12;
            if (![NSNumber conformsToProtocol:marker] || ![@(7) conformsToProtocol:marker]) return 13;
            if (![NSDictionary conformsToProtocol:marker] || ![@{@"authored":@(1)} conformsToProtocol:marker]) return 14;
            return 0;
        } @catch (id exception) { return 90; }
    }
}
