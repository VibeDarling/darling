/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UILocalNotification.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIApplicationDelegate.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "UIKitPrivate.h"

NSString *const UILocalNotificationDefaultSoundName = @"UILocalNotificationDefaultSoundName";

/* Which UILocalNotification a request was made from. */
static NSString *const UIKitLocalNotificationKey = @"UIKitLocalNotificationIdentifier";

@implementation UILocalNotification {
@public
	NSString *_identifier;
}

@synthesize fireDate = _fireDate;
@synthesize timeZone = _timeZone;
@synthesize repeatInterval = _repeatInterval;
@synthesize repeatCalendar = _repeatCalendar;
@synthesize alertBody = _alertBody;
@synthesize alertTitle = _alertTitle;
@synthesize hasAction = _hasAction;
@synthesize alertAction = _alertAction;
@synthesize alertLaunchImage = _alertLaunchImage;
@synthesize soundName = _soundName;
@synthesize applicationIconBadgeNumber = _applicationIconBadgeNumber;
@synthesize userInfo = _userInfo;
@synthesize category = _category;
@synthesize regionTriggersOnce = _regionTriggersOnce;
@synthesize region = _region;

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)init
{
	if ((self = [super init])) {
		_hasAction = YES;
		_identifier = [[NSUUID UUID] UUIDString];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	UILocalNotification *copy = [[UILocalNotification alloc] init];
	copy->_identifier = _identifier;
	copy->_fireDate = _fireDate;
	copy->_timeZone = _timeZone;
	copy->_repeatInterval = _repeatInterval;
	copy->_repeatCalendar = _repeatCalendar;
	copy->_alertBody = _alertBody;
	copy->_alertTitle = _alertTitle;
	copy->_hasAction = _hasAction;
	copy->_alertAction = _alertAction;
	copy->_alertLaunchImage = _alertLaunchImage;
	copy->_soundName = _soundName;
	copy->_applicationIconBadgeNumber = _applicationIconBadgeNumber;
	copy->_userInfo = _userInfo;
	copy->_category = _category;
	return copy;
}

- (BOOL)isEqual:(id)object
{
	return [object isKindOfClass:[UILocalNotification class]] && [((UILocalNotification *)object)->_identifier isEqualToString:_identifier];
}

- (NSUInteger)hash { return [_identifier hash]; }

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_fireDate forKey:@"fireDate"];
	[coder encodeInteger:_repeatInterval forKey:@"repeatInterval"];
	[coder encodeObject:_alertBody forKey:@"alertBody"];
	[coder encodeObject:_alertTitle forKey:@"alertTitle"];
	[coder encodeObject:_soundName forKey:@"soundName"];
	[coder encodeInteger:_applicationIconBadgeNumber forKey:@"badge"];
	[coder encodeObject:_userInfo forKey:@"userInfo"];
	[coder encodeObject:_category forKey:@"category"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [self init])) {
		_identifier = [coder decodeObjectForKey:@"identifier"] ?: _identifier;
		_fireDate = [coder decodeObjectForKey:@"fireDate"];
		_repeatInterval = [coder decodeIntegerForKey:@"repeatInterval"];
		_alertBody = [coder decodeObjectForKey:@"alertBody"];
		_alertTitle = [coder decodeObjectForKey:@"alertTitle"];
		_soundName = [coder decodeObjectForKey:@"soundName"];
		_applicationIconBadgeNumber = [coder decodeIntegerForKey:@"badge"];
		_userInfo = [coder decodeObjectForKey:@"userInfo"];
		_category = [coder decodeObjectForKey:@"category"];
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<UILocalNotification: %p>{fire date = %@, alert body = %@, repeat interval = %lu}",
		self, _fireDate, _alertBody, (unsigned long)_repeatInterval];
}

@end

#pragma mark - As UserNotifications requests

/* UserNotifications is loaded only by apps that use local notifications. */
static BOOL UIKitLoadUserNotifications(void)
{
	static BOOL loaded;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		if (NSClassFromString(@"UNUserNotificationCenter") == Nil)
			dlopen("/System/Library/Frameworks/UserNotifications.framework/UserNotifications", RTLD_LAZY);
		loaded = NSClassFromString(@"UNUserNotificationCenter") != Nil;
		if (!loaded)
			NSLog(@"UIKit: UserNotifications is missing; local notifications are not delivered");
	});
	return loaded;
}

static UNUserNotificationCenter *UIKitNotificationCenter(void)
{
	return UIKitLoadUserNotifications() ? [NSClassFromString(@"UNUserNotificationCenter") currentNotificationCenter] : nil;
}

/* The units of the fire date that repeat every interval: the next ones up
   stay free. */
static NSCalendarUnit UIKitUnitsMatching(NSCalendarUnit interval)
{
	const NSCalendarUnit time = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
	switch (interval) {
	case NSCalendarUnitMinute: return NSCalendarUnitSecond;
	case NSCalendarUnitHour: return NSCalendarUnitMinute | NSCalendarUnitSecond;
	case NSCalendarUnitDay: return time;
	case NSCalendarUnitWeekday:
	case NSCalendarUnitWeekOfYear:
	case NSCalendarUnitWeekOfMonth: return NSCalendarUnitWeekday | time;
	case NSCalendarUnitMonth: return NSCalendarUnitDay | time;
	case NSCalendarUnitYear: return NSCalendarUnitMonth | NSCalendarUnitDay | time;
	default: return 0;
	}
}

static UNNotificationRequest *UIKitRequestFor(UILocalNotification *notification, BOOL now)
{
	UNMutableNotificationContent *content = [[NSClassFromString(@"UNMutableNotificationContent") alloc] init];
	[content setTitle:[notification alertTitle] ?: @""];
	[content setBody:[notification alertBody] ?: @""];
	if ([notification category] != nil)
		[content setCategoryIdentifier:[notification category]];
	if ([notification applicationIconBadgeNumber] != 0)
		[content setBadge:@([notification applicationIconBadgeNumber])];
	NSString *sound = [notification soundName];
	if (sound != nil) {
		Class soundClass = NSClassFromString(@"UNNotificationSound");
		[content setSound:[sound isEqualToString:UILocalNotificationDefaultSoundName] ? [soundClass defaultSound] : [soundClass soundNamed:sound]];
	}
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[notification userInfo] ?: @{}];
	userInfo[UIKitLocalNotificationKey] = notification->_identifier;
	[content setUserInfo:userInfo];

	UNNotificationTrigger *trigger = nil;
	NSDate *fireDate = [notification fireDate];
	NSCalendarUnit units = UIKitUnitsMatching([notification repeatInterval]);
	if (!now && fireDate != nil && units != 0) {
		NSCalendar *calendar = [notification repeatCalendar] ?: [NSCalendar currentCalendar];
		NSDateComponents *components = [calendar components:units fromDate:fireDate];
		trigger = [NSClassFromString(@"UNCalendarNotificationTrigger") triggerWithDateMatchingComponents:components repeats:YES];
	} else if (!now && fireDate != nil && [fireDate timeIntervalSinceNow] > 0) {
		trigger = [NSClassFromString(@"UNTimeIntervalNotificationTrigger") triggerWithTimeInterval:[fireDate timeIntervalSinceNow] repeats:NO];
	}
	return [NSClassFromString(@"UNNotificationRequest") requestWithIdentifier:notification->_identifier content:content trigger:trigger];
}

static UILocalNotification *UIKitNotificationFrom(UNNotificationRequest *request)
{
	UNNotificationContent *content = [request content];
	NSMutableDictionary *userInfo = [[content userInfo] mutableCopy];
	NSString *identifier = userInfo[UIKitLocalNotificationKey];
	[userInfo removeObjectForKey:UIKitLocalNotificationKey];
	UILocalNotification *notification = [[UILocalNotification alloc] init];
	notification->_identifier = identifier ?: [request identifier];
	[notification setAlertTitle:[[content title] length] > 0 ? [content title] : nil];
	[notification setAlertBody:[content body]];
	[notification setUserInfo:[userInfo count] > 0 ? userInfo : nil];
	[notification setCategory:[[content categoryIdentifier] length] > 0 ? [content categoryIdentifier] : nil];
	[notification setApplicationIconBadgeNumber:[[content badge] integerValue]];
	UNNotificationTrigger *trigger = [request trigger];
	if ([trigger respondsToSelector:@selector(nextTriggerDate)])
		[notification setFireDate:[(UNTimeIntervalNotificationTrigger *)trigger nextTriggerDate]];
	return notification;
}

@implementation UIApplication (UILocalNotifications)

- (void)scheduleLocalNotification:(UILocalNotification *)notification
{
	if (notification != nil)
		[UIKitNotificationCenter() addNotificationRequest:UIKitRequestFor(notification, NO) withCompletionHandler:nil];
}

- (void)presentLocalNotificationNow:(UILocalNotification *)notification
{
	if (notification != nil)
		[UIKitNotificationCenter() addNotificationRequest:UIKitRequestFor(notification, YES) withCompletionHandler:nil];
}

- (void)cancelLocalNotification:(UILocalNotification *)notification
{
	if (notification != nil)
		[UIKitNotificationCenter() removePendingNotificationRequestsWithIdentifiers:@[ notification->_identifier ]];
}

- (void)cancelAllLocalNotifications
{
	[UIKitNotificationCenter() removeAllPendingNotificationRequests];
}

/* The daemon answers on UserNotifications' own queue, never this one. */
- (NSArray<UILocalNotification *> *)scheduledLocalNotifications
{
	UNUserNotificationCenter *center = UIKitNotificationCenter();
	if (center == nil)
		return @[];
	__block NSArray *requests = nil;
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	[center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *pending) {
		requests = pending;
		dispatch_semaphore_signal(done);
	}];
	dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
	NSMutableArray *notifications = [NSMutableArray array];
	for (UNNotificationRequest *request in requests)
		[notifications addObject:UIKitNotificationFrom(request)];
	return notifications;
}

- (void)setScheduledLocalNotifications:(NSArray<UILocalNotification *> *)notifications
{
	[self cancelAllLocalNotifications];
	for (UILocalNotification *notification in notifications)
		[self scheduleLocalNotification:notification];
}

@end

#pragma mark - Delivery to the app delegate

@interface UIKitLocalNotificationForwarder : NSObject <UNUserNotificationCenterDelegate>
@end

@implementation UIKitLocalNotificationForwarder

- (void)uikitDeliver:(UNNotification *)notification
{
	UIApplication *application = [UIApplication sharedApplication];
	id<UIApplicationDelegate> delegate = [application delegate];
	if ([delegate respondsToSelector:@selector(application:didReceiveLocalNotification:)])
		[delegate application:application didReceiveLocalNotification:UIKitNotificationFrom([notification request])];
}

/* In front: the app hears of it, and nothing is shown, as on iOS 4. */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
	[self uikitDeliver:notification];
	completionHandler(UNNotificationPresentationOptionNone);
}

/* Opened from the banner. */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler
{
	[self uikitDeliver:[response notification]];
	completionHandler();
}

@end

void UIKitForwardLocalNotifications(UIApplication *application)
{
	static UIKitLocalNotificationForwarder *forwarder;
	if (![[application delegate] respondsToSelector:@selector(application:didReceiveLocalNotification:)])
		return;
	UNUserNotificationCenter *center = UIKitNotificationCenter();
	if (center == nil || [center delegate] != nil)
		return;
	forwarder = [[UIKitLocalNotificationForwarder alloc] init];
	[center setDelegate:forwarder];
}
