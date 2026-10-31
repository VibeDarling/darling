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

#ifndef _USERNOTIFICATIONS_UNMUTABLENOTIFICATIONCONTENT_H_
#define _USERNOTIFICATIONS_UNMUTABLENOTIFICATIONCONTENT_H_

#import <UserNotifications/UNNotificationContent.h>

@interface UNMutableNotificationContent : UNNotificationContent

@property (copy) NSArray<UNNotificationAttachment *> *attachments;
@property (copy) NSNumber *badge;
@property (copy) NSString *body;
@property (copy) NSString *categoryIdentifier;
@property (copy) NSString *launchImageName;
@property (copy) UNNotificationSound *sound;
@property (copy) NSString *subtitle;
@property (copy) NSString *threadIdentifier;
@property (copy) NSString *title;
@property (copy) NSDictionary *userInfo;
@property (copy) NSString *summaryArgument;
@property NSUInteger summaryArgumentCount;
@property (copy) NSString *targetContentIdentifier;
@property UNNotificationInterruptionLevel interruptionLevel;
@property double relevanceScore;

@end

#endif
