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

#import <BackgroundTasks/BackgroundTasks.h>

// Nothing here launches an app in the background, so the scheduler accepts
// registrations and refuses requests with BGTaskSchedulerErrorCodeUnavailable,
// which is what iOS answers when background refresh is off. No task ever runs.

NSErrorDomain const BGTaskSchedulerErrorDomain = @"BGTaskSchedulerErrorDomain";

@implementation BGTaskRequest
@synthesize identifier = _identifier, earliestBeginDate = _earliestBeginDate;

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if ((self = [super init]))
        _identifier = [identifier copy];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    BGTaskRequest *copy = [[[self class] allocWithZone:zone] initWithIdentifier:_identifier];
    copy.earliestBeginDate = _earliestBeginDate;
    return copy;
}

- (void)dealloc
{
    [_identifier release];
    [_earliestBeginDate release];
    [super dealloc];
}
@end

@implementation BGAppRefreshTaskRequest
- (instancetype)initWithIdentifier:(NSString *)identifier
{
    return [super initWithIdentifier:identifier];
}
@end

@implementation BGProcessingTaskRequest
@synthesize requiresNetworkConnectivity = _requiresNetworkConnectivity, requiresExternalPower = _requiresExternalPower;
- (instancetype)initWithIdentifier:(NSString *)identifier
{
    return [super initWithIdentifier:identifier];
}
@end

@implementation BGContinuedProcessingTaskRequest
@synthesize title = _title, subtitle = _subtitle;

- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title subtitle:(NSString *)subtitle
{
    if ((self = [super initWithIdentifier:identifier])) {
        _title = [title copy];
        _subtitle = [subtitle copy];
    }
    return self;
}

- (void)dealloc
{
    [_title release];
    [_subtitle release];
    [super dealloc];
}
@end

@implementation BGTask
@synthesize identifier = _identifier, expirationHandler = _expirationHandler;

- (void)setTaskCompletedWithSuccess:(BOOL)success
{
}

- (void)dealloc
{
    [_identifier release];
    [_expirationHandler release];
    [super dealloc];
}
@end

@implementation BGAppRefreshTask
@end

@implementation BGProcessingTask
@end

@implementation BGContinuedProcessingTask
@synthesize title = _title, subtitle = _subtitle;

- (void)updateTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    [_title release];
    _title = [title copy];
    [_subtitle release];
    _subtitle = [subtitle copy];
}

- (void)dealloc
{
    [_title release];
    [_subtitle release];
    [super dealloc];
}
@end

@implementation BGTaskScheduler

+ (BGTaskScheduler *)sharedScheduler
{
    static BGTaskScheduler *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[BGTaskScheduler alloc] init]; });
    return shared;
}

- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier
                           usingQueue:(dispatch_queue_t)queue
                        launchHandler:(void (^)(BGTask *task))launchHandler
{
    return YES;
}

- (BOOL)submitTaskRequest:(BGTaskRequest *)taskRequest error:(NSError **)error
{
    if (error)
        *error = [NSError errorWithDomain:BGTaskSchedulerErrorDomain
                                     code:BGTaskSchedulerErrorCodeUnavailable userInfo:nil];
    return NO;
}

- (void)cancelTaskRequestWithIdentifier:(NSString *)identifier
{
}

- (void)cancelAllTaskRequests
{
}

- (void)getPendingTaskRequestsWithCompletionHandler:(void (^)(NSArray<BGTaskRequest *> *))completionHandler
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ completionHandler(@[]); });
}

@end
