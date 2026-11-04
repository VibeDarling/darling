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

/* Notifications: SpringBoard is usernotificationsd's presenter. Each one
   the daemon sends is shown in a window of its own at the top of the
   screen, at alert level, so it stays in front of whichever app is there.
   A banner goes away by itself after a few seconds; tapping it opens its
   app, swiping it up dismisses it. One with a critical sound, which is how
   alarms ask for attention, stays as an alert with its category's actions
   and a Stop button, and rings until one of them is pressed. What the user
   chose goes back to the daemon, which tells the app. */

#import <UIKit/UIKit.h>
#import <DarlingBoard/DarlingBoard.h>
#import <UserNotifications/UserNotifications.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSColor.h>
#include <CoreAudio/CoreAudioTypes.h>
#import "SpringBoard.h"
#import "UNLite.h"
#include <pthread.h>
#include <unistd.h>
#include <math.h>

static const NSTimeInterval SBBannerDuration = 5;
static const CGFloat SBBannerMargin = 8;
static const CGFloat SBBannerHeight = 76;
static const CGFloat SBAlertButtonHeight = 44;
/* An alert rings again this often. */
static const NSTimeInterval SBAlertRingInterval = 2;

#pragma mark - Sounds

/* Sounds are synthesized: a two-note chime for banners, a run of beeps for
   alerts. Each plays once through an Audio Queue of its own. */
static const Float64 SBSampleRate = 44100;

/* AudioToolbox's Audio Queue API: Darling's own AudioQueue.h is C++. */
typedef struct OpaqueAudioQueue *AudioQueueRef;
typedef struct AudioQueueBuffer {
	const UInt32 mAudioDataBytesCapacity;
	void *mAudioData;
	UInt32 mAudioDataByteSize;
	void *mUserData;
	const UInt32 mPacketDescriptionCapacity;
	AudioStreamPacketDescription *const mPacketDescriptions;
	UInt32 mPacketDescriptionCount;
} *AudioQueueBufferRef;
typedef void (*AudioQueueOutputCallback)(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer);
extern OSStatus AudioQueueNewOutput(const AudioStreamBasicDescription *format, AudioQueueOutputCallback callback, void *userData,
	CFRunLoopRef runLoop, CFStringRef runLoopMode, UInt32 flags, AudioQueueRef *queue);
extern OSStatus AudioQueueAllocateBuffer(AudioQueueRef queue, UInt32 size, AudioQueueBufferRef *buffer);
extern OSStatus AudioQueueEnqueueBuffer(AudioQueueRef queue, AudioQueueBufferRef buffer, UInt32 packets, const AudioStreamPacketDescription *descriptions);
extern OSStatus AudioQueueStart(AudioQueueRef queue, const AudioTimeStamp *start);
extern OSStatus AudioQueueStop(AudioQueueRef queue, Boolean immediate);
extern OSStatus AudioQueueDispose(AudioQueueRef queue, Boolean immediate);

static NSData *SBSynthesize(BOOL alert, float volume)
{
	NSMutableData *data = [NSMutableData data];
	void (^tone)(double, double, double) = ^(double frequency, double seconds, double decay) {
		NSUInteger count = (NSUInteger)(seconds * SBSampleRate);
		for (NSUInteger i = 0; i < count; i++) {
			double t = i / SBSampleRate;
			double envelope = exp(-t * decay) * MIN(1.0, t * 400);
			double sample = (sin(2 * M_PI * frequency * t) + 0.3 * sin(4 * M_PI * frequency * t)) / 1.3;
			int16_t value = (int16_t)(sample * envelope * volume * 0.6 * INT16_MAX);
			[data appendBytes:&value length:sizeof(value)];
		}
	};
	if (alert) {
		for (int i = 0; i < 4; i++) {
			tone(1760, 0.12, 6);
			tone(0, 0.06, 0);
		}
	} else {
		tone(1318.5, 0.18, 9);
		tone(987.8, 0.45, 6);
	}
	return data;
}

static void SBSoundFinished(void *context, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
	/* Played once: the queue goes when it has run dry. */
	AudioQueueStop(queue, false);
	dispatch_async(dispatch_get_main_queue(), ^{
		AudioQueueDispose(queue, true);
	});
}

static void SBPlaySound(BOOL alert, float volume)
{
	NSData *samples = SBSynthesize(alert, volume > 0 ? volume : 1);
	AudioStreamBasicDescription format = {
		.mSampleRate = SBSampleRate,
		.mFormatID = kAudioFormatLinearPCM,
		.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
		.mBytesPerPacket = 2,
		.mFramesPerPacket = 1,
		.mBytesPerFrame = 2,
		.mChannelsPerFrame = 1,
		.mBitsPerChannel = 16,
	};
	AudioQueueRef queue;
	OSStatus status = AudioQueueNewOutput(&format, SBSoundFinished, NULL, NULL, NULL, 0, &queue);
	if (status != noErr) {
		SBLog(@"cannot play a sound: AudioQueueNewOutput %d", (int)status);
		return;
	}
	AudioQueueBufferRef buffer;
	if (AudioQueueAllocateBuffer(queue, (UInt32)[samples length], &buffer) != noErr) {
		AudioQueueDispose(queue, true);
		return;
	}
	memcpy(buffer->mAudioData, [samples bytes], [samples length]);
	buffer->mAudioDataByteSize = (UInt32)[samples length];
	AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
	status = AudioQueueStart(queue, NULL);
	if (status != noErr) {
		SBLog(@"cannot play a sound: AudioQueueStart %d", (int)status);
		AudioQueueDispose(queue, true);
	}
}

#pragma mark - The banner

@class SBNotificationView;

@protocol SBNotificationViewDelegate <NSObject>
- (void)notificationView:(SBNotificationView *)view didChooseAction:(NSString *)action;
@end

@interface SBNotificationView : UIView
@property (nonatomic, weak) id<SBNotificationViewDelegate> delegate;
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSDictionary *notification;
@property (nonatomic) BOOL isAlert;
- (instancetype)initWithEvent:(NSDictionary *)event width:(CGFloat)width;
@end

@implementation SBNotificationView {
	CGPoint _touchStart;
	NSArray<NSDictionary *> *_buttons;
}

static UILabel *SBLabel(CGRect frame, UIFont *font, UIColor *color, NSString *text)
{
	UILabel *label = [[UILabel alloc] initWithFrame:frame];
	label.font = font;
	label.textColor = color;
	label.text = text;
	return label;
}

- (instancetype)initWithEvent:(NSDictionary *)event width:(CGFloat)width
{
	NSDictionary *notification = event[@"notification"];
	NSDictionary *content = notification[@"request"][@"content"];
	NSDictionary *sound = content[@"sound"];
	/* Shown as an alert: a critical sound that the app wants played. */
	BOOL alert = [sound[@"critical"] boolValue] && ([event[@"options"] unsignedIntegerValue] & UNNotificationPresentationOptionSound);
	NSMutableArray *buttons = [NSMutableArray array];
	if (alert) {
		for (NSDictionary *action in event[@"actions"])
			if ([action isKindOfClass:[NSDictionary class]])
				[buttons addObject:action];
		[buttons addObject:@{ @"identifier": UNNotificationDismissActionIdentifier, @"title": @"Stop" }];
	}
	CGFloat height = SBBannerHeight + (alert ? SBAlertButtonHeight : 0);
	if ((self = [super initWithFrame:CGRectMake(0, 0, width, height)])) {
		_bundleIdentifier = [event[@"bundleIdentifier"] copy];
		_notification = [notification copy];
		_isAlert = alert;
		_buttons = buttons;

		NSBundle *bundle = [[DBApplicationService sharedService] bundleForApplication:_bundleIdentifier];
		SBApplication *application = bundle != nil ? [SBApplication applicationWithBundle:bundle] : nil;
		NSString *appName = application.displayName ?: [[_bundleIdentifier componentsSeparatedByString:@"."] lastObject];

		UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 20, 20)];
		icon.image = application.icon;
		[self addSubview:icon];
		UIColor *secondary = [UIColor colorWithWhite:0.4 alpha:1];
		[self addSubview:SBLabel(CGRectMake(40, 10, width - 120, 20), [UIFont systemFontOfSize:13], secondary, [appName uppercaseString])];
		UILabel *when = SBLabel(CGRectMake(width - 72, 10, 60, 20), [UIFont systemFontOfSize:13], secondary, @"now");
		when.textAlignment = NSTextAlignmentRight;
		[self addSubview:when];

		NSString *title = [content[@"title"] length] > 0 ? content[@"title"] : appName;
		NSString *body = content[@"body"] ?: @"";
		if ([content[@"subtitle"] length] > 0)
			body = [NSString stringWithFormat:@"%@ — %@", content[@"subtitle"], body];
		[self addSubview:SBLabel(CGRectMake(12, 32, width - 24, 20), [UIFont boldSystemFontOfSize:15], [UIColor blackColor], title)];
		[self addSubview:SBLabel(CGRectMake(12, 52, width - 24, 20), [UIFont systemFontOfSize:15], [UIColor blackColor], body)];

		CGFloat buttonWidth = (width - 24) / MAX([buttons count], 1u);
		for (NSUInteger i = 0; i < [buttons count]; i++) {
			UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
			button.frame = CGRectMake(12 + i * buttonWidth, SBBannerHeight, buttonWidth, SBAlertButtonHeight - 6);
			button.tag = i;
			[button setTitle:buttons[i][@"title"] forState:UIControlStateNormal];
			BOOL destructive = ([buttons[i][@"options"] unsignedIntegerValue] & UNNotificationActionOptionDestructive) != 0;
			if (destructive || [buttons[i][@"identifier"] isEqual:UNNotificationDismissActionIdentifier])
				[button setTitleColor:[UIColor colorWithRed:1 green:0.23 blue:0.19 alpha:1] forState:UIControlStateNormal];
			button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
			[button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
			[self addSubview:button];
		}
	}
	return self;
}

- (BOOL)isOpaque
{
	return NO;
}

- (void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGRect bounds = [self bounds];
	CGContextSetRGBFillColor(context, 0.96, 0.96, 0.97, 1);
	SBAddRoundedRect(context, CGRectInset(bounds, 0.5, 0.5), 14);
	CGContextFillPath(context);
	if (_isAlert) {
		CGContextSetRGBFillColor(context, 0.82, 0.82, 0.84, 1);
		CGContextFillRect(context, CGRectMake(12, SBBannerHeight - 4, bounds.size.width - 24, 0.5));
	}
}

- (void)buttonPressed:(UIButton *)button
{
	[_delegate notificationView:self didChooseAction:_buttons[button.tag][@"identifier"]];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	_touchStart = [[touches anyObject] locationInView:self];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	CGPoint end = [[touches anyObject] locationInView:self];
	if (_touchStart.y - end.y > 20) {
		/* Swiped away: a banner just goes; an alert has its Stop button. */
		if (!_isAlert)
			[_delegate notificationView:self didChooseAction:nil];
	} else if (fabs(end.x - _touchStart.x) < 12 && fabs(end.y - _touchStart.y) < 12) {
		[_delegate notificationView:self didChooseAction:UNNotificationDefaultActionIdentifier];
	}
}

@end

#pragma mark - The presenter

@interface SBNotificationPresenter () <SBNotificationViewDelegate>
@end

@implementation SBNotificationPresenter {
	UIWindow *_window;
	SBNotificationView *_current;
	NSMutableArray<NSDictionary *> *_waiting;
	NSTimer *_timer;
}

+ (instancetype)sharedPresenter
{
	static SBNotificationPresenter *presenter;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		presenter = [[self alloc] init];
	});
	return presenter;
}

static void *SBPresenterThread(void *unused)
{
	unsigned int wait = 1;
	for (;;) {
		@autoreleasepool {
			int fd = UNLiteConnect();
			if (fd >= 0 && UNLiteSend(fd, @{ @"op": @"presenter" })) {
				SBLog(@"presenting usernotificationsd's notifications");
				wait = 1;
				NSDictionary *event;
				while ((event = UNLiteReceive(fd)) != nil) {
					dispatch_async(dispatch_get_main_queue(), ^{
						[[SBNotificationPresenter sharedPresenter] handleEvent:event];
					});
				}
			}
			if (fd >= 0)
				close(fd);
		}
		sleep(wait);
		wait = MIN(wait * 2, 30u);
	}
	return NULL;
}

- (void)start
{
	_waiting = [NSMutableArray array];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	pthread_t thread;
	pthread_create(&thread, NULL, SBPresenterThread, NULL);
	pthread_detach(thread);
}

- (void)handleEvent:(NSDictionary *)event
{
	NSString *op = event[@"op"];
	if ([op isEqualToString:@"show"]) {
		SBLog(@"notification from %@: %@", event[@"bundleIdentifier"], event[@"notification"][@"request"][@"identifier"]);
		[_waiting addObject:event];
		if (_current == nil)
			[self showNext];
	} else if ([op isEqualToString:@"withdraw"]) {
		NSArray *identifiers = event[@"identifiers"];
		NSString *bundleIdentifier = event[@"bundleIdentifier"];
		BOOL (^withdrawn)(NSString *, NSDictionary *) = ^BOOL(NSString *bundle, NSDictionary *notification) {
			return [bundle isEqual:bundleIdentifier] && [identifiers containsObject:notification[@"request"][@"identifier"] ?: @""];
		};
		for (NSInteger i = [_waiting count] - 1; i >= 0; i--)
			if (withdrawn(_waiting[i][@"bundleIdentifier"], _waiting[i][@"notification"]))
				[_waiting removeObjectAtIndex:i];
		if (_current != nil && withdrawn(_current.bundleIdentifier, _current.notification)) {
			SBLog(@"%@ withdrew %@", bundleIdentifier, _current.notification[@"request"][@"identifier"]);
			[self dismissCurrent];
		}
	}
}

- (CGRect)frameForHeight:(CGFloat)height
{
	CGRect screen = [[UIScreen mainScreen] bounds];
	CGFloat top = MAX(UIKitHostSafeAreaInsets().top, 24) + 4;
	CGFloat width = MIN(screen.size.width - 2 * SBBannerMargin, 500);
	return CGRectMake(floor((screen.size.width - width) / 2), top, width, height);
}

- (void)showNext
{
	if ([_waiting count] == 0)
		return;
	NSDictionary *event = _waiting[0];
	[_waiting removeObjectAtIndex:0];

	CGRect frame = [self frameForHeight:SBBannerHeight];
	SBNotificationView *view = [[SBNotificationView alloc] initWithEvent:event width:frame.size.width];
	view.delegate = self;
	frame.size.height = view.frame.size.height;

	_window = [[UIWindow alloc] initWithFrame:frame];
	NSWindow *host = [_window valueForKey:@"_hostWindow"];
	[host setOpaque:NO];
	[host setBackgroundColor:[NSColor clearColor]];
	_window.windowLevel = UIWindowLevelAlert;
	[_window addSubview:view];
	_current = view;
	[_window setHidden:NO];

	NSUInteger options = [event[@"options"] unsignedIntegerValue];
	NSDictionary *sound = event[@"notification"][@"request"][@"content"][@"sound"];
	BOOL plays = (options & UNNotificationPresentationOptionSound) && [sound isKindOfClass:[NSDictionary class]];
	if (plays)
		SBPlaySound(view.isAlert, [sound[@"volume"] floatValue]);

	if (view.isAlert) {
		_timer = [NSTimer scheduledTimerWithTimeInterval:SBAlertRingInterval repeats:YES block:^(NSTimer *timer) {
			if (plays)
				SBPlaySound(YES, [sound[@"volume"] floatValue]);
		}];
	} else {
		_timer = [NSTimer scheduledTimerWithTimeInterval:SBBannerDuration repeats:NO block:^(NSTimer *timer) {
			[self dismissCurrent];
		}];
	}
}

- (void)dismissCurrent
{
	[_timer invalidate];
	_timer = nil;
	[_window setHidden:YES];
	_window = nil;
	_current = nil;
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self->_current == nil)
			[self showNext];
	});
}

/* SpringBoard's windows leave the screen with it when an app comes to the
   front; the notification's must not. */
- (void)didEnterBackground:(NSNotification *)notification
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self->_window != nil)
			[self->_window setHidden:NO];
	});
}

- (void)notificationView:(SBNotificationView *)view didChooseAction:(NSString *)action
{
	NSString *bundleIdentifier = view.bundleIdentifier;
	NSDictionary *notification = view.notification;
	NSString *identifier = notification[@"request"][@"identifier"];
	[self dismissCurrent];
	if (action == nil)
		return;
	SBLog(@"%@: %@ answered with %@", bundleIdentifier, identifier, action);

	/* Opening it brings its app to the front; an action without
	   UNNotificationActionOptionForeground wakes the app in the background. */
	BOOL foreground = [action isEqual:UNNotificationDefaultActionIdentifier];
	BOOL launch = foreground;
	for (NSDictionary *candidate in [self actionsOfNotificationView:view])
		if ([candidate[@"identifier"] isEqual:action]) {
			launch = YES;
			foreground = ([candidate[@"options"] unsignedIntegerValue] & UNNotificationActionOptionForeground) != 0;
		}

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		UNLiteRequest(@{ @"op": @"respond", @"bundleIdentifier": bundleIdentifier, @"identifier": identifier,
		                 @"action": action, @"notification": notification });
		if (!launch)
			return;
		NSDictionary *options = foreground ? nil : @{ DBOpenApplicationOptionSuspended: @YES };
		[[DBApplicationService sharedService] openApplication:bundleIdentifier options:options completion:^(NSError *error) {
			if (error != nil)
				SBLog(@"cannot open %@: %@", bundleIdentifier, [error localizedFailureReason] ?: error);
		}];
	});
}

- (NSArray<NSDictionary *> *)actionsOfNotificationView:(SBNotificationView *)view
{
	return [view valueForKey:@"_buttons"];
}

@end
