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

/* usernotificationsd: keeps every app's scheduled notifications and fires
   them when their triggers come due, the way iOS's daemon of the same name
   does. A notification for an app that is in front goes to the app first
   (its delegate decides whether it is shown); otherwise it goes straight to
   the presenter, SpringBoard, which shows it. What the user does with one
   comes back from SpringBoard and goes on to the app, now or when it next
   checks in. The protocol is in UserNotifications' UNLite.h.

   Everything is kept in ~/Library/UserNotifications/Notifications.plist
   (or $USERNOTIFICATIONS_STORE),
   so scheduled notifications outlive the daemon; ones that came due while
   it was not running are delivered when it starts, and shown too if they
   are less than ten minutes late. frontboardd starts it.

   With $USERNOTIFICATIONS_SCHEDULE set, it also writes what is coming to
   that file, for a host that can wake the phone when Darling is not
   running (Darling Pocket hands it to Android's AlarmManager). One line per
   firing, soonest first, tab-separated:
     <unix time in ms> <alarm|normal> <bundle id> <identifier> <title> <body>
   with \, tab and newline escaped as \\, \t and \n. A repeating request
   gives its next few firings. */

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "UNLite.h"
#import "DBWire.h"
#include <sys/socket.h>
#include <signal.h>
#include <errno.h>
#include <unistd.h>
#include <pthread.h>
#include <time.h>

/* How late a notification may be and still be shown. */
static const NSTimeInterval UNDShowLateness = 10 * 60;
/* How long an app in front gets to say whether to show one. */
static const int64_t UNDPresentTimeout = 3 * NSEC_PER_SEC;
/* The clock may be set: look again at least this often. */
static const NSTimeInterval UNDLongestWait = 60;
/* Delivered notifications kept per app, newest first. */
static const NSUInteger UNDDeliveredLimit = 64;
/* Shows waiting for a presenter. */
static const NSUInteger UNDWaitingLimit = 16;
/* Firings of each repeating request written to the schedule. */
static const NSUInteger UNDScheduleRepeats = 3;

/* All state lives on this queue. */
static dispatch_queue_t sQueue;
static NSString *sStorePath;
static NSString *sSchedulePath;
/* bundleIdentifier -> { pending: [{request, fireDate}], delivered: [notification], categories: [category] } */
static NSMutableDictionary<NSString *, NSMutableDictionary *> *sApps;
static dispatch_source_t sTimer;
/* bundleIdentifier -> its check-in connection */
static NSMutableDictionary<NSString *, NSNumber *> *sCheckIns;
/* bundleIdentifier -> responses waiting for it to check in */
static NSMutableDictionary<NSString *, NSMutableArray *> *sWaitingResponses;
static int sPresenter = -1;
static NSMutableArray<NSDictionary *> *sWaitingShows;
/* token -> what to do with the app's presentation options */
static NSMutableDictionary<NSNumber *, void (^)(UNNotificationPresentationOptions)> *sPresentations;
static uint64_t sNextToken = 1;

static void UNDLog(NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	fprintf(stderr, "usernotificationsd: %s\n", [line UTF8String]);
}

#pragma mark - Store

static void UNDLoad(void)
{
	sApps = [NSMutableDictionary dictionary];
	NSDictionary *store = [NSDictionary dictionaryWithContentsOfFile:sStorePath];
	NSDictionary *apps = store[@"apps"];
	if (![apps isKindOfClass:[NSDictionary class]])
		return;
	for (NSString *bundleIdentifier in apps) {
		NSDictionary *app = apps[bundleIdentifier];
		if (![app isKindOfClass:[NSDictionary class]])
			continue;
		NSMutableDictionary *loaded = [NSMutableDictionary dictionary];
		for (NSString *key in @[ @"pending", @"delivered", @"categories" ])
			loaded[key] = [app[key] isKindOfClass:[NSArray class]] ? [app[key] mutableCopy] : [NSMutableArray array];
		sApps[bundleIdentifier] = loaded;
	}
}

static NSString *UNDScheduleField(id value)
{
	NSString *text = [value isKindOfClass:[NSString class]] ? value : @"";
	text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
	text = [text stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
	text = [text stringByReplacingOccurrencesOfString:@"\r" withString:@""];
	return [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
}

static void UNDWriteSchedule(void)
{
	if (sSchedulePath == nil)
		return;
	NSMutableArray<NSArray *> *firings = [NSMutableArray array];
	for (NSString *bundleIdentifier in sApps) {
		for (NSDictionary *entry in sApps[bundleIdentifier][@"pending"]) {
			NSDictionary *request = entry[@"request"];
			NSDictionary *content = request[@"content"];
			NSDictionary *trigger = request[@"trigger"];
			BOOL alarm = [content[@"sound"][@"critical"] boolValue];
			NSString *rest = [@[ alarm ? @"alarm" : @"normal", UNDScheduleField(bundleIdentifier),
				UNDScheduleField(request[@"identifier"]), UNDScheduleField(content[@"title"]),
				UNDScheduleField(content[@"body"]) ] componentsJoinedByString:@"\t"];
			NSDate *date = entry[@"fireDate"];
			for (NSUInteger i = 0; date != nil && i < UNDScheduleRepeats; i++) {
				[firings addObject:@[ date, rest ]];
				date = [trigger[@"repeats"] boolValue] ? UNLiteNextFireDate(trigger, [date dateByAddingTimeInterval:1]) : nil;
			}
		}
	}
	[firings sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
		return [a[0] compare:b[0]];
	}];
	NSMutableString *text = [NSMutableString string];
	for (NSArray *firing in firings)
		[text appendFormat:@"%lld\t%@\n", (long long)([firing[0] timeIntervalSince1970] * 1000), firing[1]];
	if (![text writeToFile:sSchedulePath atomically:YES encoding:NSUTF8StringEncoding error:NULL])
		UNDLog(@"cannot write %@", sSchedulePath);
}

static void UNDSave(void)
{
	UNDWriteSchedule();
	[[NSFileManager defaultManager] createDirectoryAtPath:[sStorePath stringByDeletingLastPathComponent]
	                          withIntermediateDirectories:YES attributes:nil error:NULL];
	if (![@{ @"apps": sApps } writeToFile:sStorePath atomically:YES])
		UNDLog(@"cannot write %@", sStorePath);
}

static NSMutableDictionary *UNDApp(NSString *bundleIdentifier)
{
	NSMutableDictionary *app = sApps[bundleIdentifier];
	if (app == nil) {
		app = [@{ @"pending": [NSMutableArray array], @"delivered": [NSMutableArray array], @"categories": [NSMutableArray array] } mutableCopy];
		sApps[bundleIdentifier] = app;
	}
	return app;
}

static NSString *UNDIdentifierOfNotification(NSDictionary *notification)
{
	return notification[@"request"][@"identifier"];
}

/* The request as apps see it: its trigger says when it fires next. */
static NSDictionary *UNDRequestOfEntry(NSDictionary *entry)
{
	NSMutableDictionary *request = [entry[@"request"] mutableCopy];
	if (request[@"trigger"] != nil) {
		NSMutableDictionary *trigger = [request[@"trigger"] mutableCopy];
		trigger[@"fireDate"] = entry[@"fireDate"];
		request[@"trigger"] = trigger;
	}
	return request;
}

#pragma mark - Talking to apps and the presenter

static BOOL UNDSendTo(int fd, NSDictionary *event)
{
	/* A connection that has gone away fails here; its thread sees EOF and
	   cleans up. */
	return fd >= 0 && UNLiteSend(fd, event);
}

/* Whether the app is the one in front. Without frontboardd, an app that
   has checked in is taken to be: it is a plain app on a desktop. */
static BOOL UNDIsForeground(NSString *bundleIdentifier)
{
	NSDictionary *reply = DBWireRequest(@{ @"op": @"list" });
	if (reply == nil)
		return YES;
	for (NSDictionary *process in reply[@"processes"])
		if ([process[@"bundleIdentifier"] isEqual:bundleIdentifier])
			return [process[@"state"] integerValue] == 1 /* DBApplicationStateForeground */;
	return NO;
}

static void UNDShow(NSString *bundleIdentifier, NSDictionary *notification, UNNotificationPresentationOptions options)
{
	NSMutableDictionary *event = [@{ @"op": @"show", @"bundleIdentifier": bundleIdentifier, @"notification": notification,
	                                 @"options": @(options) } mutableCopy];
	NSString *categoryIdentifier = notification[@"request"][@"content"][@"categoryIdentifier"];
	for (NSDictionary *category in UNDApp(bundleIdentifier)[@"categories"]) {
		if ([category[@"identifier"] isEqual:categoryIdentifier]) {
			event[@"actions"] = category[@"actions"] ?: @[];
			event[@"categoryOptions"] = category[@"options"] ?: @0;
		}
	}
	if (UNDSendTo(sPresenter, event))
		return;
	[sWaitingShows addObject:event];
	if ([sWaitingShows count] > UNDWaitingLimit)
		[sWaitingShows removeObjectAtIndex:0];
}

static void UNDAddDelivered(NSString *bundleIdentifier, NSDictionary *notification)
{
	NSMutableArray *delivered = UNDApp(bundleIdentifier)[@"delivered"];
	NSString *identifier = UNDIdentifierOfNotification(notification);
	for (NSInteger i = [delivered count] - 1; i >= 0; i--)
		if ([UNDIdentifierOfNotification(delivered[i]) isEqual:identifier])
			[delivered removeObjectAtIndex:i];
	[delivered insertObject:notification atIndex:0];
	while ([delivered count] > UNDDeliveredLimit)
		[delivered removeLastObject];
}

static void UNDDeliver(NSString *bundleIdentifier, NSDictionary *request, NSDate *due)
{
	NSDate *now = [NSDate date];
	NSDictionary *notification = @{ @"date": now, @"request": request };
	UNDLog(@"%@: %@ is due", bundleIdentifier, request[@"identifier"]);

	if ([now timeIntervalSinceDate:due] > UNDShowLateness) {
		UNDAddDelivered(bundleIdentifier, notification);
		return;
	}

	NSNumber *checkIn = sCheckIns[bundleIdentifier];
	if (checkIn != nil && UNDIsForeground(bundleIdentifier)) {
		NSNumber *token = @(sNextToken++);
		sPresentations[token] = ^(UNNotificationPresentationOptions options) {
			UNDLog(@"%@ presents %@ with options %lu", bundleIdentifier, request[@"identifier"], (unsigned long)options);
			if (options & (UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionAlert))
				UNDAddDelivered(bundleIdentifier, notification);
			if (options & (UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound))
				UNDShow(bundleIdentifier, notification, options);
			UNDSave();
		};
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, UNDPresentTimeout), sQueue, ^{
			void (^presentation)(UNNotificationPresentationOptions) = sPresentations[token];
			if (presentation != nil) {
				[sPresentations removeObjectForKey:token];
				presentation(UNNotificationPresentationOptionNone);
			}
		});
		if (UNDSendTo([checkIn intValue], @{ @"op": @"present", @"notification": notification, @"token": token }))
			return;
		[sPresentations removeObjectForKey:token];
	}

	UNDAddDelivered(bundleIdentifier, notification);
	UNDShow(bundleIdentifier, notification, UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList
		| UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge);
}

static void UNDSendResponse(NSString *bundleIdentifier, NSDictionary *response)
{
	NSNumber *checkIn = sCheckIns[bundleIdentifier];
	if (checkIn != nil && UNDSendTo([checkIn intValue], response))
		return;
	NSMutableArray *waiting = sWaitingResponses[bundleIdentifier];
	if (waiting == nil)
		sWaitingResponses[bundleIdentifier] = waiting = [NSMutableArray array];
	[waiting addObject:response];
}

#pragma mark - Firing

static void UNDArm(void);

static void UNDFire(void)
{
	NSDate *now = [NSDate date];
	BOOL changed = NO;
	for (NSString *bundleIdentifier in [sApps allKeys]) {
		NSMutableArray *pending = UNDApp(bundleIdentifier)[@"pending"];
		for (NSDictionary *entry in [pending copy]) {
			NSDate *fireDate = entry[@"fireDate"];
			if ([fireDate timeIntervalSinceDate:now] > 0.05)
				continue;
			changed = YES;
			NSDictionary *request = UNDRequestOfEntry(entry);
			NSUInteger index = [pending indexOfObjectIdenticalTo:entry];
			NSDictionary *trigger = request[@"trigger"];
			NSDate *next = [trigger[@"repeats"] boolValue] ? UNLiteNextFireDate(trigger, now) : nil;
			if (next != nil)
				pending[index] = @{ @"request": entry[@"request"], @"fireDate": next };
			else
				[pending removeObjectAtIndex:index];
			UNDDeliver(bundleIdentifier, request, fireDate);
		}
	}
	if (changed)
		UNDSave();
	UNDArm();
}

/* One timer, for whichever notification is due first. It runs on the wall
   clock, so time spent asleep counts. */
static void UNDArm(void)
{
	NSDate *first = nil;
	for (NSDictionary *app in [sApps allValues])
		for (NSDictionary *entry in app[@"pending"])
			if (first == nil || [entry[@"fireDate"] compare:first] == NSOrderedAscending)
				first = entry[@"fireDate"];
	NSTimeInterval wait = first != nil ? MIN([first timeIntervalSinceNow], UNDLongestWait) : UNDLongestWait;
	struct timespec when;
	clock_gettime(CLOCK_REALTIME, &when);
	double at = when.tv_sec + when.tv_nsec / 1e9 + MAX(wait, 0);
	when.tv_sec = (time_t)at;
	when.tv_nsec = (long)((at - when.tv_sec) * 1e9);
	dispatch_source_set_timer(sTimer, dispatch_walltime(&when, 0), DISPATCH_TIME_FOREVER, 10 * NSEC_PER_MSEC);
}

#pragma mark - Requests

static NSDictionary *UNDError(UNErrorCode code, NSString *reason)
{
	return @{ @"error": reason, @"code": @(code) };
}

static NSDictionary *UNDAdd(NSString *bundleIdentifier, NSDictionary *request)
{
	NSString *identifier = request[@"identifier"];
	if (![identifier isKindOfClass:[NSString class]] || ![request[@"content"] isKindOfClass:[NSDictionary class]])
		return UNDError(UNErrorCodeNotificationInvalidNoContent, @"The request has no identifier or content.");

	/* A request replaces any pending one with its identifier. */
	NSMutableArray *pending = UNDApp(bundleIdentifier)[@"pending"];
	for (NSInteger i = [pending count] - 1; i >= 0; i--)
		if ([pending[i][@"request"][@"identifier"] isEqual:identifier])
			[pending removeObjectAtIndex:i];

	NSDictionary *trigger = request[@"trigger"];
	if (trigger == nil) {
		UNDDeliver(bundleIdentifier, request, [NSDate date]);
		UNDSave();
		return @{};
	}
	NSDate *fireDate = [trigger[@"type"] isEqual:@"interval"] ? trigger[@"fireDate"] : UNLiteNextFireDate(trigger, [NSDate date]);
	if (![fireDate isKindOfClass:[NSDate class]]) {
		UNDSave();
		return UNDError(UNErrorCodeNotificationInvalidNoDate, @"The trigger never fires.");
	}
	NSMutableDictionary *stored = [request mutableCopy];
	NSMutableDictionary *storedTrigger = [trigger mutableCopy];
	[storedTrigger removeObjectForKey:@"fireDate"];
	if ([trigger[@"type"] isEqual:@"interval"])
		storedTrigger[@"fireDate"] = fireDate; /* where the intervals count from */
	stored[@"trigger"] = storedTrigger;
	[pending addObject:@{ @"request": stored, @"fireDate": fireDate }];
	UNDLog(@"%@: %@ fires at %@", bundleIdentifier, identifier, fireDate);
	UNDSave();
	UNDArm();
	return @{};
}

static void UNDRemove(NSMutableArray *list, NSArray *identifiers, NSString *(^identify)(NSDictionary *))
{
	if (![identifiers isKindOfClass:[NSArray class]]) {
		[list removeAllObjects];
		return;
	}
	for (NSInteger i = [list count] - 1; i >= 0; i--)
		if ([identifiers containsObject:identify(list[i]) ?: @""])
			[list removeObjectAtIndex:i];
}

static NSDictionary *UNDRespond(NSString *bundleIdentifier, NSDictionary *request)
{
	NSString *identifier = request[@"identifier"];
	NSString *action = request[@"action"] ?: UNNotificationDefaultActionIdentifier;
	NSMutableArray *delivered = UNDApp(bundleIdentifier)[@"delivered"];
	NSDictionary *notification = nil;
	for (NSDictionary *candidate in delivered)
		if ([UNDIdentifierOfNotification(candidate) isEqual:identifier]) {
			notification = candidate;
			break;
		}
	notification = notification ?: request[@"notification"];
	if (notification == nil)
		return UNDError(UNErrorCodeNotificationInvalidNoContent, @"No such notification.");
	UNDRemove(delivered, @[ identifier ], ^NSString *(NSDictionary *candidate) {
		return UNDIdentifierOfNotification(candidate);
	});
	UNDSave();

	UNDLog(@"%@: %@ answered with %@", bundleIdentifier, identifier, action);
	if ([action isEqual:UNNotificationDismissActionIdentifier]) {
		/* Apps hear about dismissals only if their category asks. */
		NSString *categoryIdentifier = notification[@"request"][@"content"][@"categoryIdentifier"];
		BOOL wanted = NO;
		for (NSDictionary *category in UNDApp(bundleIdentifier)[@"categories"])
			if ([category[@"identifier"] isEqual:categoryIdentifier])
				wanted = ([category[@"options"] unsignedIntegerValue] & UNNotificationCategoryOptionCustomDismissAction) != 0;
		if (!wanted)
			return @{};
	}
	UNDSendResponse(bundleIdentifier, @{ @"op": @"response", @"notification": notification, @"action": action });
	return @{};
}

static NSDictionary *UNDHandle(NSDictionary *request)
{
	NSString *op = request[@"op"];
	NSString *bundleIdentifier = request[@"bundleIdentifier"];
	if (![bundleIdentifier isKindOfClass:[NSString class]] || [bundleIdentifier length] == 0)
		return UNDError(UNErrorCodeNotificationsNotAllowed, @"The request names no app.");
	NSMutableDictionary *app = UNDApp(bundleIdentifier);

	if ([op isEqualToString:@"add"])
		return UNDAdd(bundleIdentifier, request[@"request"]);
	if ([op isEqualToString:@"pending"]) {
		NSMutableArray *requests = [NSMutableArray array];
		for (NSDictionary *entry in app[@"pending"])
			[requests addObject:UNDRequestOfEntry(entry)];
		return @{ @"requests": requests };
	}
	if ([op isEqualToString:@"removePending"]) {
		UNDRemove(app[@"pending"], request[@"identifiers"], ^NSString *(NSDictionary *entry) {
			return entry[@"request"][@"identifier"];
		});
		UNDSave();
		UNDArm();
		return @{};
	}
	if ([op isEqualToString:@"delivered"])
		return @{ @"notifications": app[@"delivered"] };
	if ([op isEqualToString:@"removeDelivered"]) {
		NSArray *identifiers = request[@"identifiers"];
		NSMutableArray *removed = [NSMutableArray array];
		for (NSDictionary *notification in app[@"delivered"])
			if (![identifiers isKindOfClass:[NSArray class]] || [identifiers containsObject:UNDIdentifierOfNotification(notification)])
				[removed addObject:UNDIdentifierOfNotification(notification)];
		UNDRemove(app[@"delivered"], identifiers, ^NSString *(NSDictionary *notification) {
			return UNDIdentifierOfNotification(notification);
		});
		UNDSave();
		/* An alert still up for one of them goes away too. */
		NSArray *withdrawn = [identifiers isKindOfClass:[NSArray class]] ? identifiers : removed;
		if ([withdrawn count] > 0)
			UNDSendTo(sPresenter, @{ @"op": @"withdraw", @"bundleIdentifier": bundleIdentifier, @"identifiers": withdrawn });
		return @{};
	}
	if ([op isEqualToString:@"setCategories"]) {
		NSArray *categories = request[@"categories"];
		app[@"categories"] = [categories isKindOfClass:[NSArray class]] ? [categories mutableCopy] : [NSMutableArray array];
		UNDSave();
		return @{};
	}
	if ([op isEqualToString:@"categories"])
		return @{ @"categories": app[@"categories"] };
	if ([op isEqualToString:@"respond"])
		return UNDRespond(bundleIdentifier, request);
	return UNDError(UNErrorCodeNotificationsNotAllowed, [NSString stringWithFormat:@"unknown request \"%@\"", op]);
}

#pragma mark - Connections

/* Connections that stay open block for as long as their peer lives, so
   each gets a thread of its own rather than one of GCD's few workers. */
static void *UNDThreadMain(void *block)
{
	void (^work)(void) = (__bridge_transfer void (^)(void))block;
	work();
	return NULL;
}

static void UNDDetach(void (^work)(void))
{
	pthread_t thread;
	pthread_attr_t attributes;
	pthread_attr_init(&attributes);
	pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
	pthread_create(&thread, &attributes, UNDThreadMain, (__bridge_retained void *)[work copy]);
	pthread_attr_destroy(&attributes);
}

static void UNDCheckIn(NSString *bundleIdentifier, int fd)
{
	dispatch_sync(sQueue, ^{
		UNDLog(@"%@ checked in", bundleIdentifier);
		sCheckIns[bundleIdentifier] = @(fd);
		NSArray *waiting = sWaitingResponses[bundleIdentifier];
		[sWaitingResponses removeObjectForKey:bundleIdentifier];
		for (NSDictionary *response in waiting)
			UNDSendTo(fd, response);
	});
	NSDictionary *message;
	while ((message = UNLiteReceive(fd)) != nil) {
		if (![message[@"op"] isEqual:@"presentOptions"])
			continue;
		dispatch_async(sQueue, ^{
			NSNumber *token = message[@"token"];
			void (^presentation)(UNNotificationPresentationOptions) = sPresentations[token];
			if (presentation != nil) {
				[sPresentations removeObjectForKey:token];
				presentation([message[@"options"] unsignedIntegerValue]);
			}
		});
	}
	dispatch_sync(sQueue, ^{
		if ([sCheckIns[bundleIdentifier] intValue] == fd)
			[sCheckIns removeObjectForKey:bundleIdentifier];
	});
}

static void UNDServePresenter(int fd)
{
	dispatch_sync(sQueue, ^{
		UNDLog(@"the presenter connected");
		sPresenter = fd;
		NSArray *waiting = [sWaitingShows copy];
		[sWaitingShows removeAllObjects];
		for (NSDictionary *show in waiting)
			UNDSendTo(fd, show);
	});
	while (UNLiteReceive(fd) != nil)
		;
	dispatch_sync(sQueue, ^{
		if (sPresenter == fd)
			sPresenter = -1;
	});
}

static void UNDServe(int fd)
{
	@autoreleasepool {
		NSDictionary *request = UNLiteReceive(fd);
		NSString *op = request[@"op"];
		if ([op isEqual:@"checkin"] && [request[@"bundleIdentifier"] isKindOfClass:[NSString class]])
			UNDCheckIn(request[@"bundleIdentifier"], fd);
		else if ([op isEqual:@"presenter"])
			UNDServePresenter(fd);
		else if (op != nil) {
			__block NSDictionary *reply;
			dispatch_sync(sQueue, ^{
				reply = UNDHandle(request);
			});
			UNLiteSend(fd, reply);
		}
		close(fd);
	}
}

int main(int argc, char **argv)
{
	@autoreleasepool {
		signal(SIGPIPE, SIG_IGN);
		sQueue = dispatch_queue_create("usernotificationsd", DISPATCH_QUEUE_SERIAL);
		const char *store = getenv("USERNOTIFICATIONS_STORE");
		sStorePath = store != NULL ? [NSString stringWithUTF8String:store]
			: [NSHomeDirectory() stringByAppendingPathComponent:@"Library/UserNotifications/Notifications.plist"];
		const char *schedule = getenv("USERNOTIFICATIONS_SCHEDULE");
		if (schedule != NULL && *schedule != '\0')
			sSchedulePath = [NSString stringWithUTF8String:schedule];
		sCheckIns = [NSMutableDictionary dictionary];
		sWaitingResponses = [NSMutableDictionary dictionary];
		sWaitingShows = [NSMutableArray array];
		sPresentations = [NSMutableDictionary dictionary];

		int running = UNLiteConnect();
		if (running >= 0) {
			UNDLog(@"already running on %@", UNLiteSocketPath());
			close(running);
			return 0;
		}
		int listener = UNLiteListen();
		if (listener < 0) {
			UNDLog(@"cannot listen on %@: %s", UNLiteSocketPath(), strerror(errno));
			return 1;
		}
		UNDLog(@"listening on %@", UNLiteSocketPath());

		dispatch_sync(sQueue, ^{
			UNDLoad();
			UNDWriteSchedule();
			sTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, sQueue);
			dispatch_source_set_event_handler(sTimer, ^{
				UNDFire();
			});
			UNDArm();
			dispatch_resume(sTimer);
		});
		/* Due while we were not running. */
		dispatch_async(sQueue, ^{
			UNDFire();
		});

		for (;;) {
			int fd = accept(listener, NULL, NULL);
			if (fd < 0) {
				if (errno == EINTR)
					continue;
				UNDLog(@"accept: %s", strerror(errno));
				return 1;
			}
			UNDDetach(^{
				UNDServe(fd);
			});
		}
	}
}
