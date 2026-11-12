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

#ifndef _USERNOTIFICATIONS_UNUSERNOTIFICATIONCENTER_H_
#define _USERNOTIFICATIONS_UNUSERNOTIFICATIONCENTER_H_

#import <Foundation/Foundation.h>

@protocol UNUserNotificationCenterDelegate;
@class UNNotificationSettings, UNNotificationRequest, UNNotificationCategory, UNNotification, UNNotificationResponse;

extern NSString * const UNErrorDomain;

typedef NS_ENUM(NSInteger, UNErrorCode) {
    UNErrorCodeNotificationsNotAllowed = 1,
    UNErrorCodeAttachmentInvalidURL = 100,
    UNErrorCodeAttachmentUnrecognizedType,
    UNErrorCodeAttachmentInvalidFileSize,
    UNErrorCodeAttachmentNotInDataStore,
    UNErrorCodeAttachmentMoveIntoDataStoreFailed,
    UNErrorCodeAttachmentCorrupt,
    UNErrorCodeNotificationInvalidNoDate = 1400,
    UNErrorCodeNotificationInvalidNoContent,
    UNErrorCodeContentProvidingObjectNotAllowed = 1500,
    UNErrorCodeContentProvidingInvalid,
};

typedef NS_OPTIONS(NSUInteger, UNAuthorizationOptions) {
    UNAuthorizationOptionBadge = (1 << 0),
    UNAuthorizationOptionSound = (1 << 1),
    UNAuthorizationOptionAlert = (1 << 2),
    UNAuthorizationOptionCarPlay = (1 << 3),
    UNAuthorizationOptionCriticalAlert = (1 << 4),
    UNAuthorizationOptionProvidesAppNotificationSettings = (1 << 5),
    UNAuthorizationOptionProvisional = (1 << 6),
    UNAuthorizationOptionAnnouncement = (1 << 7),
    UNAuthorizationOptionTimeSensitive = (1 << 8),
};

typedef NS_OPTIONS(NSUInteger, UNNotificationPresentationOptions) {
    UNNotificationPresentationOptionBadge = (1 << 0),
    UNNotificationPresentationOptionSound = (1 << 1),
    UNNotificationPresentationOptionAlert = (1 << 2),
    UNNotificationPresentationOptionList = (1 << 3),
    UNNotificationPresentationOptionBanner = (1 << 4),
};

static const UNNotificationPresentationOptions UNNotificationPresentationOptionNone = 0;

/* Notifications are kept and delivered by usernotificationsd; SpringBoard
   shows them. One that comes while its app is in front goes to the
   delegate's userNotificationCenter:willPresentNotification:..., which
   decides whether it is shown too. Opening one (or picking one of its
   actions) launches or resumes the app and tells the delegate. */
@interface UNUserNotificationCenter : NSObject

+ (UNUserNotificationCenter *) currentNotificationCenter;

- (instancetype) init NS_UNAVAILABLE;

@property (weak) id<UNUserNotificationCenterDelegate> delegate;
@property (readonly) BOOL supportsContentExtensions;

- (void) requestAuthorizationWithOptions: (UNAuthorizationOptions) options
                       completionHandler: (void (^)(BOOL granted, NSError *error)) completionHandler;

- (void) getNotificationSettingsWithCompletionHandler: (void (^)(UNNotificationSettings *settings)) completionHandler;

- (void) addNotificationRequest: (UNNotificationRequest *) request
          withCompletionHandler: (void (^)(NSError *error)) completionHandler;

- (void) getPendingNotificationRequestsWithCompletionHandler: (void (^)(NSArray<UNNotificationRequest *> *requests)) completionHandler;
- (void) removePendingNotificationRequestsWithIdentifiers: (NSArray<NSString *> *) identifiers;
- (void) removeAllPendingNotificationRequests;

- (void) getDeliveredNotificationsWithCompletionHandler: (void (^)(NSArray<UNNotification *> *notifications)) completionHandler;
- (void) removeDeliveredNotificationsWithIdentifiers: (NSArray<NSString *> *) identifiers;
- (void) removeAllDeliveredNotifications;

- (void) setNotificationCategories: (NSSet<UNNotificationCategory *> *) categories;
- (void) getNotificationCategoriesWithCompletionHandler: (void (^)(NSSet<UNNotificationCategory *> *categories)) completionHandler;

- (void) setBadgeCount: (NSInteger) newBadgeCount withCompletionHandler: (void (^)(NSError *error)) completionHandler;

@end

@protocol UNUserNotificationCenterDelegate <NSObject>
@optional

- (void) userNotificationCenter: (UNUserNotificationCenter *) center
        willPresentNotification: (UNNotification *) notification
          withCompletionHandler: (void (^)(UNNotificationPresentationOptions options)) completionHandler;

- (void) userNotificationCenter: (UNUserNotificationCenter *) center
 didReceiveNotificationResponse: (UNNotificationResponse *) response
          withCompletionHandler: (void (^)(void)) completionHandler;

- (void) userNotificationCenter: (UNUserNotificationCenter *) center
    openSettingsForNotification: (UNNotification *) notification;

@end

#endif
