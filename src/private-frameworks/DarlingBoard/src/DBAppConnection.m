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


#import <DarlingBoard/DarlingBoard.h>
#import "DBWire.h"
#include <unistd.h>
#include <sys/socket.h>

NSNotificationName const DBAppConnectionEventNotification = @"DBAppConnectionEventNotification";

@implementation DBAppConnection {
	int _fd;
	__weak id<DBAppConnectionDelegate> _delegate;
	dispatch_queue_t _queue;
	BOOL _invalidated;
}

+ (instancetype)checkInWithBundleIdentifier:(NSString *)bundleIdentifier delegate:(id<DBAppConnectionDelegate>)delegate queue:(dispatch_queue_t)queue
{
	int fd = DBWireConnect();
	if (fd < 0)
		return nil;
	if (!DBWireSend(fd, @{ @"op": @"checkin", @"bundleIdentifier": bundleIdentifier ?: @"", @"pid": @(getpid()) })) {
		close(fd);
		return nil;
	}

	DBAppConnection *connection = [[self alloc] init];
	connection->_fd = fd;
	connection->_delegate = delegate;
	connection->_queue = queue;

	/* Events are read on a thread of their own; the connection lives as
	   long as the app does, so the thread holds the connection. */
	[NSThread detachNewThreadSelector:@selector(db_readEvents) toTarget:connection withObject:nil];
	return connection;
}

- (void)db_readEvents
{
	@autoreleasepool {
		NSDictionary *event;
		while ((event = DBWireReceive(_fd)) != nil) {
			NSString *name = event[@"event"];
			if ([name isEqualToString:@"state"]) {
				DBApplicationState state = [event[@"state"] integerValue];
				dispatch_async(_queue, ^{
					if (state == self->_applicationState)
						return;
					self->_applicationState = state;
					[self->_delegate appConnection:self didChangeApplicationState:state];
				});
			} else if ([name isEqualToString:@"terminate"]) {
				dispatch_async(_queue, ^{
					[self->_delegate appConnectionDidRequestTermination:self];
				});
			} else if (name != nil) {
				dispatch_async(_queue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:DBAppConnectionEventNotification object:self userInfo:event];
				});
			}
		}
		dispatch_async(_queue, ^{
			if (self->_invalidated)
				return;
			id<DBAppConnectionDelegate> delegate = self->_delegate;
			if ([delegate respondsToSelector:@selector(appConnectionDidDisconnect:)])
				[delegate appConnectionDidDisconnect:self];
		});
	}
}

- (void)invalidate
{
	_invalidated = YES;
	shutdown(_fd, SHUT_RDWR);
}

@end
