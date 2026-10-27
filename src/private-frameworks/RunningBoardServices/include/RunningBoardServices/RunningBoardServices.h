/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef _RunningBoardServices_H_
#define _RunningBoardServices_H_

/* RunningBoardServices, best effort from class-dumped headers (it ships on
   macOS 10.15+ and iOS 13+). There is no runningboardd: process facts come
   straight from libproc, and assertions are tracked in-process only. */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(unsigned char, RBSTaskState) {
	RBSTaskStateUnknown = 0,
	RBSTaskStateNone = 1,
	RBSTaskStateRunningScheduled = 2,
	RBSTaskStateRunningSuspended = 3,
	RBSTaskStateRunning = 4,
};

@class RBSProcessHandle;

@interface RBSProcessIdentifier : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)identifierWithPid:(pid_t)pid;
+ (instancetype)identifierForCurrentProcess;
@property (nonatomic, readonly) pid_t pid;
@end

@interface RBSProcessPredicate : NSObject <NSCopying>
+ (instancetype)predicateMatchingIdentifier:(RBSProcessIdentifier *)identifier;
+ (instancetype)predicateMatchingBundleIdentifier:(NSString *)bundleIdentifier;
+ (instancetype)predicateMatchingBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers;
- (BOOL)matchesProcess:(RBSProcessHandle *)process;
@end

@interface RBSProcessState : NSObject <NSCopying>
@property (nonatomic, readonly, strong) RBSProcessHandle *process;
@property (nonatomic, readonly) RBSTaskState taskState;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@end

@interface RBSProcessHandle : NSObject <NSCopying>
+ (instancetype)currentProcess;
+ (nullable instancetype)handleForIdentifier:(RBSProcessIdentifier *)identifier error:(NSError **)error;
+ (nullable instancetype)handleForPredicate:(RBSProcessPredicate *)predicate error:(NSError **)error;
/* Not in Apple's API: every live process the predicate matches. */
+ (NSArray<RBSProcessHandle *> *)handlesForPredicate:(RBSProcessPredicate *)predicate;
@property (nonatomic, readonly, strong) RBSProcessIdentifier *identifier;
@property (nonatomic, readonly) pid_t pid;
@property (nonatomic, readonly) pid_t rbs_pid;
@property (nonatomic, readonly, copy, nullable) NSString *name;
@property (nonatomic, readonly, copy, nullable) NSString *executablePath;
@property (nonatomic, readonly, copy, nullable) NSString *bundleIdentifier;
@property (nonatomic, readonly, getter=isValid) BOOL valid;
@property (nonatomic, readonly, strong) RBSProcessState *currentState;
@end

@interface RBSTarget : NSObject <NSCopying>
+ (instancetype)currentProcess;
+ (instancetype)targetWithPid:(pid_t)pid;
+ (instancetype)targetWithProcessIdentifier:(RBSProcessIdentifier *)identifier;
@property (nonatomic, readonly, strong, nullable) RBSProcessIdentifier *processIdentifier;
@end

@interface RBSAttribute : NSObject <NSCopying>
@end

@interface RBSDomainAttribute : RBSAttribute
+ (instancetype)attributeWithDomain:(NSString *)domain name:(NSString *)name;
@property (nonatomic, readonly, copy) NSString *domain;
@property (nonatomic, readonly, copy) NSString *name;
@end

@interface RBSAssertion : NSObject
- (instancetype)initWithExplanation:(NSString *)explanation target:(RBSTarget *)target attributes:(NSArray<RBSAttribute *> *)attributes;
- (BOOL)acquireWithError:(NSError **)error;
- (void)acquireWithInvalidationHandler:(nullable void (^)(RBSAssertion *assertion, NSError *error))handler;
- (void)invalidate;
- (BOOL)invalidateSyncWithError:(NSError **)error;
@property (nonatomic, readonly, copy) NSString *explanation;
@property (nonatomic, readonly, strong) RBSTarget *target;
@property (nonatomic, readonly, copy) NSArray<RBSAttribute *> *attributes;
@property (nonatomic, readonly, getter=isValid) BOOL valid;
/* Not in Apple's API: assertions currently held on a target in this process. */
+ (NSArray<RBSAssertion *> *)acquiredAssertionsForTarget:(RBSTarget *)target;
@end

extern NSErrorDomain const RBSRequestErrorDomain;

typedef NS_ENUM(NSInteger, RBSRequestErrorCode) {
	RBSRequestErrorFailed = 1,
	RBSRequestErrorInvalidParameters = 2,
	RBSRequestErrorProcessNotFound = 3,
};

NS_ASSUME_NONNULL_END

#endif
