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

/* The public UserNotifications classes, and the notification center that
   hands requests to usernotificationsd (the protocol is in UNLite.h). */

#import <UserNotifications/UserNotifications.h>
#import "UNLite.h"
#include <pthread.h>
#include <unistd.h>

NSString * const UNErrorDomain = @"UNErrorDomain";
NSString * const UNNotificationDefaultActionIdentifier = @"com.apple.UNNotificationDefaultActionIdentifier";
NSString * const UNNotificationDismissActionIdentifier = @"com.apple.UNNotificationDismissActionIdentifier";

@interface UNNotificationContent ()
- (void) un_copyInto: (UNNotificationContent *) copy;
@end

@interface UNNotificationTrigger ()
- (instancetype) initUNRepeating: (BOOL) repeats;
@end

@interface UNNotificationSettings ()
- (instancetype) initUN;
@end

static BOOL UNEqual(id a, id b)
{
	return a == b || [a isEqual:b];
}

#pragma mark - UNNotificationSound

@implementation UNNotificationSound {
	NSString *_name;
	BOOL _critical;
	float _audioVolume;
}

+ (BOOL) supportsSecureCoding { return YES; }

+ (instancetype) un_soundNamed: (NSString *) name critical: (BOOL) critical volume: (float) volume
{
	UNNotificationSound *sound = [[self alloc] initUN];
	sound->_name = [name copy];
	sound->_critical = critical;
	sound->_audioVolume = volume;
	return sound;
}

- (instancetype) initUN { return [super init]; }

+ (UNNotificationSound *) defaultSound { return [self un_soundNamed:nil critical:NO volume:1]; }
+ (UNNotificationSound *) defaultCriticalSound { return [self un_soundNamed:nil critical:YES volume:1]; }
+ (instancetype) soundNamed: (NSString *) name { return [self un_soundNamed:name critical:NO volume:1]; }
+ (instancetype) criticalSoundNamed: (NSString *) name { return [self un_soundNamed:name critical:YES volume:1]; }
+ (instancetype) criticalSoundNamed: (NSString *) name withAudioVolume: (float) volume { return [self un_soundNamed:name critical:YES volume:volume]; }
+ (instancetype) defaultCriticalSoundWithAudioVolume: (float) volume { return [self un_soundNamed:nil critical:YES volume:volume]; }

- (NSString *) name { return _name; }
- (BOOL) isCritical { return _critical; }
- (float) audioVolume { return _audioVolume; }

- (id) copyWithZone: (NSZone *) zone { return self; }

- (BOOL) isEqual: (id) other
{
	if (![other isKindOfClass:[UNNotificationSound class]])
		return NO;
	UNNotificationSound *sound = other;
	return UNEqual(_name, sound->_name) && _critical == sound->_critical && _audioVolume == sound->_audioVolume;
}

- (NSUInteger) hash { return [_name hash] ^ _critical; }

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeObject:_name forKey:@"name"];
	[coder encodeBool:_critical forKey:@"critical"];
	[coder encodeFloat:_audioVolume forKey:@"audioVolume"];
}

- (instancetype) initWithCoder: (NSCoder *) coder
{
	if ((self = [super init])) {
		_name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
		_critical = [coder decodeBoolForKey:@"critical"];
		_audioVolume = [coder decodeFloatForKey:@"audioVolume"];
	}
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"<%@: %p name: %@, critical: %d>", [self class], self, _name ?: @"(default)", _critical];
}

@end

#pragma mark - UNNotificationContent

@implementation UNNotificationContent

+ (BOOL) supportsSecureCoding { return YES; }

- (instancetype) init
{
	if ((self = [super init])) {
		_attachments = @[];
		_body = @"";
		_categoryIdentifier = @"";
		_launchImageName = @"";
		_subtitle = @"";
		_threadIdentifier = @"";
		_title = @"";
		_userInfo = @{};
		_summaryArgument = @"";
		_interruptionLevel = UNNotificationInterruptionLevelActive;
	}
	return self;
}

- (NSArray *) attachments { return _attachments; }
- (NSNumber *) badge { return _badge; }
- (NSString *) body { return _body; }
- (NSString *) categoryIdentifier { return _categoryIdentifier; }
- (NSString *) launchImageName { return _launchImageName; }
- (UNNotificationSound *) sound { return _sound; }
- (NSString *) subtitle { return _subtitle; }
- (NSString *) threadIdentifier { return _threadIdentifier; }
- (NSString *) title { return _title; }
- (NSDictionary *) userInfo { return _userInfo; }
- (NSString *) summaryArgument { return _summaryArgument; }
- (NSUInteger) summaryArgumentCount { return _summaryArgumentCount; }
- (NSString *) targetContentIdentifier { return _targetContentIdentifier; }
- (UNNotificationInterruptionLevel) interruptionLevel { return _interruptionLevel; }
- (double) relevanceScore { return _relevanceScore; }

- (void) un_copyInto: (UNNotificationContent *) copy
{
	copy->_attachments = [_attachments copy];
	copy->_badge = [_badge copy];
	copy->_body = [_body copy];
	copy->_categoryIdentifier = [_categoryIdentifier copy];
	copy->_launchImageName = [_launchImageName copy];
	copy->_sound = [_sound copy];
	copy->_subtitle = [_subtitle copy];
	copy->_threadIdentifier = [_threadIdentifier copy];
	copy->_title = [_title copy];
	copy->_userInfo = [_userInfo copy];
	copy->_summaryArgument = [_summaryArgument copy];
	copy->_summaryArgumentCount = _summaryArgumentCount;
	copy->_targetContentIdentifier = [_targetContentIdentifier copy];
	copy->_interruptionLevel = _interruptionLevel;
	copy->_relevanceScore = _relevanceScore;
}

- (id) copyWithZone: (NSZone *) zone
{
	if ([self class] == [UNNotificationContent class])
		return self;
	UNNotificationContent *copy = [[UNNotificationContent alloc] init];
	[self un_copyInto:copy];
	return copy;
}

- (id) mutableCopyWithZone: (NSZone *) zone
{
	UNMutableNotificationContent *copy = [[UNMutableNotificationContent alloc] init];
	[self un_copyInto:copy];
	return copy;
}

- (BOOL) isEqual: (id) other
{
	if (![other isKindOfClass:[UNNotificationContent class]])
		return NO;
	UNNotificationContent *content = other;
	return UNEqual(_title, content->_title) && UNEqual(_subtitle, content->_subtitle) && UNEqual(_body, content->_body)
		&& UNEqual(_badge, content->_badge) && UNEqual(_sound, content->_sound) && UNEqual(_userInfo, content->_userInfo)
		&& UNEqual(_categoryIdentifier, content->_categoryIdentifier) && UNEqual(_threadIdentifier, content->_threadIdentifier);
}

- (NSUInteger) hash { return [_title hash] ^ [_body hash]; }

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeObject:_attachments forKey:@"attachments"];
	[coder encodeObject:_badge forKey:@"badge"];
	[coder encodeObject:_body forKey:@"body"];
	[coder encodeObject:_categoryIdentifier forKey:@"categoryIdentifier"];
	[coder encodeObject:_launchImageName forKey:@"launchImageName"];
	[coder encodeObject:_sound forKey:@"sound"];
	[coder encodeObject:_subtitle forKey:@"subtitle"];
	[coder encodeObject:_threadIdentifier forKey:@"threadIdentifier"];
	[coder encodeObject:_title forKey:@"title"];
	[coder encodeObject:_userInfo forKey:@"userInfo"];
	[coder encodeObject:_summaryArgument forKey:@"summaryArgument"];
	[coder encodeInteger:_summaryArgumentCount forKey:@"summaryArgumentCount"];
	[coder encodeObject:_targetContentIdentifier forKey:@"targetContentIdentifier"];
	[coder encodeInteger:_interruptionLevel forKey:@"interruptionLevel"];
	[coder encodeDouble:_relevanceScore forKey:@"relevanceScore"];
}

- (instancetype) initWithCoder: (NSCoder *) coder
{
	if ((self = [self init])) {
		NSSet *plist = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSDate class], [NSData class], nil];
		_attachments = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSObject class], nil] forKey:@"attachments"] ?: @[];
		_badge = [coder decodeObjectOfClass:[NSNumber class] forKey:@"badge"];
		_body = [coder decodeObjectOfClass:[NSString class] forKey:@"body"] ?: @"";
		_categoryIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"categoryIdentifier"] ?: @"";
		_launchImageName = [coder decodeObjectOfClass:[NSString class] forKey:@"launchImageName"] ?: @"";
		_sound = [coder decodeObjectOfClass:[UNNotificationSound class] forKey:@"sound"];
		_subtitle = [coder decodeObjectOfClass:[NSString class] forKey:@"subtitle"] ?: @"";
		_threadIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"threadIdentifier"] ?: @"";
		_title = [coder decodeObjectOfClass:[NSString class] forKey:@"title"] ?: @"";
		_userInfo = [coder decodeObjectOfClasses:plist forKey:@"userInfo"] ?: @{};
		_summaryArgument = [coder decodeObjectOfClass:[NSString class] forKey:@"summaryArgument"] ?: @"";
		_summaryArgumentCount = [coder decodeIntegerForKey:@"summaryArgumentCount"];
		_targetContentIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"targetContentIdentifier"];
		_interruptionLevel = [coder decodeIntegerForKey:@"interruptionLevel"];
		_relevanceScore = [coder decodeDoubleForKey:@"relevanceScore"];
	}
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"<%@: %p title: \"%@\", subtitle: \"%@\", body: \"%@\", categoryIdentifier: %@, sound: %@, badge: %@>",
		[self class], self, _title, _subtitle, _body, _categoryIdentifier, _sound, _badge];
}

@end

@implementation UNMutableNotificationContent

@dynamic attachments, badge, body, categoryIdentifier, launchImageName, sound, subtitle, threadIdentifier, title, userInfo,
	summaryArgument, summaryArgumentCount, targetContentIdentifier, interruptionLevel, relevanceScore;

- (id) copyWithZone: (NSZone *) zone
{
	UNNotificationContent *copy = [[UNNotificationContent alloc] init];
	[self un_copyInto:copy];
	return copy;
}

- (void) setAttachments: (NSArray *) attachments { _attachments = [attachments copy] ?: @[]; }
- (void) setBadge: (NSNumber *) badge { _badge = [badge copy]; }
- (void) setBody: (NSString *) body { _body = [body copy] ?: @""; }
- (void) setCategoryIdentifier: (NSString *) identifier { _categoryIdentifier = [identifier copy] ?: @""; }
- (void) setLaunchImageName: (NSString *) name { _launchImageName = [name copy] ?: @""; }
- (void) setSound: (UNNotificationSound *) sound { _sound = [sound copy]; }
- (void) setSubtitle: (NSString *) subtitle { _subtitle = [subtitle copy] ?: @""; }
- (void) setThreadIdentifier: (NSString *) identifier { _threadIdentifier = [identifier copy] ?: @""; }
- (void) setTitle: (NSString *) title { _title = [title copy] ?: @""; }
- (void) setUserInfo: (NSDictionary *) userInfo { _userInfo = [userInfo copy] ?: @{}; }
- (void) setSummaryArgument: (NSString *) argument { _summaryArgument = [argument copy] ?: @""; }
- (void) setSummaryArgumentCount: (NSUInteger) count { _summaryArgumentCount = count; }
- (void) setTargetContentIdentifier: (NSString *) identifier { _targetContentIdentifier = [identifier copy]; }
- (void) setInterruptionLevel: (UNNotificationInterruptionLevel) level { _interruptionLevel = level; }
- (void) setRelevanceScore: (double) score { _relevanceScore = score; }

@end

#pragma mark - Triggers

@implementation UNNotificationTrigger

+ (BOOL) supportsSecureCoding { return YES; }

- (instancetype) initUNRepeating: (BOOL) repeats
{
	if ((self = [super init]))
		_repeats = repeats;
	return self;
}

- (BOOL) repeats { return _repeats; }
- (id) copyWithZone: (NSZone *) zone { return self; }

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeBool:_repeats forKey:@"repeats"];
}

- (instancetype) initWithCoder: (NSCoder *) coder
{
	if ((self = [super init]))
		_repeats = [coder decodeBoolForKey:@"repeats"];
	return self;
}

@end

@implementation UNTimeIntervalNotificationTrigger {
	NSTimeInterval _timeInterval;
	NSDate *_fireDate;
}

/* Its own initWithCoder: needs its own claim to secure coding. */
+ (BOOL) supportsSecureCoding { return YES; }

+ (instancetype) un_triggerWithTimeInterval: (NSTimeInterval) interval repeats: (BOOL) repeats fireDate: (NSDate *) fireDate
{
	UNTimeIntervalNotificationTrigger *trigger = [[self alloc] initUNRepeating:repeats];
	trigger->_timeInterval = interval;
	trigger->_fireDate = fireDate;
	return trigger;
}

+ (instancetype) triggerWithTimeInterval: (NSTimeInterval) interval repeats: (BOOL) repeats
{
	if (!(interval > 0))
		[NSException raise:NSInternalInconsistencyException format:@"time interval must be greater than 0"];
	if (repeats && interval < 60)
		[NSException raise:NSInternalInconsistencyException format:@"time interval must be at least 60 if repeating"];
	return [self un_triggerWithTimeInterval:interval repeats:repeats fireDate:[NSDate dateWithTimeIntervalSinceNow:interval]];
}

- (NSTimeInterval) timeInterval { return _timeInterval; }
- (NSDate *) un_fireDate { return _fireDate; }

- (NSDate *) nextTriggerDate
{
	return UNLiteNextFireDate(@{ @"type": @"interval", @"interval": @(_timeInterval), @"repeats": @(_repeats), @"fireDate": _fireDate }, [NSDate date]);
}

- (BOOL) isEqual: (id) other
{
	return [other isKindOfClass:[UNTimeIntervalNotificationTrigger class]]
		&& ((UNTimeIntervalNotificationTrigger *)other)->_timeInterval == _timeInterval
		&& ((UNTimeIntervalNotificationTrigger *)other)->_repeats == _repeats;
}

- (NSUInteger) hash { return (NSUInteger)_timeInterval; }

- (void) encodeWithCoder: (NSCoder *) coder
{
	[super encodeWithCoder:coder];
	[coder encodeDouble:_timeInterval forKey:@"timeInterval"];
	[coder encodeObject:_fireDate forKey:@"fireDate"];
}

- (instancetype) initWithCoder: (NSCoder *) coder
{
	if ((self = [super initWithCoder:coder])) {
		_timeInterval = [coder decodeDoubleForKey:@"timeInterval"];
		_fireDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"fireDate"];
	}
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"<%@: %p timeInterval: %g, repeats: %d>", [self class], self, _timeInterval, _repeats];
}

@end

@implementation UNCalendarNotificationTrigger {
	NSDateComponents *_dateComponents;
}

/* Its own initWithCoder: needs its own claim to secure coding. */
+ (BOOL) supportsSecureCoding { return YES; }

+ (instancetype) triggerWithDateMatchingComponents: (NSDateComponents *) components repeats: (BOOL) repeats
{
	UNCalendarNotificationTrigger *trigger = [[self alloc] initUNRepeating:repeats];
	trigger->_dateComponents = [components copy];
	return trigger;
}

- (NSDateComponents *) dateComponents { return _dateComponents; }

- (NSDate *) nextTriggerDate
{
	return UNLiteNextDateMatching(_dateComponents, [NSDate date]);
}

- (BOOL) isEqual: (id) other
{
	return [other isKindOfClass:[UNCalendarNotificationTrigger class]]
		&& UNEqual(((UNCalendarNotificationTrigger *)other)->_dateComponents, _dateComponents)
		&& ((UNCalendarNotificationTrigger *)other)->_repeats == _repeats;
}

- (NSUInteger) hash { return [_dateComponents hash]; }

- (void) encodeWithCoder: (NSCoder *) coder
{
	[super encodeWithCoder:coder];
	[coder encodeObject:_dateComponents forKey:@"dateComponents"];
}

- (instancetype) initWithCoder: (NSCoder *) coder
{
	if ((self = [super initWithCoder:coder]))
		_dateComponents = [coder decodeObjectOfClass:[NSDateComponents class] forKey:@"dateComponents"];
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"<%@: %p dateComponents: %@, repeats: %d>", [self class], self, _dateComponents, _repeats];
}

@end

#pragma mark - Requests and notifications

@implementation UNNotificationRequest {
	NSString *_identifier;
	UNNotificationContent *_content;
	UNNotificationTrigger *_trigger;
}

+ (BOOL) supportsSecureCoding { return YES; }

+ (instancetype) requestWithIdentifier: (NSString *) identifier content: (UNNotificationContent *) content trigger: (UNNotificationTrigger *) trigger
{
	if (identifier == nil || content == nil)
		[NSException raise:NSInvalidArgumentException format:@"a notification request needs an identifier and content"];
	UNNotificationRequest *request = [[self alloc] initUN];
	request->_identifier = [identifier copy];
	request->_content = [content copy];
	request->_trigger = [trigger copy];
	return request;
}

- (instancetype) initUN { return [super init]; }

- (NSString *) identifier { return _identifier; }
- (UNNotificationContent *) content { return _content; }
- (UNNotificationTrigger *) trigger { return _trigger; }
- (id) copyWithZone: (NSZone *) zone { return self; }

- (BOOL) isEqual: (id) other
{
	if (![other isKindOfClass:[UNNotificationRequest class]])
		return NO;
	UNNotificationRequest *request = other;
	return UNEqual(_identifier, request->_identifier) && UNEqual(_content, request->_content) && UNEqual(_trigger, request->_trigger);
}

- (NSUInteger) hash { return [_identifier hash]; }

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_content forKey:@"content"];
	[coder encodeObject:_trigger forKey:@"trigger"];
}

- (instancetype) initWithCoder: (NSCoder *) coder
{
	if ((self = [super init])) {
		_identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
		_content = [coder decodeObjectOfClass:[UNNotificationContent class] forKey:@"content"];
		_trigger = [coder decodeObjectOfClasses:[NSSet setWithObjects:[UNTimeIntervalNotificationTrigger class], [UNCalendarNotificationTrigger class], nil] forKey:@"trigger"];
	}
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"<%@: %p identifier: %@, content: %@, trigger: %@>", [self class], self, _identifier, _content, _trigger];
}

@end

@implementation UNNotification {
	NSDate *_date;
	UNNotificationRequest *_request;
}

+ (BOOL) supportsSecureCoding { return YES; }

+ (instancetype) un_notificationWithRequest: (UNNotificationRequest *) request date: (NSDate *) date
{
	UNNotification *notification = [[self alloc] initUN];
	notification->_request = request;
	notification->_date = [date copy];
	return notification;
}

- (instancetype) initUN { return [super init]; }

- (NSDate *) date { return _date; }
- (UNNotificationRequest *) request { return _request; }
- (id) copyWithZone: (NSZone *) zone { return self; }

- (BOOL) isEqual: (id) other
{
	return [other isKindOfClass:[UNNotification class]] && UNEqual(_date, ((UNNotification *)other)->_date)
		&& UNEqual(_request, ((UNNotification *)other)->_request);
}

- (NSUInteger) hash { return [_request hash]; }

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeObject:_date forKey:@"date"];
	[coder encodeObject:_request forKey:@"request"];
}

- (instancetype) initWithCoder: (NSCoder *) coder
{
	if ((self = [super init])) {
		_date = [coder decodeObjectOfClass:[NSDate class] forKey:@"date"];
		_request = [coder decodeObjectOfClass:[UNNotificationRequest class] forKey:@"request"];
	}
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"<%@: %p date: %@, request: %@>", [self class], self, _date, _request];
}

@end

@implementation UNNotificationResponse {
	UNNotification *_notification;
	NSString *_actionIdentifier;
}

+ (BOOL) supportsSecureCoding { return YES; }

+ (instancetype) un_responseWithNotification: (UNNotification *) notification actionIdentifier: (NSString *) actionIdentifier
{
	UNNotificationResponse *response = [[self alloc] initUN];
	response->_notification = notification;
	response->_actionIdentifier = [actionIdentifier copy];
	return response;
}

- (instancetype) initUN { return [super init]; }

- (UNNotification *) notification { return _notification; }
- (NSString *) actionIdentifier { return _actionIdentifier; }
- (id) copyWithZone: (NSZone *) zone { return self; }

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeObject:_notification forKey:@"notification"];
	[coder encodeObject:_actionIdentifier forKey:@"actionIdentifier"];
}

- (instancetype) initWithCoder: (NSCoder *) coder
{
	if ((self = [super init])) {
		_notification = [coder decodeObjectOfClass:[UNNotification class] forKey:@"notification"];
		_actionIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"actionIdentifier"];
	}
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"<%@: %p actionIdentifier: %@, notification: %@>", [self class], self, _actionIdentifier, _notification];
}

@end

#pragma mark - UNNotificationSettings

/* Darling asks no one: every app may notify, in every way. */
@implementation UNNotificationSettings

+ (BOOL) supportsSecureCoding { return YES; }

- (instancetype) initUN { return [super init]; }

- (UNAuthorizationStatus) authorizationStatus { return UNAuthorizationStatusAuthorized; }
- (UNNotificationSetting) soundSetting { return UNNotificationSettingEnabled; }
- (UNNotificationSetting) badgeSetting { return UNNotificationSettingEnabled; }
- (UNNotificationSetting) alertSetting { return UNNotificationSettingEnabled; }
- (UNNotificationSetting) notificationCenterSetting { return UNNotificationSettingEnabled; }
- (UNNotificationSetting) lockScreenSetting { return UNNotificationSettingEnabled; }
- (UNNotificationSetting) carPlaySetting { return UNNotificationSettingNotSupported; }
- (UNNotificationSetting) criticalAlertSetting { return UNNotificationSettingEnabled; }
- (UNNotificationSetting) announcementSetting { return UNNotificationSettingNotSupported; }
- (UNNotificationSetting) timeSensitiveSetting { return UNNotificationSettingEnabled; }
- (UNNotificationSetting) scheduledDeliverySetting { return UNNotificationSettingDisabled; }
- (UNNotificationSetting) directMessagesSetting { return UNNotificationSettingNotSupported; }
- (UNAlertStyle) alertStyle { return UNAlertStyleBanner; }
- (UNShowPreviewsSetting) showPreviewsSetting { return UNShowPreviewsSettingAlways; }
- (BOOL) providesAppNotificationSettings { return NO; }

- (id) copyWithZone: (NSZone *) zone { return self; }
- (void) encodeWithCoder: (NSCoder *) coder { }
- (instancetype) initWithCoder: (NSCoder *) coder { return [super init]; }

@end

#pragma mark - UNUserNotificationCenter

@interface UNNotificationResponse (UNLite)
+ (instancetype) un_responseWithNotification: (UNNotification *) notification actionIdentifier: (NSString *) actionIdentifier;
@end

static void *UNThreadMain(void *block)
{
	void (^work)(void) = (__bridge_transfer void (^)(void))block;
	work();
	return NULL;
}

static void UNDetach(void (^work)(void))
{
	pthread_t thread;
	pthread_attr_t attributes;
	pthread_attr_init(&attributes);
	pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
	pthread_create(&thread, &attributes, UNThreadMain, (__bridge_retained void *)[work copy]);
	pthread_attr_destroy(&attributes);
}

@implementation UNUserNotificationCenter {
	NSString *_bundleIdentifier;
	dispatch_queue_t _queue;
	__weak id<UNUserNotificationCenterDelegate> _delegate;
	BOOL _checkingIn;
	NSSet *_categories;
}

+ (UNUserNotificationCenter *) currentNotificationCenter
{
	static UNUserNotificationCenter *center;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		center = [[self alloc] initUN];
	});
	return center;
}

- (instancetype) initUN
{
	if ((self = [super init])) {
		_bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier] ?: [[NSProcessInfo processInfo] processName];
		_queue = dispatch_queue_create("com.apple.usernotifications.UNUserNotificationCenter", DISPATCH_QUEUE_SERIAL);
	}
	return self;
}

- (BOOL) supportsContentExtensions { return NO; }

- (id<UNUserNotificationCenterDelegate>) delegate
{
	@synchronized (self) {
		return _delegate;
	}
}

/* With a delegate the app hears about its notifications, so it checks in
   with the daemon then: from that connection come the notifications that
   arrive while it is in front, and what the user did with others. */
- (void) setDelegate: (id<UNUserNotificationCenterDelegate>) delegate
{
	@synchronized (self) {
		_delegate = delegate;
		if (delegate == nil || _checkingIn)
			return;
		_checkingIn = YES;
	}
	UNDetach(^{
		[self un_serveEvents];
	});
}

- (NSDictionary *) un_request: (NSString *) op with: (NSDictionary *) arguments
{
	NSMutableDictionary *message = [NSMutableDictionary dictionaryWithDictionary:arguments ?: @{}];
	message[@"op"] = op;
	message[@"bundleIdentifier"] = _bundleIdentifier;
	return UNLiteRequest(message);
}

static NSError *UNDaemonError(NSDictionary *reply)
{
	if (reply == nil)
		return [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeNotificationsNotAllowed
		                       userInfo:@{ NSLocalizedDescriptionKey: @"Notifications are not available: usernotificationsd is not running." }];
	if (reply[@"error"] != nil)
		return [NSError errorWithDomain:UNErrorDomain code:[reply[@"code"] integerValue] ?: UNErrorCodeNotificationInvalidNoContent
		                       userInfo:@{ NSLocalizedDescriptionKey: reply[@"error"] }];
	return nil;
}

- (void) requestAuthorizationWithOptions: (UNAuthorizationOptions) options completionHandler: (void (^)(BOOL granted, NSError *error)) completionHandler
{
	if (completionHandler != nil)
		dispatch_async(_queue, ^{
			completionHandler(YES, nil);
		});
}

- (void) getNotificationSettingsWithCompletionHandler: (void (^)(UNNotificationSettings *settings)) completionHandler
{
	if (completionHandler != nil)
		dispatch_async(_queue, ^{
			completionHandler([[UNNotificationSettings alloc] initUN]);
		});
}

- (void) addNotificationRequest: (UNNotificationRequest *) request withCompletionHandler: (void (^)(NSError *error)) completionHandler
{
	NSDictionary *wire = UNLiteWireRequest(request);
	dispatch_async(_queue, ^{
		NSError *error = UNDaemonError([self un_request:@"add" with:@{ @"request": wire }]);
		if (error != nil)
			NSLog(@"UserNotifications: cannot add %@: %@", request.identifier, [error localizedDescription]);
		if (completionHandler != nil)
			completionHandler(error);
	});
}

- (void) getPendingNotificationRequestsWithCompletionHandler: (void (^)(NSArray<UNNotificationRequest *> *requests)) completionHandler
{
	dispatch_async(_queue, ^{
		NSMutableArray *requests = [NSMutableArray array];
		for (NSDictionary *wire in [self un_request:@"pending" with:nil][@"requests"]) {
			UNNotificationRequest *request = UNLiteRequestFromWire(wire);
			if (request != nil)
				[requests addObject:request];
		}
		completionHandler(requests);
	});
}

- (void) un_send: (NSString *) op identifiers: (NSArray<NSString *> *) identifiers
{
	NSDictionary *arguments = identifiers != nil ? @{ @"identifiers": [identifiers copy] } : nil;
	dispatch_async(_queue, ^{
		[self un_request:op with:arguments];
	});
}

- (void) removePendingNotificationRequestsWithIdentifiers: (NSArray<NSString *> *) identifiers
{
	[self un_send:@"removePending" identifiers:identifiers ?: @[]];
}

- (void) removeAllPendingNotificationRequests
{
	[self un_send:@"removePending" identifiers:nil];
}

- (void) getDeliveredNotificationsWithCompletionHandler: (void (^)(NSArray<UNNotification *> *notifications)) completionHandler
{
	dispatch_async(_queue, ^{
		NSMutableArray *notifications = [NSMutableArray array];
		for (NSDictionary *wire in [self un_request:@"delivered" with:nil][@"notifications"]) {
			UNNotification *notification = UNLiteNotificationFromWire(wire);
			if (notification != nil)
				[notifications addObject:notification];
		}
		completionHandler(notifications);
	});
}

- (void) removeDeliveredNotificationsWithIdentifiers: (NSArray<NSString *> *) identifiers
{
	[self un_send:@"removeDelivered" identifiers:identifiers ?: @[]];
}

- (void) removeAllDeliveredNotifications
{
	[self un_send:@"removeDelivered" identifiers:nil];
}

- (void) setNotificationCategories: (NSSet<UNNotificationCategory *> *) categories
{
	NSMutableArray *wire = [NSMutableArray array];
	for (UNNotificationCategory *category in categories)
		[wire addObject:UNLiteWireCategory(category)];
	@synchronized (self) {
		_categories = [categories copy];
	}
	dispatch_async(_queue, ^{
		[self un_request:@"setCategories" with:@{ @"categories": wire }];
	});
}

- (void) getNotificationCategoriesWithCompletionHandler: (void (^)(NSSet<UNNotificationCategory *> *categories)) completionHandler
{
	dispatch_async(_queue, ^{
		NSMutableSet *categories = [NSMutableSet set];
		NSDictionary *reply = [self un_request:@"categories" with:nil];
		if (reply == nil) {
			@synchronized (self) {
				[categories unionSet:self->_categories ?: [NSSet set]];
			}
		}
		for (NSDictionary *wire in reply[@"categories"]) {
			UNNotificationCategory *category = UNLiteCategoryFromWire(wire);
			if (category != nil)
				[categories addObject:category];
		}
		completionHandler(categories);
	});
}

- (void) setBadgeCount: (NSInteger) count withCompletionHandler: (void (^)(NSError *error)) completionHandler
{
	if (completionHandler != nil)
		dispatch_async(_queue, ^{
			completionHandler(nil);
		});
}

#pragma mark Events

/* The check-in connection, on a thread of its own: it waits for the
   daemon's events for as long as the app runs, reconnecting if the daemon
   restarts. */
- (void) un_serveEvents
{
	unsigned int wait = 1;
	for (;;) {
		@autoreleasepool {
			int fd = UNLiteConnect();
			if (fd >= 0 && UNLiteSend(fd, @{ @"op": @"checkin", @"bundleIdentifier": _bundleIdentifier, @"pid": @(getpid()) })) {
				wait = 1;
				NSDictionary *event;
				while ((event = UNLiteReceive(fd)) != nil) {
					@autoreleasepool {
						[self un_handleEvent:event fd:fd];
					}
				}
			}
			if (fd >= 0)
				close(fd);
		}
		sleep(wait);
		wait = MIN(wait * 2, 30u);
	}
}

- (void) un_handleEvent: (NSDictionary *) event fd: (int) fd
{
	NSString *op = event[@"op"];
	UNNotification *notification = UNLiteNotificationFromWire(event[@"notification"]);
	if (notification == nil)
		return;

	if ([op isEqualToString:@"present"]) {
		id token = event[@"token"] ?: @0;
		dispatch_async(dispatch_get_main_queue(), ^{
			id<UNUserNotificationCenterDelegate> delegate = self.delegate;
			__block BOOL answered = NO;
			void (^answer)(UNNotificationPresentationOptions) = ^(UNNotificationPresentationOptions options) {
				if (answered)
					return;
				answered = YES;
				UNLiteSend(fd, @{ @"op": @"presentOptions", @"token": token, @"options": @(options) });
			};
			if ([delegate respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)])
				[delegate userNotificationCenter:self willPresentNotification:notification withCompletionHandler:answer];
			else
				answer(UNNotificationPresentationOptionNone);
		});
	} else if ([op isEqualToString:@"response"]) {
		UNNotificationResponse *response = [UNNotificationResponse un_responseWithNotification:notification actionIdentifier:event[@"action"] ?: UNNotificationDefaultActionIdentifier];
		dispatch_async(dispatch_get_main_queue(), ^{
			id<UNUserNotificationCenterDelegate> delegate = self.delegate;
			if ([delegate respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)])
				[delegate userNotificationCenter:self didReceiveNotificationResponse:response withCompletionHandler:^{}];
		});
	}
}

@end
