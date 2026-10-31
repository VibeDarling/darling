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

#ifndef _USERNOTIFICATIONS_UNNOTIFICATIONSOUND_H_
#define _USERNOTIFICATIONS_UNNOTIFICATIONSOUND_H_

#import <Foundation/Foundation.h>

typedef NSString *UNNotificationSoundName;

@interface UNNotificationSound : NSObject <NSCopying, NSSecureCoding>

@property (class, readonly, copy) UNNotificationSound *defaultSound;
@property (class, readonly, copy) UNNotificationSound *defaultCriticalSound;

+ (instancetype) soundNamed: (UNNotificationSoundName) name;
+ (instancetype) criticalSoundNamed: (UNNotificationSoundName) name;
+ (instancetype) criticalSoundNamed: (UNNotificationSoundName) name withAudioVolume: (float) volume;
+ (instancetype) defaultCriticalSoundWithAudioVolume: (float) volume;

- (instancetype) init NS_UNAVAILABLE;

/* nil for the default sound. */
@property (readonly, copy) UNNotificationSoundName name;
@property (readonly, getter=isCritical) BOOL critical;
@property (readonly) float audioVolume;

@end

#endif
