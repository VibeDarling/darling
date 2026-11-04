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


#ifndef _DBWIRE_H_
#define _DBWIRE_H_

/* The wire between DarlingBoard and frontboardd. One Unix socket; every
   message is a property list dictionary, framed by a 4-byte big-endian
   length.

   Requests (one per connection, answered by one reply):
     open       bundleIdentifier, options      -> pid | error, code
     openURL    url                            -> {} | error, code
     pid        bundleIdentifier               -> pid (0 if not running)
     terminate  bundleIdentifier               -> (after it has exited)
     home                                      -> (foreground app backgrounded)
     button     button: "home"                 -> {}
     list                                      -> processes: [{bundleIdentifier, pid, state}]
   An app's own connection:
     checkin    bundleIdentifier, pid          -> then events until it closes:
                                                  state (state: DBApplicationState), terminate

   These functions are for frontboardd, usernotificationsd and DarlingBoard
   itself, not for apps. */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* $FRONTBOARD_SOCKET, or /private/var/run/frontboardd.sock. */
extern NSString *DBWireSocketPath(void);

extern int DBWireConnect(void);
extern int DBWireListen(void);
extern BOOL DBWireSend(int fd, NSDictionary *message);
extern NSDictionary * _Nullable DBWireReceive(int fd);

/* Connect, send, wait for the reply, close. nil when no frontboardd runs. */
extern NSDictionary * _Nullable DBWireRequest(NSDictionary *message);

/* Option dictionaries as plists: NSURLs become strings. */
extern NSDictionary *DBWireOptions(NSDictionary * _Nullable options);

/* Spawn an installed app's executable, honouring the debugging options
   (arguments, environment, stdout/stderr paths). */
extern NSError * _Nullable DBSpawnApplication(NSBundle *bundle, NSDictionary * _Nullable options, pid_t *pid);

NS_ASSUME_NONNULL_END

#endif
