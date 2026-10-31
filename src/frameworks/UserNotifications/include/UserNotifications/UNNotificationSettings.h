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

#ifndef _USERNOTIFICATIONS_UNNOTIFICATIONSETTINGS_H_
#define _USERNOTIFICATIONS_UNNOTIFICATIONSETTINGS_H_

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UNAuthorizationStatus) {
    UNAuthorizationStatusNotDetermined = 0,
    UNAuthorizationStatusDenied,
    UNAuthorizationStatusAuthorized,
    UNAuthorizationStatusProvisional,
    UNAuthorizationStatusEphemeral,
};

typedef NS_ENUM(NSInteger, UNNotificationSetting) {
    UNNotificationSettingNotSupported = 0,
    UNNotificationSettingDisabled,
    UNNotificationSettingEnabled,
};

typedef NS_ENUM(NSInteger, UNAlertStyle) {
    UNAlertStyleNone = 0,
    UNAlertStyleBanner,
    UNAlertStyleAlert,
};

typedef NS_ENUM(NSInteger, UNShowPreviewsSetting) {
    UNShowPreviewsSettingAlways,
    UNShowPreviewsSettingWhenAuthenticated,
    UNShowPreviewsSettingNever,
};

@interface UNNotificationSettings : NSObject <NSCopying, NSSecureCoding>

- (instancetype) init NS_UNAVAILABLE;

@property (readonly) UNAuthorizationStatus authorizationStatus;
@property (readonly) UNNotificationSetting soundSetting;
@property (readonly) UNNotificationSetting badgeSetting;
@property (readonly) UNNotificationSetting alertSetting;
@property (readonly) UNNotificationSetting notificationCenterSetting;
@property (readonly) UNNotificationSetting lockScreenSetting;
@property (readonly) UNNotificationSetting carPlaySetting;
@property (readonly) UNNotificationSetting criticalAlertSetting;
@property (readonly) UNNotificationSetting announcementSetting;
@property (readonly) UNNotificationSetting timeSensitiveSetting;
@property (readonly) UNNotificationSetting scheduledDeliverySetting;
@property (readonly) UNNotificationSetting directMessagesSetting;
@property (readonly) UNAlertStyle alertStyle;
@property (readonly) UNShowPreviewsSetting showPreviewsSetting;
@property (readonly) BOOL providesAppNotificationSettings;

@end

#endif
