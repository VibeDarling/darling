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

#ifndef _SPRINGBOARD_H_
#define _SPRINGBOARD_H_

#import <UIKit/UIKit.h>

/* UIKit's: what the host's screen edges cover (a phone host's status and
   navigation bars), in points. */
UIEdgeInsets UIKitHostSafeAreaInsets(void);

void SBLog(NSString *format, ...);
void SBAddRoundedRect(CGContextRef context, CGRect rect, CGFloat radius);

/* The class and method names below are iOS SpringBoard's, which tweaks
   (WinterBoard's themes) find and hook by name. */

@interface SBApplication : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *displayName;
/* The bundle's directory. */
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) UIImage *icon;
+ (instancetype)applicationWithBundle:(NSBundle *)bundle;
- (NSString *)displayIdentifier;
/* The file the icon is read from, or nil. */
- (NSString *)pathForIcon;
@end

/* Shows apps' notifications, as usernotificationsd's presenter: a banner
   at the top of the screen, over whatever app is in front, or for one with
   a critical sound (an alarm) an alert that keeps ringing until the user
   answers it. Opening one opens its app. */
@interface SBNotificationPresenter : NSObject
+ (instancetype)sharedPresenter;
- (void)start;
@end

#endif
