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

#ifndef _FBSLITE_H_
#define _FBSLITE_H_

/* The wire between FrontBoardServices and frontboardd, our stand-in for
   the FrontBoard half of SpringBoard. One Unix socket; every message is a
   property list dictionary, framed by a 4-byte big-endian length.

   Requests (one per connection, answered by one reply):
     open       bundleIdentifier, options      -> pid | error, code
     pid        bundleIdentifier               -> pid (0 if not running)
     terminate  bundleIdentifier               -> (after it has exited)
     home                                      -> (foreground app backgrounded)
     list                                      -> processes: [{bundleIdentifier, pid, state}]
   An app's own connection:
     checkin    bundleIdentifier, pid          -> then events until it closes:
                                                  state (state: FBSApplicationState), terminate

   The private FrontBoardServices functions below are for frontboardd and
   FrontBoardServices itself, not for apps. */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* $FRONTBOARD_SOCKET, or /private/var/run/frontboardd.sock. */
extern NSString *FBSLiteSocketPath(void);

extern int FBSLiteConnect(void);
extern int FBSLiteListen(void);
extern BOOL FBSLiteSend(int fd, NSDictionary *message);
extern NSDictionary * _Nullable FBSLiteReceive(int fd);

/* Connect, send, wait for the reply, close. nil when no frontboardd runs. */
extern NSDictionary * _Nullable FBSLiteRequest(NSDictionary *message);

/* Option dictionaries as plists: NSURLs become strings. */
extern NSDictionary *FBSLiteWireOptions(NSDictionary * _Nullable options);

/* Spawn an installed app's executable, honouring the debugging options
   (arguments, environment, stdout/stderr paths). */
extern NSError * _Nullable FBSLiteSpawnApplication(NSBundle *bundle, NSDictionary * _Nullable options, pid_t *pid);

NS_ASSUME_NONNULL_END

#endif
