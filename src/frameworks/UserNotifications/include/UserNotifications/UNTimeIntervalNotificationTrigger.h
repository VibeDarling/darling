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

#ifndef _USERNOTIFICATIONS_UNTIMEINTERVALNOTIFICATIONTRIGGER_H_
#define _USERNOTIFICATIONS_UNTIMEINTERVALNOTIFICATIONTRIGGER_H_

#import <UserNotifications/UNNotificationTrigger.h>

/* Fires the interval after it is added; one that repeats must be at least a
   minute apart. */
@interface UNTimeIntervalNotificationTrigger : UNNotificationTrigger

+ (instancetype) triggerWithTimeInterval: (NSTimeInterval) timeInterval repeats: (BOOL) repeats;

@property (readonly) NSTimeInterval timeInterval;

/* When it fires next: a trigger made in this process counts from its
   creation, one read back from the system from when it was added. */
- (NSDate *) nextTriggerDate;

@end

#endif
