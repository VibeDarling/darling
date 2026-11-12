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

#import "UNLite.h"
#import <UserNotifications/UserNotifications.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>

NSString *UNLiteSocketPath(void)
{
	const char *path = getenv("USERNOTIFICATIONS_SOCKET");
	return path != NULL ? [NSString stringWithUTF8String:path] : @"/private/var/run/usernotificationsd.sock";
}

static BOOL UNLiteAddress(struct sockaddr_un *address)
{
	const char *path = [UNLiteSocketPath() fileSystemRepresentation];
	memset(address, 0, sizeof(*address));
	address->sun_family = AF_UNIX;
	if (strlen(path) >= sizeof(address->sun_path))
		return NO;
	strcpy(address->sun_path, path);
	return YES;
}

int UNLiteConnect(void)
{
	struct sockaddr_un address;
	if (!UNLiteAddress(&address))
		return -1;
	int fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd < 0)
		return -1;
	if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
		close(fd);
		return -1;
	}
	fcntl(fd, F_SETFD, FD_CLOEXEC);
	return fd;
}

int UNLiteListen(void)
{
	struct sockaddr_un address;
	if (!UNLiteAddress(&address))
		return -1;
	int fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd < 0)
		return -1;
	unlink(address.sun_path);
	if (bind(fd, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(fd, 16) != 0) {
		close(fd);
		return -1;
	}
	fcntl(fd, F_SETFD, FD_CLOEXEC);
	return fd;
}

static BOOL UNLiteWriteAll(int fd, const void *buffer, size_t length)
{
	const char *bytes = buffer;
	while (length > 0) {
		ssize_t written = write(fd, bytes, length);
		if (written < 0 && errno == EINTR)
			continue;
		if (written <= 0)
			return NO;
		bytes += written;
		length -= written;
	}
	return YES;
}

static BOOL UNLiteReadAll(int fd, void *buffer, size_t length)
{
	char *bytes = buffer;
	while (length > 0) {
		ssize_t got = read(fd, bytes, length);
		if (got < 0 && errno == EINTR)
			continue;
		if (got <= 0)
			return NO;
		bytes += got;
		length -= got;
	}
	return YES;
}

BOOL UNLiteSend(int fd, NSDictionary *message)
{
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:message format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
	if (data == nil)
		return NO;
	/* One write, so that messages sent from two threads do not interleave. */
	NSMutableData *framed = [NSMutableData dataWithCapacity:[data length] + 4];
	uint32_t length = htonl((uint32_t)[data length]);
	[framed appendBytes:&length length:sizeof(length)];
	[framed appendData:data];
	return UNLiteWriteAll(fd, [framed bytes], [framed length]);
}

NSDictionary *UNLiteReceive(int fd)
{
	uint32_t length;
	if (!UNLiteReadAll(fd, &length, sizeof(length)))
		return nil;
	length = ntohl(length);
	if (length > (16 << 20))
		return nil;
	NSMutableData *data = [NSMutableData dataWithLength:length];
	if (!UNLiteReadAll(fd, [data mutableBytes], length))
		return nil;
	id message = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
	return [message isKindOfClass:[NSDictionary class]] ? message : nil;
}

NSDictionary *UNLiteRequest(NSDictionary *message)
{
	int fd = UNLiteConnect();
	if (fd < 0)
		return nil;
	NSDictionary *reply = UNLiteSend(fd, message) ? UNLiteReceive(fd) : nil;
	close(fd);
	return reply;
}

#pragma mark - Conversions

/* What a property list can hold; anything else in userInfo is left out. */
static BOOL UNLiteIsPropertyList(id object)
{
	return object != nil && [NSPropertyListSerialization dataWithPropertyList:object format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL] != nil;
}

static void UNLiteSet(NSMutableDictionary *wire, NSString *key, id value)
{
	if (value != nil)
		wire[key] = value;
}

static id UNLiteGet(NSDictionary *wire, NSString *key, Class class)
{
	id value = wire[key];
	return [value isKindOfClass:class] ? value : nil;
}

static NSDictionary *UNLiteWireSound(UNNotificationSound *sound)
{
	NSMutableDictionary *wire = [NSMutableDictionary dictionary];
	UNLiteSet(wire, @"name", sound.name);
	if (sound.critical) {
		wire[@"critical"] = @YES;
		wire[@"volume"] = @(sound.audioVolume);
	}
	return wire;
}

static UNNotificationSound *UNLiteSoundFromWire(NSDictionary *wire)
{
	if (![wire isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *name = UNLiteGet(wire, @"name", [NSString class]);
	if ([UNLiteGet(wire, @"critical", [NSNumber class]) boolValue]) {
		float volume = [UNLiteGet(wire, @"volume", [NSNumber class]) floatValue];
		return name ? [UNNotificationSound criticalSoundNamed:name withAudioVolume:volume]
		            : [UNNotificationSound defaultCriticalSoundWithAudioVolume:volume];
	}
	return name ? [UNNotificationSound soundNamed:name] : [UNNotificationSound defaultSound];
}

static NSDictionary *UNLiteWireContent(UNNotificationContent *content)
{
	NSMutableDictionary *wire = [NSMutableDictionary dictionary];
	UNLiteSet(wire, @"title", content.title);
	UNLiteSet(wire, @"subtitle", content.subtitle);
	UNLiteSet(wire, @"body", content.body);
	UNLiteSet(wire, @"badge", content.badge);
	if (content.sound != nil)
		wire[@"sound"] = UNLiteWireSound(content.sound);
	if (content.userInfo.count > 0) {
		if (UNLiteIsPropertyList(content.userInfo))
			wire[@"userInfo"] = content.userInfo;
		else
			NSLog(@"UserNotifications: userInfo is not a property list; it is left out");
	}
	UNLiteSet(wire, @"categoryIdentifier", content.categoryIdentifier);
	UNLiteSet(wire, @"threadIdentifier", content.threadIdentifier);
	UNLiteSet(wire, @"launchImageName", content.launchImageName);
	UNLiteSet(wire, @"targetContentIdentifier", content.targetContentIdentifier);
	UNLiteSet(wire, @"summaryArgument", content.summaryArgument);
	wire[@"summaryArgumentCount"] = @(content.summaryArgumentCount);
	wire[@"interruptionLevel"] = @(content.interruptionLevel);
	wire[@"relevanceScore"] = @(content.relevanceScore);
	return wire;
}

static UNNotificationContent *UNLiteContentFromWire(NSDictionary *wire)
{
	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	if (![wire isKindOfClass:[NSDictionary class]])
		return [content copy];
	content.title = UNLiteGet(wire, @"title", [NSString class]) ?: @"";
	content.subtitle = UNLiteGet(wire, @"subtitle", [NSString class]) ?: @"";
	content.body = UNLiteGet(wire, @"body", [NSString class]) ?: @"";
	content.badge = UNLiteGet(wire, @"badge", [NSNumber class]);
	content.sound = UNLiteSoundFromWire(wire[@"sound"]);
	content.userInfo = UNLiteGet(wire, @"userInfo", [NSDictionary class]) ?: @{};
	content.categoryIdentifier = UNLiteGet(wire, @"categoryIdentifier", [NSString class]) ?: @"";
	content.threadIdentifier = UNLiteGet(wire, @"threadIdentifier", [NSString class]) ?: @"";
	content.launchImageName = UNLiteGet(wire, @"launchImageName", [NSString class]) ?: @"";
	content.targetContentIdentifier = UNLiteGet(wire, @"targetContentIdentifier", [NSString class]);
	content.summaryArgument = UNLiteGet(wire, @"summaryArgument", [NSString class]) ?: @"";
	content.summaryArgumentCount = [UNLiteGet(wire, @"summaryArgumentCount", [NSNumber class]) unsignedIntegerValue];
	content.interruptionLevel = [UNLiteGet(wire, @"interruptionLevel", [NSNumber class]) unsignedIntegerValue];
	content.relevanceScore = [UNLiteGet(wire, @"relevanceScore", [NSNumber class]) doubleValue];
	return [content copy];
}

static NSString * const UNLiteComponentKeys[] = { @"year", @"month", @"day", @"hour", @"minute", @"second", @"weekday" };

static NSInteger UNLiteComponent(NSDateComponents *components, NSUInteger index)
{
	switch (index) {
	case 0: return components.year;
	case 1: return components.month;
	case 2: return components.day;
	case 3: return components.hour;
	case 4: return components.minute;
	case 5: return components.second;
	default: return components.weekday;
	}
}

static NSDictionary *UNLiteWireComponents(NSDateComponents *components)
{
	NSMutableDictionary *wire = [NSMutableDictionary dictionary];
	for (NSUInteger i = 0; i < 7; i++) {
		NSInteger value = UNLiteComponent(components, i);
		if (value != NSUndefinedDateComponent)
			wire[UNLiteComponentKeys[i]] = @(value);
	}
	UNLiteSet(wire, @"timeZone", components.timeZone.name);
	UNLiteSet(wire, @"calendar", components.calendar.calendarIdentifier);
	return wire;
}

static NSDateComponents *UNLiteComponentsFromWire(NSDictionary *wire)
{
	NSDateComponents *components = [[NSDateComponents alloc] init];
	if (![wire isKindOfClass:[NSDictionary class]])
		return components;
	NSNumber *value;
	if ((value = UNLiteGet(wire, @"year", [NSNumber class]))) components.year = [value integerValue];
	if ((value = UNLiteGet(wire, @"month", [NSNumber class]))) components.month = [value integerValue];
	if ((value = UNLiteGet(wire, @"day", [NSNumber class]))) components.day = [value integerValue];
	if ((value = UNLiteGet(wire, @"hour", [NSNumber class]))) components.hour = [value integerValue];
	if ((value = UNLiteGet(wire, @"minute", [NSNumber class]))) components.minute = [value integerValue];
	if ((value = UNLiteGet(wire, @"second", [NSNumber class]))) components.second = [value integerValue];
	if ((value = UNLiteGet(wire, @"weekday", [NSNumber class]))) components.weekday = [value integerValue];
	NSString *name = UNLiteGet(wire, @"timeZone", [NSString class]);
	if (name != nil)
		components.timeZone = [NSTimeZone timeZoneWithName:name];
	name = UNLiteGet(wire, @"calendar", [NSString class]);
	if (name != nil)
		components.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:name];
	return components;
}

/* Private: UNUserNotifications.m's. */
@interface UNTimeIntervalNotificationTrigger (UNLite)
+ (instancetype) un_triggerWithTimeInterval: (NSTimeInterval) interval repeats: (BOOL) repeats fireDate: (NSDate *) fireDate;
- (NSDate *) un_fireDate;
@end

@interface UNNotification (UNLite)
+ (instancetype) un_notificationWithRequest: (UNNotificationRequest *) request date: (NSDate *) date;
@end

static NSDictionary *UNLiteWireTrigger(UNNotificationTrigger *trigger)
{
	if ([trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]]) {
		UNTimeIntervalNotificationTrigger *interval = (UNTimeIntervalNotificationTrigger *)trigger;
		return @{ @"type": @"interval", @"interval": @(interval.timeInterval), @"repeats": @(trigger.repeats),
		          @"fireDate": [interval un_fireDate] };
	}
	if ([trigger isKindOfClass:[UNCalendarNotificationTrigger class]]) {
		UNCalendarNotificationTrigger *calendar = (UNCalendarNotificationTrigger *)trigger;
		NSMutableDictionary *wire = [@{ @"type": @"calendar", @"components": UNLiteWireComponents(calendar.dateComponents),
		                                @"repeats": @(trigger.repeats) } mutableCopy];
		UNLiteSet(wire, @"fireDate", [calendar nextTriggerDate]);
		return wire;
	}
	return nil;
}

static UNNotificationTrigger *UNLiteTriggerFromWire(NSDictionary *wire)
{
	if (![wire isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *type = UNLiteGet(wire, @"type", [NSString class]);
	BOOL repeats = [UNLiteGet(wire, @"repeats", [NSNumber class]) boolValue];
	if ([type isEqualToString:@"interval"]) {
		NSTimeInterval interval = [UNLiteGet(wire, @"interval", [NSNumber class]) doubleValue];
		NSDate *fireDate = UNLiteNextFireDate(wire, [NSDate date]) ?: UNLiteGet(wire, @"fireDate", [NSDate class]);
		return [UNTimeIntervalNotificationTrigger un_triggerWithTimeInterval:interval repeats:repeats fireDate:fireDate];
	}
	if ([type isEqualToString:@"calendar"])
		return [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:UNLiteComponentsFromWire(wire[@"components"]) repeats:repeats];
	return nil;
}

NSDictionary *UNLiteWireRequest(UNNotificationRequest *request)
{
	NSMutableDictionary *wire = [NSMutableDictionary dictionary];
	wire[@"identifier"] = request.identifier ?: @"";
	wire[@"content"] = UNLiteWireContent(request.content);
	UNLiteSet(wire, @"trigger", UNLiteWireTrigger(request.trigger));
	return wire;
}

UNNotificationRequest *UNLiteRequestFromWire(NSDictionary *wire)
{
	NSString *identifier = UNLiteGet(wire, @"identifier", [NSString class]);
	if (identifier == nil)
		return nil;
	return [UNNotificationRequest requestWithIdentifier:identifier content:UNLiteContentFromWire(wire[@"content"])
	                                            trigger:UNLiteTriggerFromWire(wire[@"trigger"])];
}

NSDictionary *UNLiteWireNotification(UNNotification *notification)
{
	return @{ @"date": notification.date ?: [NSDate date], @"request": UNLiteWireRequest(notification.request) };
}

UNNotification *UNLiteNotificationFromWire(NSDictionary *wire)
{
	if (![wire isKindOfClass:[NSDictionary class]])
		return nil;
	UNNotificationRequest *request = UNLiteRequestFromWire(wire[@"request"]);
	if (request == nil)
		return nil;
	return [UNNotification un_notificationWithRequest:request date:UNLiteGet(wire, @"date", [NSDate class]) ?: [NSDate date]];
}

NSDictionary *UNLiteWireCategory(UNNotificationCategory *category)
{
	NSMutableArray *actions = [NSMutableArray array];
	for (UNNotificationAction *action in category.actions)
		[actions addObject:@{ @"identifier": action.identifier ?: @"", @"title": action.title ?: @"", @"options": @(action.options) }];
	return @{ @"identifier": category.identifier ?: @"", @"actions": actions, @"options": @(category.options),
	          @"intentIdentifiers": category.intentIdentifiers ?: @[] };
}

UNNotificationCategory *UNLiteCategoryFromWire(NSDictionary *wire)
{
	NSString *identifier = UNLiteGet(wire, @"identifier", [NSString class]);
	if (identifier == nil)
		return nil;
	NSMutableArray *actions = [NSMutableArray array];
	for (NSDictionary *action in UNLiteGet(wire, @"actions", [NSArray class])) {
		if (![action isKindOfClass:[NSDictionary class]])
			continue;
		[actions addObject:[UNNotificationAction actionWithIdentifier:UNLiteGet(action, @"identifier", [NSString class]) ?: @""
		                                                        title:UNLiteGet(action, @"title", [NSString class]) ?: @""
		                                                      options:[UNLiteGet(action, @"options", [NSNumber class]) unsignedIntegerValue]]];
	}
	return [UNNotificationCategory categoryWithIdentifier:identifier actions:actions
	                                    intentIdentifiers:UNLiteGet(wire, @"intentIdentifiers", [NSArray class]) ?: @[]
	                                              options:[UNLiteGet(wire, @"options", [NSNumber class]) unsignedIntegerValue]];
}

#pragma mark - Dates

NSDate *UNLiteNextFireDate(NSDictionary *trigger, NSDate *after)
{
	NSString *type = UNLiteGet(trigger, @"type", [NSString class]);
	BOOL repeats = [UNLiteGet(trigger, @"repeats", [NSNumber class]) boolValue];
	if ([type isEqualToString:@"interval"]) {
		NSDate *fireDate = UNLiteGet(trigger, @"fireDate", [NSDate class]);
		NSTimeInterval interval = [UNLiteGet(trigger, @"interval", [NSNumber class]) doubleValue];
		if (fireDate == nil)
			return nil;
		if ([fireDate compare:after] == NSOrderedDescending)
			return fireDate;
		if (!repeats || interval <= 0)
			return nil;
		double periods = floor([after timeIntervalSinceDate:fireDate] / interval) + 1;
		return [fireDate dateByAddingTimeInterval:periods * interval];
	}
	if ([type isEqualToString:@"calendar"])
		return UNLiteNextDateMatching(UNLiteComponentsFromWire(trigger[@"components"]), after);
	return nil;
}

NSDate *UNLiteNextDateMatching(NSDateComponents *wanted, NSDate *after)
{
	NSCalendar *calendar = [(wanted.calendar ?: [NSCalendar currentCalendar]) copy];
	if (wanted.timeZone != nil)
		calendar.timeZone = wanted.timeZone;

	NSInteger value[7];
	NSInteger smallest = -1;
	for (NSUInteger i = 0; i < 7; i++) {
		value[i] = UNLiteComponent(wanted, i);
		if (i < 6 && value[i] != NSUndefinedDateComponent)
			smallest = i;
	}
	if (smallest < 0) {
		if (value[6] == NSUndefinedDateComponent)
			return nil;
		smallest = 2; /* a weekday alone: at midnight */
	}

	/* Each time of day unit: the one wanted, its minimum below the smallest
	   unit given, or any. */
	NSRange times[3];
	static const NSUInteger limits[3] = { 24, 60, 60 };
	for (NSUInteger i = 0; i < 3; i++) {
		NSInteger v = value[3 + i];
		if (v != NSUndefinedDateComponent)
			times[i] = NSMakeRange(v, 1);
		else if ((NSInteger)(3 + i) > smallest)
			times[i] = NSMakeRange(0, 1);
		else
			times[i] = NSMakeRange(0, limits[i]);
	}

	NSDateComponents *dayOf = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:after];
	NSDate *day = [calendar dateFromComponents:dayOf];
	NSDateComponents *oneDay = [[NSDateComponents alloc] init];
	oneDay.day = 1;
	/* Eight years covers any February 29th. */
	for (NSUInteger n = 0; n < 8 * 366 + 1 && day != nil; n++) {
		NSDate *next = [calendar dateByAddingComponents:oneDay toDate:day options:0];
		NSDateComponents *got = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekday fromDate:day];
		if (value[0] != NSUndefinedDateComponent && got.year > value[0])
			return nil;
		BOOL matches = [next compare:after] == NSOrderedDescending
			&& (value[0] == NSUndefinedDateComponent || got.year == value[0])
			&& (value[1] == NSUndefinedDateComponent || got.month == value[1])
			&& (value[2] == NSUndefinedDateComponent || got.day == value[2])
			&& (value[6] == NSUndefinedDateComponent || got.weekday == value[6]);
		if (matches) {
			NSDateComponents *at = [[NSDateComponents alloc] init];
			at.year = got.year;
			at.month = got.month;
			at.day = got.day;
			for (NSUInteger h = times[0].location; h < NSMaxRange(times[0]); h++)
				for (NSUInteger m = times[1].location; m < NSMaxRange(times[1]); m++)
					for (NSUInteger s = times[2].location; s < NSMaxRange(times[2]); s++) {
						at.hour = h;
						at.minute = m;
						at.second = s;
						NSDate *date = [calendar dateFromComponents:at];
						if (date != nil && [date compare:after] == NSOrderedDescending)
							return date;
					}
		}
		day = next;
	}
	return nil;
}
