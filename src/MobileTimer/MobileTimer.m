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

/*
 * Clock (com.apple.mobiletimer): World Clock, Alarm, Stopwatch and Timer,
 * one tab each. Alarms and the timer are local notifications, so they go
 * off with the app closed: usernotificationsd fires them and SpringBoard
 * rings them as alerts (their sounds are critical), with Snooze when the
 * alarm allows it. Everything else is kept in the app's defaults
 * (com.apple.mobiletimer); the stopwatch and timer keep running from
 * their saved start and end dates while the app is away.
 */

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

static NSString *const MTStateDidChangeNotification = @"MTStateDidChange";
static NSString *const MTAlarmCategory = @"MTAlarm";
static NSString *const MTAlarmNoSnoozeCategory = @"MTAlarmNoSnooze";
static NSString *const MTTimerCategory = @"MTTimer";
static NSString *const MTSnoozeAction = @"SNOOZE";
static NSString *const MTTimerRequest = @"timer";
static const NSTimeInterval MTSnoozeInterval = 9 * 60;

static UIColor *MTOrange(void)
{
	return [UIColor colorWithRed:1 green:0.58 blue:0 alpha:1];
}

static NSUserDefaults *MTDefaults(void)
{
	return [NSUserDefaults standardUserDefaults];
}

static void MTStateChanged(void)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:MTStateDidChangeNotification object:nil];
	});
}

static NSString *MTTimeString(NSDate *date, NSTimeZone *zone)
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateStyle = NSDateFormatterNoStyle;
	formatter.timeStyle = NSDateFormatterShortStyle;
	if (zone != nil)
		formatter.timeZone = zone;
	return [formatter stringFromDate:date];
}

static NSString *MTHourMinute(NSInteger hour, NSInteger minute)
{
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[NSDate date]];
	components.hour = hour;
	components.minute = minute;
	return MTTimeString([calendar dateFromComponents:components], nil);
}

/* 1:02:03.45, or 02:03.45 under an hour. */
static NSString *MTDuration(NSTimeInterval seconds, BOOL hundredths)
{
	seconds = MAX(seconds, 0);
	long whole = (long)seconds;
	long h = whole / 3600, m = whole / 60 % 60, s = whole % 60;
	NSString *clock = h > 0 ? [NSString stringWithFormat:@"%ld:%02ld:%02ld", h, m, s] : [NSString stringWithFormat:@"%02ld:%02ld", m, s];
	if (!hundredths)
		return clock;
	return [clock stringByAppendingFormat:@".%02ld", (long)((seconds - whole) * 100)];
}

#pragma mark - Drawing

/* Tab bar glyphs, drawn as strokes. */
static UIImage *MTTabIcon(NSInteger kind)
{
	CGSize size = CGSizeMake(26, 26);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	[[UIColor blackColor] setStroke];
	[[UIColor blackColor] setFill];
	CGPoint center = CGPointMake(13, 14);
	UIBezierPath *face = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 4, 20, 20)];
	face.lineWidth = 2;
	[face stroke];
	UIBezierPath *lines = [UIBezierPath bezierPath];
	lines.lineWidth = 2;
	switch (kind) {
	case 0: /* a globe */
		[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 4, 8, 20)] stroke];
		[lines moveToPoint:CGPointMake(3, 14)];
		[lines addLineToPoint:CGPointMake(23, 14)];
		break;
	case 1: /* an alarm clock: bells and hands */
		[lines moveToPoint:CGPointMake(2, 6)];
		[lines addLineToPoint:CGPointMake(6, 2)];
		[lines moveToPoint:CGPointMake(24, 6)];
		[lines addLineToPoint:CGPointMake(20, 2)];
		[lines moveToPoint:center];
		[lines addLineToPoint:CGPointMake(13, 8)];
		[lines moveToPoint:center];
		[lines addLineToPoint:CGPointMake(17, 17)];
		break;
	case 2: /* a stopwatch */
		[lines moveToPoint:CGPointMake(13, 4)];
		[lines addLineToPoint:CGPointMake(13, 1)];
		[lines moveToPoint:CGPointMake(10, 1)];
		[lines addLineToPoint:CGPointMake(16, 1)];
		[lines moveToPoint:center];
		[lines addLineToPoint:CGPointMake(17, 9)];
		break;
	default: /* a timer: a hand and quarter ticks */
		[lines moveToPoint:center];
		[lines addLineToPoint:CGPointMake(13, 7)];
		for (int i = 0; i < 4; i++) {
			CGFloat a = i * M_PI / 2;
			[lines moveToPoint:CGPointMake(13 + 10 * sin(a), 14 - 10 * cos(a))];
			[lines addLineToPoint:CGPointMake(13 + 7 * sin(a), 14 - 7 * cos(a))];
		}
		break;
	}
	[lines stroke];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static UIImage *MTCircle(UIColor *color, CGFloat diameter)
{
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), NO, 0);
	[color setFill];
	[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, diameter, diameter)] fill];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

/* The round Start/Stop/Lap buttons. */
static UIButton *MTRoundButton(id target, SEL action)
{
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = CGRectMake(0, 0, 84, 84);
	button.titleLabel.font = [UIFont systemFontOfSize:17];
	[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

static void MTStyleRoundButton(UIButton *button, NSString *title, UIColor *color, BOOL enabled)
{
	UIColor *background = [color colorWithAlphaComponent:0.2];
	[button setBackgroundImage:MTCircle(background, 84) forState:UIControlStateNormal];
	[button setTitle:title forState:UIControlStateNormal];
	[button setTitleColor:enabled ? color : [color colorWithAlphaComponent:0.4] forState:UIControlStateNormal];
	button.enabled = enabled;
}

#pragma mark - World Clock

static NSArray<NSString *> *MTDefaultZones(void)
{
	return @[ [[NSTimeZone systemTimeZone] name] ?: @"UTC", @"America/New_York", @"Europe/London", @"Asia/Tokyo" ];
}

static NSString *MTCityOfZone(NSString *name)
{
	return [[[name componentsSeparatedByString:@"/"] lastObject] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
}

/* "Today, +6HRS": the zone's day and its offset from here. */
static NSString *MTZoneDetail(NSTimeZone *zone, NSDate *now)
{
	NSCalendar *here = [NSCalendar currentCalendar];
	NSCalendar *there = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	there.timeZone = zone;
	NSDateComponents *a = [here components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:now];
	NSDateComponents *b = [there components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:now];
	NSInteger dayA = a.year * 400 + a.month * 32 + a.day, dayB = b.year * 400 + b.month * 32 + b.day;
	NSString *day = dayB > dayA ? @"Tomorrow" : dayB < dayA ? @"Yesterday" : @"Today";
	NSInteger offset = [zone secondsFromGMTForDate:now] - [[NSTimeZone systemTimeZone] secondsFromGMTForDate:now];
	if (offset == 0)
		return [day stringByAppendingString:@", +0HRS"];
	NSInteger hours = labs(offset) / 3600, minutes = labs(offset) / 60 % 60;
	NSString *amount = minutes ? [NSString stringWithFormat:@"%ld:%02ld", (long)hours, (long)minutes] : [NSString stringWithFormat:@"%ld", (long)hours];
	return [NSString stringWithFormat:@"%@, %@%@%@", day, offset > 0 ? @"+" : @"-", amount, hours == 1 && minutes == 0 ? @"HR" : @"HRS"];
}

@interface MTZonePickerController : UITableViewController <UITextFieldDelegate>
@property (nonatomic, copy) void (^picked)(NSString *zone);
@end

@implementation MTZonePickerController {
	NSArray<NSString *> *_all;
	NSArray<NSString *> *_shown;
	UITextField *_search;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = @"Choose a City";
	_all = [[NSTimeZone knownTimeZoneNames] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
		return [MTCityOfZone(a) localizedCaseInsensitiveCompare:MTCityOfZone(b)];
	}];
	_shown = _all;
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 52)];
	_search = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, self.view.bounds.size.width - 24, 36)];
	_search.placeholder = @"Search";
	_search.borderStyle = UITextBorderStyleRoundedRect;
	_search.autocorrectionType = UITextAutocorrectionTypeNo;
	_search.delegate = self;
	_search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[_search addTarget:self action:@selector(searchChanged) forControlEvents:UIControlEventEditingChanged];
	[header addSubview:_search];
	self.tableView.tableHeaderView = header;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchChanged)
	                                             name:UITextFieldTextDidChangeNotification object:_search];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)searchChanged
{
	NSString *text = _search.text;
	if ([text length] == 0) {
		_shown = _all;
	} else {
		NSPredicate *matches = [NSPredicate predicateWithBlock:^BOOL(NSString *zone, NSDictionary *bindings) {
			return [zone rangeOfString:text options:NSCaseInsensitiveSearch].location != NSNotFound
				|| [MTCityOfZone(zone) rangeOfString:text options:NSCaseInsensitiveSearch].location != NSNotFound;
		}];
		_shown = [_all filteredArrayUsingPredicate:matches];
	}
	[self.tableView reloadData];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_shown count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zone"]
		?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"zone"];
	NSString *zone = _shown[indexPath.row];
	NSArray *parts = [zone componentsSeparatedByString:@"/"];
	cell.textLabel.text = [parts count] > 1 ? [NSString stringWithFormat:@"%@, %@", MTCityOfZone(zone), parts[0]] : MTCityOfZone(zone);
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (self.picked)
		self.picked(_shown[indexPath.row]);
	[self.navigationController popViewControllerAnimated:YES];
}

@end

@interface MTWorldClockController : UITableViewController
@end

@implementation MTWorldClockController {
	NSMutableArray<NSString *> *_zones;
	NSTimer *_timer;
	NSString *_shownMinute;
}

- (instancetype)init
{
	if ((self = [super initWithStyle:UITableViewStylePlain])) {
		self.title = @"World Clock";
		self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"World Clock" image:MTTabIcon(0) tag:0];
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	NSArray *saved = [MTDefaults() arrayForKey:@"WorldClockZones"];
	_zones = [(saved ?: MTDefaultZones()) mutableCopy];
	self.tableView.rowHeight = 76;
	self.navigationItem.leftBarButtonItem = self.editButtonItem;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add)];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self.tableView reloadData];
	[_timer invalidate];
	_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[_timer invalidate];
	_timer = nil;
}

/* Redrawn when the minute changes. */
- (void)tick
{
	NSString *minute = MTTimeString([NSDate date], nil);
	if (![minute isEqual:_shownMinute]) {
		_shownMinute = minute;
		[self.tableView reloadData];
	}
}

- (void)save
{
	[MTDefaults() setObject:_zones forKey:@"WorldClockZones"];
}

- (void)add
{
	MTZonePickerController *picker = [[MTZonePickerController alloc] initWithStyle:UITableViewStylePlain];
	picker.picked = ^(NSString *zone) {
		if (![self->_zones containsObject:zone]) {
			[self->_zones addObject:zone];
			[self save];
		}
	};
	[self.navigationController pushViewController:picker animated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_zones count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"city"];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"city"];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.font = [UIFont systemFontOfSize:22];
		cell.detailTextLabel.textColor = [UIColor grayColor];
		UILabel *time = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 50)];
		time.font = [UIFont monospacedDigitSystemFontOfSize:36 weight:UIFontWeightLight];
		time.textAlignment = NSTextAlignmentRight;
		cell.accessoryView = time;
	}
	NSString *name = _zones[indexPath.row];
	NSTimeZone *zone = [NSTimeZone timeZoneWithName:name] ?: [NSTimeZone systemTimeZone];
	NSDate *now = [NSDate date];
	cell.textLabel.text = MTCityOfZone(name);
	cell.detailTextLabel.text = MTZoneDetail(zone, now);
	((UILabel *)cell.accessoryView).text = MTTimeString(now, zone);
	return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (style != UITableViewCellEditingStyleDelete)
		return;
	[_zones removeObjectAtIndex:indexPath.row];
	[self save];
	[tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end

#pragma mark - Alarms

@interface MTAlarm : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic) NSInteger hour;
@property (nonatomic) NSInteger minute;
@property (nonatomic, copy) NSString *label;
/* Weekdays it repeats on, 1 (Sunday) to 7; none: once. */
@property (nonatomic, copy) NSArray<NSNumber *> *days;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL snooze;
/* When a one-time alarm goes off; past it, the alarm turns itself off. */
@property (nonatomic, copy) NSDate *fireDate;
@end

@implementation MTAlarm

- (instancetype)init
{
	if ((self = [super init])) {
		_identifier = [[NSUUID UUID] UUIDString];
		_hour = 7;
		_label = @"Alarm";
		_days = @[];
		_enabled = YES;
		_snooze = YES;
	}
	return self;
}

+ (instancetype)alarmWithDictionary:(NSDictionary *)dictionary
{
	MTAlarm *alarm = [[self alloc] init];
	alarm.identifier = dictionary[@"identifier"] ?: alarm.identifier;
	alarm.hour = [dictionary[@"hour"] integerValue];
	alarm.minute = [dictionary[@"minute"] integerValue];
	alarm.label = dictionary[@"label"] ?: @"Alarm";
	alarm.days = dictionary[@"days"] ?: @[];
	alarm.enabled = [dictionary[@"enabled"] boolValue];
	alarm.snooze = dictionary[@"snooze"] ? [dictionary[@"snooze"] boolValue] : YES;
	alarm.fireDate = dictionary[@"fireDate"];
	return alarm;
}

- (NSDictionary *)dictionary
{
	NSMutableDictionary *dictionary = [@{ @"identifier": _identifier, @"hour": @(_hour), @"minute": @(_minute), @"label": _label ?: @"",
	                                      @"days": _days ?: @[], @"enabled": @(_enabled), @"snooze": @(_snooze) } mutableCopy];
	if (_fireDate != nil)
		dictionary[@"fireDate"] = _fireDate;
	return dictionary;
}

- (NSString *)repeatSummary
{
	NSSet *days = [NSSet setWithArray:_days];
	if ([days count] == 0)
		return @"Never";
	if ([days count] == 7)
		return @"Every day";
	if ([days isEqualToSet:[NSSet setWithArray:@[ @2, @3, @4, @5, @6 ]]])
		return @"Weekdays";
	if ([days isEqualToSet:[NSSet setWithArray:@[ @1, @7 ]]])
		return @"Weekends";
	NSArray *names = [[[NSDateFormatter alloc] init] shortWeekdaySymbols];
	NSMutableArray *picked = [NSMutableArray array];
	for (NSInteger day = 1; day <= 7; day++)
		if ([days containsObject:@(day)])
			[picked addObject:names[day - 1]];
	return [picked componentsJoinedByString:@" "];
}

- (NSString *)detail
{
	NSString *repeat = [self repeatSummary];
	return [repeat isEqual:@"Never"] ? _label : [NSString stringWithFormat:@"%@, %@", _label, [repeat lowercaseString]];
}

/* The notification identifiers it is scheduled under. */
- (NSString *)requestIdentifierForDay:(NSNumber *)day
{
	return day != nil ? [NSString stringWithFormat:@"alarm-%@-%@", _identifier, day] : [NSString stringWithFormat:@"alarm-%@", _identifier];
}

- (UNMutableNotificationContent *)content
{
	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.title = [_label length] > 0 ? _label : @"Alarm";
	content.body = MTHourMinute(_hour, _minute);
	content.sound = [UNNotificationSound defaultCriticalSound];
	content.categoryIdentifier = _snooze ? MTAlarmCategory : MTAlarmNoSnoozeCategory;
	content.interruptionLevel = UNNotificationInterruptionLevelCritical;
	content.userInfo = @{ @"alarm": _identifier };
	return content;
}

@end

@interface MTAlarmStore : NSObject
+ (NSMutableArray<MTAlarm *> *)alarms;
+ (void)saveAlarms:(NSArray<MTAlarm *> *)alarms;
+ (MTAlarm *)alarmWithIdentifier:(NSString *)identifier;
/* Turns off one-time alarms that have gone off. */
+ (void)expireAlarms;
@end

@implementation MTAlarmStore

+ (NSMutableArray<MTAlarm *> *)alarms
{
	NSMutableArray *alarms = [NSMutableArray array];
	for (NSDictionary *dictionary in [MTDefaults() arrayForKey:@"Alarms"])
		if ([dictionary isKindOfClass:[NSDictionary class]])
			[alarms addObject:[MTAlarm alarmWithDictionary:dictionary]];
	[alarms sortUsingComparator:^NSComparisonResult(MTAlarm *a, MTAlarm *b) {
		return [@(a.hour * 60 + a.minute) compare:@(b.hour * 60 + b.minute)];
	}];
	return alarms;
}

+ (MTAlarm *)alarmWithIdentifier:(NSString *)identifier
{
	for (MTAlarm *alarm in [self alarms])
		if ([alarm.identifier isEqual:identifier])
			return alarm;
	return nil;
}

/* Saves them and schedules the enabled ones: a repeating alarm once per
   weekday it repeats on, a one-time alarm once. */
+ (void)saveAlarms:(NSArray<MTAlarm *> *)alarms
{
	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
	NSMutableArray *requests = [NSMutableArray array];
	for (MTAlarm *alarm in alarms) {
		alarm.fireDate = nil;
		if (!alarm.enabled)
			continue;
		if ([alarm.days count] == 0) {
			NSDateComponents *components = [[NSDateComponents alloc] init];
			components.hour = alarm.hour;
			components.minute = alarm.minute;
			UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:NO];
			alarm.fireDate = [trigger nextTriggerDate];
			[requests addObject:[UNNotificationRequest requestWithIdentifier:[alarm requestIdentifierForDay:nil] content:[alarm content] trigger:trigger]];
		} else {
			for (NSNumber *day in alarm.days) {
				NSDateComponents *components = [[NSDateComponents alloc] init];
				components.weekday = [day integerValue];
				components.hour = alarm.hour;
				components.minute = alarm.minute;
				[requests addObject:[UNNotificationRequest requestWithIdentifier:[alarm requestIdentifierForDay:day] content:[alarm content]
					trigger:[UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:YES]]];
			}
		}
	}
	NSMutableArray *dictionaries = [NSMutableArray array];
	for (MTAlarm *alarm in alarms)
		[dictionaries addObject:[alarm dictionary]];
	[MTDefaults() setObject:dictionaries forKey:@"Alarms"];
	[MTDefaults() synchronize];

	[center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *pending) {
		NSMutableArray *stale = [NSMutableArray array];
		for (UNNotificationRequest *request in pending)
			if ([request.identifier hasPrefix:@"alarm-"])
				[stale addObject:request.identifier];
		[center removePendingNotificationRequestsWithIdentifiers:stale];
		for (UNNotificationRequest *request in requests)
			[center addNotificationRequest:request withCompletionHandler:^(NSError *error) {
				if (error != nil)
					NSLog(@"Clock: cannot schedule %@: %@", request.identifier, error);
			}];
	}];
}

+ (void)expireAlarms
{
	NSMutableArray *alarms = [self alarms];
	BOOL changed = NO;
	for (MTAlarm *alarm in alarms) {
		if (alarm.enabled && [alarm.days count] == 0 && alarm.fireDate != nil && [alarm.fireDate timeIntervalSinceNow] <= 0) {
			alarm.enabled = NO;
			changed = YES;
		}
	}
	if (changed) {
		/* saveAlarms: would reschedule; only the record changes. */
		NSMutableArray *dictionaries = [NSMutableArray array];
		for (MTAlarm *alarm in alarms)
			[dictionaries addObject:[alarm dictionary]];
		[MTDefaults() setObject:dictionaries forKey:@"Alarms"];
		MTStateChanged();
	}
}

@end

@interface MTRepeatController : UITableViewController
@property (nonatomic, strong) MTAlarm *alarm;
@end

@implementation MTRepeatController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = @"Repeat";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 7;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"day"]
		?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"day"];
	/* Weeks start on Monday in the list, as iOS shows them in most places. */
	NSInteger day = indexPath.row == 6 ? 1 : indexPath.row + 2;
	cell.textLabel.text = [NSString stringWithFormat:@"Every %@", [[[NSDateFormatter alloc] init] weekdaySymbols][day - 1]];
	cell.accessoryType = [self.alarm.days containsObject:@(day)] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	cell.tintColor = MTOrange();
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger day = indexPath.row == 6 ? 1 : indexPath.row + 2;
	NSMutableArray *days = [self.alarm.days mutableCopy];
	if ([days containsObject:@(day)])
		[days removeObject:@(day)];
	else
		[days addObject:@(day)];
	self.alarm.days = [days sortedArrayUsingSelector:@selector(compare:)];
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	[tableView reloadData];
}

@end

@interface MTAlarmEditController : UITableViewController <UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) MTAlarm *alarm;
@property (nonatomic) BOOL isNew;
@end

@implementation MTAlarmEditController {
	UIPickerView *_picker;
	UITextField *_labelField;
	UISwitch *_snooze;
}

- (instancetype)initWithAlarm:(MTAlarm *)alarm isNew:(BOOL)isNew
{
	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
		_alarm = alarm;
		_isNew = isNew;
		self.title = isNew ? @"Add Alarm" : @"Edit Alarm";
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)];

	_picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 216)];
	_picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_picker.dataSource = self;
	_picker.delegate = self;
	[_picker selectRow:_alarm.hour inComponent:0 animated:NO];
	[_picker selectRow:_alarm.minute inComponent:1 animated:NO];
	self.tableView.tableHeaderView = _picker;

	_labelField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
	_labelField.text = _alarm.label;
	_labelField.textAlignment = NSTextAlignmentRight;
	_labelField.textColor = [UIColor grayColor];
	_labelField.returnKeyType = UIReturnKeyDone;
	_labelField.delegate = self;
	_snooze = [[UISwitch alloc] init];
	_snooze.on = _alarm.snooze;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self.tableView reloadData];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
	return 2;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	return component == 0 ? 24 : 60;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	return [NSString stringWithFormat:@"%02ld", (long)row];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return _isNew ? 1 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return section == 0 ? 3 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
	if (indexPath.section == 1) {
		cell.textLabel.text = @"Delete Alarm";
		cell.textLabel.textColor = [UIColor redColor];
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
		return cell;
	}
	switch (indexPath.row) {
	case 0:
		cell.textLabel.text = @"Repeat";
		cell.detailTextLabel.text = [_alarm repeatSummary];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		break;
	case 1:
		cell.textLabel.text = @"Label";
		cell.accessoryView = _labelField;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		break;
	default:
		cell.textLabel.text = @"Snooze";
		cell.accessoryView = _snooze;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		break;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	if (indexPath.section == 1) {
		NSMutableArray *alarms = [MTAlarmStore alarms];
		for (NSInteger i = [alarms count] - 1; i >= 0; i--)
			if ([[alarms[i] identifier] isEqual:_alarm.identifier])
				[alarms removeObjectAtIndex:i];
		[MTAlarmStore saveAlarms:alarms];
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}
	if (indexPath.row == 0) {
		MTRepeatController *repeat = [[MTRepeatController alloc] initWithStyle:UITableViewStyleGrouped];
		repeat.alarm = _alarm;
		[self.navigationController pushViewController:repeat animated:YES];
	} else if (indexPath.row == 1) {
		[_labelField becomeFirstResponder];
	}
}

- (void)cancel
{
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)save
{
	[_labelField resignFirstResponder];
	_alarm.hour = [_picker selectedRowInComponent:0];
	_alarm.minute = [_picker selectedRowInComponent:1];
	_alarm.label = [_labelField.text length] > 0 ? _labelField.text : @"Alarm";
	_alarm.snooze = _snooze.on;
	_alarm.enabled = YES;
	NSMutableArray *alarms = [MTAlarmStore alarms];
	for (NSInteger i = [alarms count] - 1; i >= 0; i--)
		if ([[alarms[i] identifier] isEqual:_alarm.identifier])
			[alarms removeObjectAtIndex:i];
	[alarms addObject:_alarm];
	[MTAlarmStore saveAlarms:alarms];
	[self.navigationController popViewControllerAnimated:YES];
}

@end

@interface MTAlarmsController : UITableViewController
@end

@implementation MTAlarmsController {
	NSMutableArray<MTAlarm *> *_alarms;
}

- (instancetype)init
{
	if ((self = [super initWithStyle:UITableViewStylePlain])) {
		self.title = @"Alarm";
		self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Alarm" image:MTTabIcon(1) tag:1];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:MTStateDidChangeNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.tableView.rowHeight = 84;
	self.navigationItem.leftBarButtonItem = self.editButtonItem;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add)];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self reload];
}

- (void)reload
{
	_alarms = [MTAlarmStore alarms];
	[self.tableView reloadData];
}

- (void)add
{
	[self.navigationController pushViewController:[[MTAlarmEditController alloc] initWithAlarm:[[MTAlarm alloc] init] isNew:YES] animated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_alarms count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"alarm"];
	/* The time is too tall for the subtitle style's labels: it has its own. */
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"alarm"];
		UILabel *time = [[UILabel alloc] initWithFrame:CGRectMake(16, 6, 240, 50)];
		time.tag = 1;
		time.font = [UIFont monospacedDigitSystemFontOfSize:44 weight:UIFontWeightLight];
		[cell.contentView addSubview:time];
		UILabel *detail = [[UILabel alloc] initWithFrame:CGRectMake(16, 56, 240, 20)];
		detail.tag = 2;
		detail.font = [UIFont systemFontOfSize:15];
		[cell.contentView addSubview:detail];
		UISwitch *toggle = [[UISwitch alloc] init];
		[toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
	}
	MTAlarm *alarm = _alarms[indexPath.row];
	UILabel *time = (UILabel *)[cell.contentView viewWithTag:1];
	UILabel *detail = (UILabel *)[cell.contentView viewWithTag:2];
	time.text = MTHourMinute(alarm.hour, alarm.minute);
	detail.text = [alarm detail];
	UIColor *color = alarm.enabled ? [UIColor blackColor] : [UIColor grayColor];
	time.textColor = color;
	detail.textColor = color;
	UISwitch *toggle = (UISwitch *)cell.accessoryView;
	toggle.on = alarm.enabled;
	toggle.tag = indexPath.row;
	return cell;
}

- (void)toggled:(UISwitch *)toggle
{
	if (toggle.tag >= (NSInteger)[_alarms count])
		return;
	_alarms[toggle.tag].enabled = toggle.on;
	[MTAlarmStore saveAlarms:_alarms];
	[self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	[self.navigationController pushViewController:[[MTAlarmEditController alloc] initWithAlarm:_alarms[indexPath.row] isNew:NO] animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (style != UITableViewCellEditingStyleDelete)
		return;
	[_alarms removeObjectAtIndex:indexPath.row];
	[MTAlarmStore saveAlarms:_alarms];
	[tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end

#pragma mark - Stopwatch

@interface MTStopwatchController : UIViewController <UITableViewDataSource>
@end

@implementation MTStopwatchController {
	UILabel *_time;
	UIButton *_left;
	UIButton *_right;
	UITableView *_laps;
	NSTimer *_timer;
}

- (instancetype)init
{
	if ((self = [super init])) {
		self.title = @"Stopwatch";
		self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Stopwatch" image:MTTabIcon(2) tag:2];
	}
	return self;
}

/* The state is the start of the running stretch, the time before it,
   and the lap totals: enough to carry on while the app is gone. */
- (NSDate *)start { return [MTDefaults() objectForKey:@"StopwatchStart"]; }
- (NSTimeInterval)before { return [MTDefaults() doubleForKey:@"StopwatchElapsed"]; }
- (NSArray<NSNumber *> *)lapTotals { return [MTDefaults() arrayForKey:@"StopwatchLaps"] ?: @[]; }

- (NSTimeInterval)elapsed
{
	NSDate *start = [self start];
	return [self before] + (start != nil ? -[start timeIntervalSinceNow] : 0);
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor whiteColor];
	CGFloat width = self.view.bounds.size.width;

	_time = [[UILabel alloc] initWithFrame:CGRectMake(0, 40, width, 100)];
	_time.font = [UIFont monospacedDigitSystemFontOfSize:64 weight:UIFontWeightThin];
	_time.textAlignment = NSTextAlignmentCenter;
	_time.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:_time];

	_left = MTRoundButton(self, @selector(leftPressed));
	_left.frame = CGRectMake(20, 160, 84, 84);
	[self.view addSubview:_left];
	_right = MTRoundButton(self, @selector(rightPressed));
	_right.frame = CGRectMake(width - 104, 160, 84, 84);
	_right.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[self.view addSubview:_right];

	_laps = [[UITableView alloc] initWithFrame:CGRectMake(0, 260, width, self.view.bounds.size.height - 260) style:UITableViewStylePlain];
	_laps.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_laps.dataSource = self;
	_laps.allowsSelection = NO;
	[self.view addSubview:_laps];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self update];
	[_timer invalidate];
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[_timer invalidate];
	_timer = nil;
}

- (void)tick
{
	if ([self start] == nil)
		return;
	_time.text = MTDuration([self elapsed], YES);
	UITableViewCell *current = [_laps cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	NSNumber *last = [[self lapTotals] lastObject];
	current.detailTextLabel.text = MTDuration([self elapsed] - [last doubleValue], YES);
}

- (void)update
{
	BOOL running = [self start] != nil;
	NSTimeInterval elapsed = [self elapsed];
	_time.text = MTDuration(elapsed, YES);
	UIColor *gray = [UIColor darkGrayColor];
	if (running)
		MTStyleRoundButton(_left, @"Lap", gray, YES);
	else
		MTStyleRoundButton(_left, elapsed > 0 ? @"Reset" : @"Lap", gray, elapsed > 0);
	MTStyleRoundButton(_right, running ? @"Stop" : @"Start",
		running ? [UIColor colorWithRed:1 green:0.23 blue:0.19 alpha:1] : [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1], YES);
	[_laps reloadData];
}

- (void)leftPressed
{
	if ([self start] != nil) {
		[MTDefaults() setObject:[[self lapTotals] arrayByAddingObject:@([self elapsed])] forKey:@"StopwatchLaps"];
	} else {
		[MTDefaults() removeObjectForKey:@"StopwatchElapsed"];
		[MTDefaults() removeObjectForKey:@"StopwatchLaps"];
	}
	[self update];
}

- (void)rightPressed
{
	if ([self start] != nil) {
		[MTDefaults() setDouble:[self elapsed] forKey:@"StopwatchElapsed"];
		[MTDefaults() removeObjectForKey:@"StopwatchStart"];
	} else {
		[MTDefaults() setObject:[NSDate date] forKey:@"StopwatchStart"];
	}
	[self update];
}

/* The lap under way first, then the finished ones, newest first. */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self elapsed] > 0 ? [[self lapTotals] count] + 1 : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"lap"]
		?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"lap"];
	NSArray<NSNumber *> *totals = [self lapTotals];
	NSInteger lap = [totals count] - indexPath.row; /* 0-based */
	NSTimeInterval end = lap == (NSInteger)[totals count] ? [self elapsed] : [totals[lap] doubleValue];
	NSTimeInterval begin = lap > 0 ? [totals[lap - 1] doubleValue] : 0;
	cell.textLabel.text = [NSString stringWithFormat:@"Lap %ld", (long)lap + 1];
	cell.detailTextLabel.text = MTDuration(end - begin, YES);
	cell.detailTextLabel.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightRegular];
	return cell;
}

@end

#pragma mark - Timer

@interface MTTimerController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate>
@end

@implementation MTTimerController {
	UIPickerView *_picker;
	UILabel *_remaining;
	UIButton *_cancel;
	UIButton *_start;
	NSTimer *_timer;
	/* What the buttons show: -1 none yet, 0 idle, 1 paused, 2 running. */
	NSInteger _shownState;
}

- (instancetype)init
{
	if ((self = [super init])) {
		self.title = @"Timer";
		self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Timer" image:MTTabIcon(3) tag:3];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update) name:MTStateDidChangeNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/* Running: when it ends. Paused: what is left. Neither: idle. */
- (NSDate *)end { return [MTDefaults() objectForKey:@"TimerEnd"]; }
- (NSTimeInterval)paused { return [MTDefaults() doubleForKey:@"TimerRemaining"]; }

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor whiteColor];
	CGFloat width = self.view.bounds.size.width;
	_shownState = -1;

	_picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 20, width, 216)];
	_picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_picker.dataSource = self;
	_picker.delegate = self;
	NSInteger duration = [MTDefaults() integerForKey:@"TimerDuration"] ?: 5 * 60;
	[_picker selectRow:duration / 3600 inComponent:0 animated:NO];
	[_picker selectRow:duration / 60 % 60 inComponent:1 animated:NO];
	[_picker selectRow:duration % 60 inComponent:2 animated:NO];
	[self.view addSubview:_picker];

	_remaining = [[UILabel alloc] initWithFrame:CGRectMake(0, 70, width, 100)];
	_remaining.font = [UIFont monospacedDigitSystemFontOfSize:72 weight:UIFontWeightThin];
	_remaining.textAlignment = NSTextAlignmentCenter;
	_remaining.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:_remaining];

	_cancel = MTRoundButton(self, @selector(cancelPressed));
	_cancel.frame = CGRectMake(20, 260, 84, 84);
	[self.view addSubview:_cancel];
	_start = MTRoundButton(self, @selector(startPressed));
	_start.frame = CGRectMake(width - 104, 260, 84, 84);
	_start.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[self.view addSubview:_start];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self update];
	[_timer invalidate];
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(update) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[_timer invalidate];
	_timer = nil;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
	return 3;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	return component == 0 ? 24 : 60;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	NSArray *units = @[ row == 1 ? @"hour" : @"hours", @"min", @"sec" ];
	return [NSString stringWithFormat:@"%ld %@", (long)row, units[component]];
}

- (void)update
{
	NSDate *end = [self end];
	if (end != nil && [end timeIntervalSinceNow] <= 0) {
		/* Done: the notification rings it. */
		[MTDefaults() removeObjectForKey:@"TimerEnd"];
		end = nil;
	}
	NSTimeInterval paused = [self paused];
	BOOL active = end != nil || paused > 0;
	if (active) {
		NSString *remaining = MTDuration(end != nil ? ceil([end timeIntervalSinceNow]) : paused, NO);
		if (![remaining isEqual:_remaining.text])
			_remaining.text = remaining;
	}
	/* The rest changes only with the state; redrawing it every tick is
	   wasted work on a slow display. */
	NSInteger state = end != nil ? 2 : paused > 0 ? 1 : 0;
	if (state == _shownState)
		return;
	_shownState = state;
	_picker.hidden = active;
	_remaining.hidden = !active;
	MTStyleRoundButton(_cancel, @"Cancel", [UIColor darkGrayColor], active);
	if (state == 2)
		MTStyleRoundButton(_start, @"Pause", MTOrange(), YES);
	else
		MTStyleRoundButton(_start, state == 1 ? @"Resume" : @"Start", [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1], YES);
}

- (void)scheduleIn:(NSTimeInterval)seconds
{
	[MTDefaults() setObject:[NSDate dateWithTimeIntervalSinceNow:seconds] forKey:@"TimerEnd"];
	[MTDefaults() removeObjectForKey:@"TimerRemaining"];
	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.title = @"Timer";
	content.body = @"Timer Done";
	content.sound = [UNNotificationSound defaultCriticalSound];
	content.categoryIdentifier = MTTimerCategory;
	content.interruptionLevel = UNNotificationInterruptionLevelCritical;
	UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:MTTimerRequest content:content
		trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:seconds repeats:NO]];
	[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
}

- (void)startPressed
{
	NSDate *end = [self end];
	if (end != nil) {
		[MTDefaults() setDouble:MAX([end timeIntervalSinceNow], 1) forKey:@"TimerRemaining"];
		[MTDefaults() removeObjectForKey:@"TimerEnd"];
		[[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[ MTTimerRequest ]];
	} else if ([self paused] > 0) {
		[self scheduleIn:[self paused]];
	} else {
		NSInteger duration = [_picker selectedRowInComponent:0] * 3600 + [_picker selectedRowInComponent:1] * 60 + [_picker selectedRowInComponent:2];
		if (duration <= 0)
			return;
		[MTDefaults() setInteger:duration forKey:@"TimerDuration"];
		[self scheduleIn:duration];
	}
	[self update];
}

- (void)cancelPressed
{
	[MTDefaults() removeObjectForKey:@"TimerEnd"];
	[MTDefaults() removeObjectForKey:@"TimerRemaining"];
	[[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[ MTTimerRequest ]];
	[self update];
}

@end

#pragma mark - Application

@interface MTAppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate, UITabBarControllerDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITabBarController *tabs;
@end

@implementation MTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
	center.delegate = self;
	[center requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionCriticalAlert
	                      completionHandler:^(BOOL granted, NSError *error) {}];
	UNNotificationAction *snooze = [UNNotificationAction actionWithIdentifier:MTSnoozeAction title:@"Snooze" options:UNNotificationActionOptionNone];
	[center setNotificationCategories:[NSSet setWithObjects:
		[UNNotificationCategory categoryWithIdentifier:MTAlarmCategory actions:@[ snooze ] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction],
		[UNNotificationCategory categoryWithIdentifier:MTAlarmNoSnoozeCategory actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction],
		[UNNotificationCategory categoryWithIdentifier:MTTimerCategory actions:@[] intentIdentifiers:@[] options:0],
		nil]];

	NSMutableArray *controllers = [NSMutableArray array];
	for (UIViewController *controller in @[ [[MTWorldClockController alloc] init], [[MTAlarmsController alloc] init],
	                                        [[MTStopwatchController alloc] init], [[MTTimerController alloc] init] ]) {
		UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
		navigation.tabBarItem = controller.tabBarItem;
		[controllers addObject:navigation];
	}
	self.tabs = [[UITabBarController alloc] init];
	self.tabs.viewControllers = controllers;
	self.tabs.delegate = self;
	self.tabs.selectedIndex = MIN((NSUInteger)[MTDefaults() integerForKey:@"SelectedTab"], [controllers count] - 1);
	self.tabs.tabBar.tintColor = MTOrange();

	self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	self.window.tintColor = MTOrange();
	self.window.rootViewController = self.tabs;
	[self.window makeKeyAndVisible];
	return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	[MTAlarmStore expireAlarms];
	MTStateChanged();
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
	[MTDefaults() setInteger:tabBarController.selectedIndex forKey:@"SelectedTab"];
}

/* In front, alarms and the timer still ring. */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
	completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionList);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		[MTAlarmStore expireAlarms];
		MTStateChanged();
	});
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
	UNNotificationContent *content = response.notification.request.content;
	NSString *alarm = content.userInfo[@"alarm"];
	if ([response.actionIdentifier isEqual:MTSnoozeAction] && alarm != nil) {
		/* Rings again in nine minutes, as iOS's does. */
		UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[@"snooze-" stringByAppendingString:alarm] content:content
			trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:MTSnoozeInterval repeats:NO]];
		[center addNotificationRequest:request withCompletionHandler:nil];
	} else if ([response.actionIdentifier isEqual:UNNotificationDefaultActionIdentifier]) {
		self.tabs.selectedIndex = alarm != nil ? 1 : 3;
		[MTDefaults() setInteger:self.tabs.selectedIndex forKey:@"SelectedTab"];
	}
	[MTAlarmStore expireAlarms];
	MTStateChanged();
	completionHandler();
}

@end

int main(int argc, char *argv[])
{
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([MTAppDelegate class]));
	}
}
