#ifndef DARLING_UIKIT_SCENE_CONFIGURATION_H
#define DARLING_UIKIT_SCENE_CONFIGURATION_H

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *UISceneSessionRole NS_TYPED_EXTENSIBLE_ENUM;

extern UISceneSessionRole const UIWindowSceneSessionRoleApplication;

@interface UISceneConfiguration : NSObject <NSCopying>
+ (instancetype)configurationWithName:(nullable NSString *)name sessionRole:(UISceneSessionRole)sessionRole;
- (instancetype)initWithName:(nullable NSString *)name sessionRole:(UISceneSessionRole)sessionRole;
@property(nonatomic, readonly, nullable) NSString *name;
@property(nonatomic, readonly) UISceneSessionRole role;
@property(nonatomic, nullable) Class sceneClass;
@property(nonatomic, nullable) Class delegateClass;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END

#endif
