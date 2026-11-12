/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UILOCALNOTIFICATION_H
#define UIKIT_UILOCALNOTIFICATION_H

#import <Foundation/Foundation.h>

extern NSString *const UILocalNotificationDefaultSoundName;

/*
 * iOS 4's local notifications. They are scheduled as UserNotifications
 * requests, so usernotificationsd delivers them and SpringBoard shows
 * them; one that arrives while the app is in front goes to the app
 * delegate's application:didReceiveLocalNotification:, unless the app
 * has its own UNUserNotificationCenter delegate.
 */
@interface UILocalNotification : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, copy) NSDate *fireDate;
@property (nonatomic, copy) NSTimeZone *timeZone;
@property (nonatomic) NSCalendarUnit repeatInterval;
@property (nonatomic, copy) NSCalendar *repeatCalendar;
@property (nonatomic, copy) NSString *alertBody;
@property (nonatomic, copy) NSString *alertTitle;
@property (nonatomic) BOOL hasAction;
@property (nonatomic, copy) NSString *alertAction;
@property (nonatomic, copy) NSString *alertLaunchImage;
@property (nonatomic, copy) NSString *soundName;
@property (nonatomic) NSInteger applicationIconBadgeNumber;
@property (nonatomic, copy) NSDictionary *userInfo;
@property (nonatomic, copy) NSString *category;
@property (nonatomic) BOOL regionTriggersOnce;
@property (nonatomic, copy) id region;
@end

#endif /* UIKIT_UILOCALNOTIFICATION_H */
