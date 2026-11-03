#import "test-coredata-swift-fetch.h"
@implementation AuthoredFailingFetchContext
- (NSArray *)executeFetchRequest:(NSFetchRequest *)request error:(NSError **)error {
    (void)request;
    if (error) *error=[NSError errorWithDomain:@"invalid.example.AuthoredFetch" code:731 userInfo:nil];
    return nil;
}
@end
@implementation AuthoredSuccessWithErrorFetchContext
- (NSArray *)executeFetchRequest:(NSFetchRequest *)request error:(NSError **)error {
    (void)request;
    if (error) *error=[NSError errorWithDomain:@"invalid.example.IgnoredAfterSuccess" code:732 userInfo:nil];
    return @[];
}
@end
extern int authored_swift_fetch_probe(void);
extern int authored_swift_fetch_stage(void);
int main(void) {
    @autoreleasepool {
        @try { return authored_swift_fetch_probe(); }
        @catch (id exception) { int stage=authored_swift_fetch_stage(); return stage>=50 && stage<=64 ? stage+50 : 90; }
    }
}
