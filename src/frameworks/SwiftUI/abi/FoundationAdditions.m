// Foundation methods apps call that Darling's CFNetwork does not have yet. They are added here, rather
// than in the submodule, only until it has them: class_addMethod leaves a real implementation alone.
#import <Foundation/Foundation.h>
#include <objc/runtime.h>

static NSString *valueForHTTPHeaderField(NSHTTPURLResponse *self, SEL _cmd, NSString *field)
{
    NSDictionary *fields = [self allHeaderFields];
    for (NSString *key in fields)
        if ([key caseInsensitiveCompare:field] == NSOrderedSame)
            return fields[key];
    return nil;
}

@interface NSHTTPURLResponse (DarlingSwiftUI)
@end
@implementation NSHTTPURLResponse (DarlingSwiftUI)
+ (void)load
{
    class_addMethod(self, @selector(valueForHTTPHeaderField:), (IMP)valueForHTTPHeaderField, "@@:@");
}
@end
