#import <CoreAudio/CATapDescription.h>

@implementation CATapDescription

@synthesize name = _name;
@synthesize processes = _processes;
@synthesize uuid = _uuid;
@synthesize tapPrivate = _private;
@synthesize mixdown = _mixdown;
@synthesize mono = _mono;
@synthesize exclusive = _exclusive;

- (instancetype)init
{
    if ((self = [super init])) {
        _name = [@"" copy];
        _processes = [[NSArray alloc] init];
        _uuid = [[NSUUID alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_name release];
    [_processes release];
    [_uuid release];
    [super dealloc];
}

@end
