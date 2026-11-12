/* UserNotifications and usernotificationsd: the public classes, triggers'
   dates, and the round trip through the daemon, with this program as both
   the app and the presenter (SpringBoard's part). It starts its own daemon
   on a socket and home of its own. One PASS/FAIL line per check; exits
   nonzero on any failure. See ios-usernotifications.md. */

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "UNLite.h"
#include <spawn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

extern char **environ;
static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	fflush(stdout);
	if (!ok)
		failures++;
}

static void spin(NSTimeInterval seconds)
{
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static BOOL spinUntil(NSTimeInterval limit, BOOL (^done)(void))
{
	NSDate *end = [NSDate dateWithTimeIntervalSinceNow:limit];
	while (!done()) {
		if ([end timeIntervalSinceNow] <= 0)
			return NO;
		spin(0.05);
	}
	return YES;
}

/* Runs an asynchronous center call to completion. */
static id await(void (^call)(void (^done)(id result)))
{
	__block id result = nil;
	__block BOOL finished = NO;
	call(^(id value) {
		dispatch_async(dispatch_get_main_queue(), ^{
			result = value;
			finished = YES;
		});
	});
	spinUntil(10, ^BOOL { return finished; });
	return result;
}

static NSArray<UNNotificationRequest *> *pending(void)
{
	return await(^(void (^done)(id)) {
		[[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray *requests) {
			done(requests);
		}];
	});
}

static NSArray<UNNotification *> *delivered(void)
{
	return await(^(void (^done)(id)) {
		[[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray *notifications) {
			done(notifications);
		}];
	});
}

static NSError *add(UNNotificationRequest *request)
{
	return await(^(void (^done)(id)) {
		[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError *error) {
			done(error ?: (id)[NSNull null]);
		}];
	});
}

static BOOL hasRequest(NSArray *list, NSString *identifier)
{
	for (id item in list) {
		UNNotificationRequest *request = [item isKindOfClass:[UNNotification class]] ? [item request] : item;
		if ([request.identifier isEqual:identifier])
			return YES;
	}
	return NO;
}

#pragma mark - The daemon

static pid_t sDaemon;

static void startDaemon(void)
{
	char *argv[] = { "/usr/libexec/usernotificationsd", NULL };
	posix_spawn(&sDaemon, argv[0], NULL, NULL, argv, environ);
	spinUntil(10, ^BOOL {
		int fd = UNLiteConnect();
		if (fd >= 0)
			close(fd);
		return fd >= 0;
	});
}

static void stopDaemon(void)
{
	kill(sDaemon, SIGTERM);
	int status;
	waitpid(sDaemon, &status, 0);
}

#pragma mark - The presenter

static NSMutableArray<NSDictionary *> *sShown;
static int sPresenterFD = -1;

static void *presenterThread(void *unused)
{
	int fd = UNLiteConnect();
	sPresenterFD = fd;
	UNLiteSend(fd, @{ @"op": @"presenter" });
	NSDictionary *event;
	while ((event = UNLiteReceive(fd)) != nil)
		@synchronized (sShown) {
			[sShown addObject:event];
		}
	return NULL;
}

static NSDictionary *shown(NSString *op, NSString *identifier)
{
	@synchronized (sShown) {
		for (NSDictionary *event in sShown) {
			if (![event[@"op"] isEqual:op])
				continue;
			if ([op isEqual:@"withdraw"] ? [event[@"identifiers"] containsObject:identifier]
			                             : [event[@"notification"][@"request"][@"identifier"] isEqual:identifier])
				return event;
		}
	}
	return nil;
}

#pragma mark - The app's delegate

@interface Delegate : NSObject <UNUserNotificationCenterDelegate>
@property (nonatomic) NSMutableArray<UNNotification *> *presented;
@property (nonatomic) NSMutableArray<UNNotificationResponse *> *responses;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *answers;
@end

@implementation Delegate

- (instancetype)init
{
	if ((self = [super init])) {
		_presented = [NSMutableArray array];
		_responses = [NSMutableArray array];
		_answers = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
	[_presented addObject:notification];
	completionHandler([_answers[notification.request.identifier] unsignedIntegerValue]);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
	[_responses addObject:response];
	completionHandler();
}

- (UNNotificationResponse *)responseFor:(NSString *)identifier
{
	for (UNNotificationResponse *response in _responses)
		if ([response.notification.request.identifier isEqual:identifier])
			return response;
	return nil;
}

@end

#pragma mark - Checks

static UNMutableNotificationContent *content(NSString *title)
{
	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.title = title;
	content.body = @"Body";
	content.sound = [UNNotificationSound defaultSound];
	return content;
}

static void checkClasses(void)
{
	UNMutableNotificationContent *mutable = content(@"Title");
	mutable.subtitle = @"Sub";
	mutable.badge = @3;
	mutable.userInfo = @{ @"k": @"v" };
	mutable.categoryIdentifier = @"CAT";
	mutable.sound = [UNNotificationSound criticalSoundNamed:@"bell.caf" withAudioVolume:0.5];
	UNNotificationContent *copy = [mutable copy];
	expect([copy class] == [UNNotificationContent class] && [copy.title isEqual:@"Title"] && [copy.badge isEqual:@3]
		&& [copy.userInfo[@"k"] isEqual:@"v"] && copy.sound.critical && [copy.sound.name isEqual:@"bell.caf"],
		"copying mutable content gives immutable content with every field", [copy description]);
	expect([[copy mutableCopy] isKindOfClass:[UNMutableNotificationContent class]] && [[copy mutableCopy] isEqual:copy],
		"a mutable copy of content is mutable and equal", nil);
	expect([[UNNotificationContent new].title isEqual:@""] && [UNNotificationContent new].sound == nil,
		"new content has empty strings and no sound", nil);

	UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"r" content:mutable
		trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:90 repeats:YES]];
	mutable.title = @"Changed";
	expect([request.content.title isEqual:@"Title"], "a request keeps a copy of its content", nil);

	NSError *error = nil;
	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:request requiringSecureCoding:YES error:&error];
	UNNotificationRequest *decoded = archive ? [NSKeyedUnarchiver unarchivedObjectOfClass:[UNNotificationRequest class] fromData:archive error:&error] : nil;
	expect([decoded isEqual:request] && [decoded.trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]],
		"a request survives secure coding", decoded ? [decoded description] : [NSString stringWithFormat:@"%@", error]);

	BOOL threw = NO;
	@try { [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:30 repeats:YES]; } @catch (NSException *e) { threw = YES; }
	BOOL threwZero = NO;
	@try { [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0 repeats:NO]; } @catch (NSException *e) { threwZero = YES; }
	expect(threw && threwZero, "interval triggers refuse 0 seconds, and repeating under a minute", nil);

	UNTimeIntervalNotificationTrigger *interval = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:120 repeats:NO];
	NSTimeInterval in = [[interval nextTriggerDate] timeIntervalSinceNow];
	expect(in > 118 && in <= 120, "an interval trigger fires its interval from now", [NSString stringWithFormat:@"%.2f s", in]);
}

static NSDateComponents *components(NSInteger year, NSInteger month, NSInteger day, NSInteger hour, NSInteger minute, NSInteger second, NSInteger weekday)
{
	NSDateComponents *c = [[NSDateComponents alloc] init];
	if (year >= 0) c.year = year;
	if (month >= 0) c.month = month;
	if (day >= 0) c.day = day;
	if (hour >= 0) c.hour = hour;
	if (minute >= 0) c.minute = minute;
	if (second >= 0) c.second = second;
	if (weekday >= 0) c.weekday = weekday;
	return c;
}

static NSDate *date(NSInteger year, NSInteger month, NSInteger day, NSInteger hour, NSInteger minute, NSInteger second)
{
	NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	calendar.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
	return [calendar dateFromComponents:components(year, month, day, hour, minute, second, -1)];
}

static void checkCalendar(void)
{
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	gregorian.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
	NSDate *(^next)(NSDateComponents *, NSDate *) = ^NSDate *(NSDateComponents *c, NSDate *after) {
		c.calendar = gregorian;
		c.timeZone = gregorian.timeZone;
		return UNLiteNextDateMatching(c, after);
	};
	/* 2026-10-30 is a Friday. */
	NSDate *now = date(2026, 10, 30, 12, 30, 15);
	expect([next(components(-1, -1, -1, 7, 0, -1, -1), now) isEqual:date(2026, 10, 31, 7, 0, 0)],
		"7:00 after midday is tomorrow morning", nil);
	expect([next(components(-1, -1, -1, 13, -1, -1, -1), now) isEqual:date(2026, 10, 30, 13, 0, 0)],
		"an hour alone means on the hour", nil);
	expect([next(components(-1, -1, -1, 12, 30, 15, -1), now) isEqual:date(2026, 10, 31, 12, 30, 15)],
		"a date matching now is the next one, not now", nil);
	expect([next(components(-1, -1, -1, -1, -1, 0, -1), now) isEqual:date(2026, 10, 30, 12, 31, 0)],
		"a second alone matches every minute", nil);
	expect([next(components(-1, -1, -1, 8, 0, -1, 2), now) isEqual:date(2026, 11, 2, 8, 0, 0)],
		"Mondays at 8:00 after a Friday is three days on", nil);
	expect([next(components(-1, 2, 29, 9, 0, -1, -1), now) isEqual:date(2028, 2, 29, 9, 0, 0)],
		"February 29th is found in the next leap year", nil);
	expect(next(components(2020, 1, 1, 0, 0, 0, -1), now) == nil, "a date in the past never comes", nil);
	expect([next(components(-1, -1, 1, -1, -1, -1, -1), now) isEqual:date(2026, 11, 1, 0, 0, 0)],
		"a day of the month alone means its midnight", nil);

	NSDictionary *repeating = @{ @"type": @"interval", @"interval": @60, @"repeats": @YES, @"fireDate": date(2026, 10, 30, 12, 0, 0) };
	expect([UNLiteNextFireDate(repeating, now) isEqual:date(2026, 10, 30, 12, 31, 0)],
		"a repeating interval fires at whole intervals from its first date", nil);
}

static void checkDaemon(void)
{
	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

	NSError *error = add([UNNotificationRequest requestWithIdentifier:@"nodaemon" content:content(@"x") trigger:nil]);
	expect([error isKindOfClass:[NSError class]] && [error.domain isEqual:UNErrorDomain],
		"without the daemon, adding a request fails", [error description]);

	startDaemon();
	sShown = [NSMutableArray array];
	pthread_t thread;
	pthread_create(&thread, NULL, presenterThread, NULL);
	spin(0.3);

	/* A repeating calendar request, and one in a minute. */
	NSDateComponents *eight = components(-1, -1, -1, 8, 0, -1, -1);
	error = add([UNNotificationRequest requestWithIdentifier:@"morning" content:content(@"Morning")
		trigger:[UNCalendarNotificationTrigger triggerWithDateMatchingComponents:eight repeats:YES]]);
	expect(error == (id)[NSNull null], "adding a calendar request succeeds", [error description]);
	add([UNNotificationRequest requestWithIdentifier:@"later" content:content(@"Later")
		trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:60 repeats:NO]]);
	NSArray *requests = pending();
	UNNotificationRequest *later = nil;
	for (UNNotificationRequest *request in requests)
		if ([request.identifier isEqual:@"later"])
			later = request;
	NSTimeInterval in = [[(UNTimeIntervalNotificationTrigger *)later.trigger nextTriggerDate] timeIntervalSinceNow];
	expect([requests count] == 2 && hasRequest(requests, @"morning") && in > 55 && in <= 60,
		"pending requests come back, with when they fire", [NSString stringWithFormat:@"%lu, %.1f s", (unsigned long)[requests count], in]);
	UNNotificationRequest *morning = nil;
	for (UNNotificationRequest *request in requests)
		if ([request.identifier isEqual:@"morning"])
			morning = request;
	NSDateComponents *got = [morning.trigger isKindOfClass:[UNCalendarNotificationTrigger class]] ? [(UNCalendarNotificationTrigger *)morning.trigger dateComponents] : nil;
	expect(morning.trigger.repeats && got.hour == 8 && got.minute == 0,
		"a pending calendar trigger keeps its components and repeats", [got description]);

	add([UNNotificationRequest requestWithIdentifier:@"later" content:content(@"Later, replaced")
		trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:3600 repeats:NO]]);
	requests = pending();
	expect([requests count] == 2 && [[[requests lastObject] content].title isEqual:@"Later, replaced"],
		"a request replaces the pending one with its identifier", nil);

	[center removePendingNotificationRequestsWithIdentifiers:@[ @"later" ]];
	expect([pending() count] == 1, "removing a pending request by identifier", nil);

	error = add([UNNotificationRequest requestWithIdentifier:@"never" content:content(@"Never")
		trigger:[UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components(2001, 1, 1, 0, 0, 0, -1) repeats:NO]]);
	expect([error isKindOfClass:[NSError class]] && error.code == UNErrorCodeNotificationInvalidNoDate,
		"a trigger that never fires is refused", [error description]);

	/* In the background (no delegate, so not checked in): straight to the
	   presenter, and into the delivered list. */
	NSDate *start = [NSDate date];
	add([UNNotificationRequest requestWithIdentifier:@"soon" content:content(@"Soon")
		trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1.5 repeats:NO]]);
	BOOL came = spinUntil(8, ^BOOL { return shown(@"show", @"soon") != nil; });
	NSTimeInterval took = [[NSDate date] timeIntervalSinceDate:start];
	expect(came && took > 1.3 && took < 4, "a notification comes due on time and goes to the presenter",
		[NSString stringWithFormat:@"after %.2f s", took]);
	NSUInteger options = [shown(@"show", @"soon")[@"options"] unsignedIntegerValue];
	expect((options & UNNotificationPresentationOptionBanner) && (options & UNNotificationPresentationOptionSound),
		"a background app's notification is shown as a banner with sound", [NSString stringWithFormat:@"options %lu", (unsigned long)options]);
	expect(hasRequest(delivered(), @"soon") && !hasRequest(pending(), @"soon"),
		"once delivered, it is delivered and no longer pending", nil);

	/* Categories, and the presenter getting their actions. */
	UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:@"ALARM"
		actions:@[ [UNNotificationAction actionWithIdentifier:@"SNOOZE" title:@"Snooze" options:0] ]
		intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
	[center setNotificationCategories:[NSSet setWithObject:category]];
	NSSet *categories = await(^(void (^done)(id)) {
		[center getNotificationCategoriesWithCompletionHandler:^(NSSet *set) {
			done(set);
		}];
	});
	UNNotificationCategory *back = [categories anyObject];
	expect([categories count] == 1 && [back.identifier isEqual:@"ALARM"] && [[back.actions[0] title] isEqual:@"Snooze"]
		&& back.options == UNNotificationCategoryOptionCustomDismissAction, "categories are kept", [back description]);

	UNMutableNotificationContent *alarm = content(@"Alarm");
	alarm.categoryIdentifier = @"ALARM";
	alarm.sound = [UNNotificationSound defaultCriticalSound];
	add([UNNotificationRequest requestWithIdentifier:@"alarm" content:alarm trigger:nil]);
	spinUntil(5, ^BOOL { return shown(@"show", @"alarm") != nil; });
	NSDictionary *show = shown(@"show", @"alarm");
	expect([show[@"actions"][0][@"identifier"] isEqual:@"SNOOZE"] && [show[@"notification"][@"request"][@"content"][@"sound"][@"critical"] boolValue],
		"a request without a trigger is delivered at once, with its category's actions", [show[@"actions"] description]);

	/* The user answers while the app is not listening: the answer waits for
	   it, and comes when it sets a delegate. */
	UNLiteRequest(@{ @"op": @"respond", @"bundleIdentifier": [[NSBundle mainBundle] bundleIdentifier] ?: [[NSProcessInfo processInfo] processName],
	                 @"identifier": @"alarm", @"action": @"SNOOZE" });
	Delegate *delegate = [[Delegate alloc] init];
	center.delegate = delegate;
	spinUntil(5, ^BOOL { return [delegate responseFor:@"alarm"] != nil; });
	UNNotificationResponse *response = [delegate responseFor:@"alarm"];
	expect([response.actionIdentifier isEqual:@"SNOOZE"] && [response.notification.request.content.title isEqual:@"Alarm"],
		"an answer waits for the app, and reaches its delegate", [response description]);
	expect(!hasRequest(delivered(), @"alarm"), "an answered notification is no longer delivered", nil);

	/* In front, the delegate decides. */
	delegate.answers[@"shown"] = @(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionList);
	add([UNNotificationRequest requestWithIdentifier:@"shown" content:content(@"Shown") trigger:nil]);
	add([UNNotificationRequest requestWithIdentifier:@"quiet" content:content(@"Quiet") trigger:nil]);
	spinUntil(5, ^BOOL { return [delegate.presented count] >= 2 && shown(@"show", @"shown") != nil; });
	spin(0.5);
	expect([delegate.presented count] == 2, "an app in front is asked about each of its notifications",
		[NSString stringWithFormat:@"%lu asked", (unsigned long)[delegate.presented count]]);
	expect([shown(@"show", @"shown")[@"options"] unsignedIntegerValue] == [delegate.answers[@"shown"] unsignedIntegerValue]
		&& shown(@"show", @"quiet") == nil, "it is shown as the app says, or not at all", nil);
	NSArray *list = delivered();
	expect(hasRequest(list, @"shown") && !hasRequest(list, @"quiet"), "only the one shown in the list is delivered", nil);

	/* Dismissing: the ALARM category asks to hear about it. */
	delegate.answers[@"alarm2"] = @(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
	add([UNNotificationRequest requestWithIdentifier:@"alarm2" content:alarm trigger:nil]);
	spinUntil(5, ^BOOL { return shown(@"show", @"alarm2") != nil; });
	UNLiteRequest(@{ @"op": @"respond", @"bundleIdentifier": [[NSBundle mainBundle] bundleIdentifier] ?: [[NSProcessInfo processInfo] processName],
	                 @"identifier": @"alarm2", @"action": UNNotificationDismissActionIdentifier });
	UNLiteRequest(@{ @"op": @"respond", @"bundleIdentifier": [[NSBundle mainBundle] bundleIdentifier] ?: [[NSProcessInfo processInfo] processName],
	                 @"identifier": @"shown", @"action": UNNotificationDismissActionIdentifier });
	spinUntil(3, ^BOOL { return [delegate responseFor:@"alarm2"] != nil; });
	spin(0.5);
	expect([[delegate responseFor:@"alarm2"].actionIdentifier isEqual:UNNotificationDismissActionIdentifier]
		&& [delegate responseFor:@"shown"] == nil, "dismissals reach only apps whose category asks", nil);

	delegate.answers[@"gone"] = @(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList);
	add([UNNotificationRequest requestWithIdentifier:@"gone" content:content(@"Gone") trigger:nil]);
	spinUntil(5, ^BOOL { return hasRequest(delivered(), @"gone"); });
	[center removeDeliveredNotificationsWithIdentifiers:@[ @"gone" ]];
	spinUntil(5, ^BOOL { return shown(@"withdraw", @"gone") != nil; });
	expect(shown(@"withdraw", @"gone") != nil && !hasRequest(delivered(), @"gone"),
		"removing a delivered notification withdraws it from the presenter", nil);

	/* The daemon keeps what is pending across a restart. */
	stopDaemon();
	startDaemon();
	requests = pending();
	expect([requests count] == 1 && hasRequest(requests, @"morning"), "pending requests outlive the daemon",
		[NSString stringWithFormat:@"%lu pending", (unsigned long)[requests count]]);
	[center removeAllPendingNotificationRequests];
	[center removeAllDeliveredNotifications];
	expect([pending() count] == 0 && [delivered() count] == 0, "removing all pending and delivered", nil);
	stopDaemon();
}

int main(int argc, char **argv)
{
	@autoreleasepool {
		/* A daemon of our own: its socket and store are ours. */
		NSString *home = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"un-test-%d", getpid()]];
		[[NSFileManager defaultManager] createDirectoryAtPath:home withIntermediateDirectories:YES attributes:nil error:NULL];
		setenv("USERNOTIFICATIONS_SOCKET", [[home stringByAppendingPathComponent:@"un.sock"] fileSystemRepresentation], 1);
		setenv("USERNOTIFICATIONS_STORE", [[home stringByAppendingPathComponent:@"Notifications.plist"] fileSystemRepresentation], 1);
		/* No frontboardd to ask: an app that checked in counts as in front. */
		setenv("FRONTBOARD_SOCKET", [[home stringByAppendingPathComponent:@"none.sock"] fileSystemRepresentation], 1);

		checkClasses();
		checkCalendar();
		checkDaemon();
		[[NSFileManager defaultManager] removeItemAtPath:home error:NULL];
		printf("%d failures\n", failures);
		return failures ? 1 : 0;
	}
}
