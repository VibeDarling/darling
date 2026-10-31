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

#ifndef _UNLITE_H_
#define _UNLITE_H_

/* The wire between UserNotifications and usernotificationsd, which keeps
   every app's scheduled and delivered notifications and fires them. As with
   frontboardd (FBSLite.h): one Unix socket, every message a property list
   dictionary framed by a 4-byte big-endian length, and "op" naming the
   request.

   Requests (one per connection, answered by one reply; each names its app
   with bundleIdentifier):
     add              request                  -> {} | error
     pending                                   -> requests
     removePending    identifiers (none: all)  -> {}
     delivered                                 -> notifications
     removeDelivered  identifiers (none: all)  -> {}
     setCategories    categories               -> {}
     categories                                -> categories
     respond          identifier, action       -> {} (from the presenter: the
                                                  user opened, dismissed or
                                                  picked an action)
   An app's own connection, once it has a delegate:
     checkin  -> then events until it closes:
                   present   notification, token: it came while the app is
                             in front; the app answers on the connection with
                             {op: presentOptions, token, options}
                   response  notification, action
   The presenter's (SpringBoard's) connection:
     presenter -> then events:
                   show      bundleIdentifier, notification, options,
                             actions, categoryOptions
                   withdraw  bundleIdentifier, identifiers (the app removed
                             them; an alert still up goes away)

   Requests, notifications and categories travel as dictionaries; the
   functions below convert them. A request's trigger carries "fireDate",
   when it fires next, as the daemon has it. */

#import <Foundation/Foundation.h>

@class UNNotificationRequest, UNNotification, UNNotificationCategory, UNNotificationContent;

NS_ASSUME_NONNULL_BEGIN

/* $USERNOTIFICATIONS_SOCKET, or /private/var/run/usernotificationsd.sock. */
extern NSString *UNLiteSocketPath(void);

extern int UNLiteConnect(void);
extern int UNLiteListen(void);
extern BOOL UNLiteSend(int fd, NSDictionary *message);
extern NSDictionary * _Nullable UNLiteReceive(int fd);

/* Connect, send, wait for the reply, close. nil when no daemon runs. */
extern NSDictionary * _Nullable UNLiteRequest(NSDictionary *message);

extern NSDictionary *UNLiteWireRequest(UNNotificationRequest *request);
extern UNNotificationRequest * _Nullable UNLiteRequestFromWire(NSDictionary *wire);
extern NSDictionary *UNLiteWireNotification(UNNotification *notification);
extern UNNotification * _Nullable UNLiteNotificationFromWire(NSDictionary *wire);
extern NSDictionary *UNLiteWireCategory(UNNotificationCategory *category);
extern UNNotificationCategory * _Nullable UNLiteCategoryFromWire(NSDictionary *wire);

/* When a wire trigger fires next after the date: nil if it never does. A
   time interval trigger counts from its "fireDate" (when it was added plus
   the interval), so a repeating one fires at whole intervals from there. */
extern NSDate * _Nullable UNLiteNextFireDate(NSDictionary *trigger, NSDate *after);

/* The first date after (not at) the given one matching the components: the
   components below the smallest one given count as their minimum (an hour
   alone means on the hour), those above it as any. */
extern NSDate * _Nullable UNLiteNextDateMatching(NSDateComponents *components, NSDate *after);

NS_ASSUME_NONNULL_END

#endif
