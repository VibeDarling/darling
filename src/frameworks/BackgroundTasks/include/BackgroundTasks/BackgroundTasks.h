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

#import <Foundation/Foundation.h>

extern NSErrorDomain const BGTaskSchedulerErrorDomain;

typedef NS_ENUM(NSInteger, BGTaskSchedulerErrorCode) {
    BGTaskSchedulerErrorCodeUnavailable = 1,
    BGTaskSchedulerErrorCodeTooManyPendingTaskRequests = 2,
    BGTaskSchedulerErrorCodeNotPermitted = 3,
};

@interface BGTaskRequest : NSObject <NSCopying>
@property (readonly, copy) NSString *identifier;
@property (copy, nullable) NSDate *earliestBeginDate;
@end

@interface BGAppRefreshTaskRequest : BGTaskRequest
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

@interface BGProcessingTaskRequest : BGTaskRequest
- (instancetype)initWithIdentifier:(NSString *)identifier;
@property (assign) BOOL requiresNetworkConnectivity;
@property (assign) BOOL requiresExternalPower;
@end

@interface BGContinuedProcessingTaskRequest : BGTaskRequest
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title subtitle:(NSString *)subtitle;
@property (copy) NSString *title;
@property (copy) NSString *subtitle;
@end

@interface BGTask : NSObject
@property (readonly) NSString *identifier;
@property (copy, nullable) void (^expirationHandler)(void);
- (void)setTaskCompletedWithSuccess:(BOOL)success;
@end

@interface BGAppRefreshTask : BGTask
@end

@interface BGProcessingTask : BGTask
@end

@interface BGContinuedProcessingTask : BGTask
@property (readonly, copy) NSString *title;
@property (readonly, copy) NSString *subtitle;
- (void)updateTitle:(NSString *)title subtitle:(NSString *)subtitle;
@end

@interface BGTaskScheduler : NSObject
@property (class, readonly, strong) BGTaskScheduler *sharedScheduler;
- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier
                           usingQueue:(nullable dispatch_queue_t)queue
                        launchHandler:(void (^)(BGTask *task))launchHandler;
- (BOOL)submitTaskRequest:(BGTaskRequest *)taskRequest error:(NSError **)error;
- (void)cancelTaskRequestWithIdentifier:(NSString *)identifier;
- (void)cancelAllTaskRequests;
- (void)getPendingTaskRequestsWithCompletionHandler:(void (^)(NSArray<BGTaskRequest *> *taskRequests))completionHandler;
@end
