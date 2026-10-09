#import <UIKit/UISceneConfiguration.h>
#import <Foundation/NSException.h>

UISceneSessionRole const UIWindowSceneSessionRoleApplication = @"UIWindowSceneSessionRoleApplication";

@implementation UISceneConfiguration {
    NSString *_name;
    NSString *_role;
}
- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Use initWithName:sessionRole:"];
    return nil;
}
- (instancetype)initWithName:(NSString *)name sessionRole:(UISceneSessionRole)sessionRole
{
    if (sessionRole == nil)
        [NSException raise:NSInvalidArgumentException format:@"A scene session role is required"];
    if ((self = [super init])) {
        _name = [name copy];
        _role = [sessionRole copy];
    }
    return self;
}
+ (instancetype)configurationWithName:(NSString *)name sessionRole:(UISceneSessionRole)sessionRole
{
    return [[self alloc] initWithName:name sessionRole:sessionRole];
}
- (NSString *)name { return _name; }
- (UISceneSessionRole)role { return _role; }
- (id)copyWithZone:(NSZone *)zone
{
    UISceneConfiguration *copy = [[[self class] allocWithZone:zone] initWithName:_name sessionRole:_role];
    copy.sceneClass = self.sceneClass;
    copy.delegateClass = self.delegateClass;
    return copy;
}
@end
