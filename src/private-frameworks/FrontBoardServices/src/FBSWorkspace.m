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

#import <FrontBoardServices/FrontBoardServices.h>
#import "FBSLite.h"
#include <unistd.h>
#include <sys/socket.h>

@implementation FBSWorkspace {
	int _fd;
	__weak id<FBSWorkspaceDelegate> _delegate;
	dispatch_queue_t _queue;
	BOOL _invalidated;
}

+ (instancetype)checkInWithBundleIdentifier:(NSString *)bundleIdentifier delegate:(id<FBSWorkspaceDelegate>)delegate queue:(dispatch_queue_t)queue
{
	int fd = FBSLiteConnect();
	if (fd < 0)
		return nil;
	if (!FBSLiteSend(fd, @{ @"op": @"checkin", @"bundleIdentifier": bundleIdentifier ?: @"", @"pid": @(getpid()) })) {
		close(fd);
		return nil;
	}

	FBSWorkspace *workspace = [[self alloc] init];
	workspace->_fd = fd;
	workspace->_delegate = delegate;
	workspace->_queue = queue;

	/* Events are read on a thread of their own; the connection lives as
	   long as the app does, so the thread holds the workspace. */
	[NSThread detachNewThreadSelector:@selector(fbs_readEvents) toTarget:workspace withObject:nil];
	return workspace;
}

- (void)fbs_readEvents
{
	@autoreleasepool {
		NSDictionary *event;
		while ((event = FBSLiteReceive(_fd)) != nil) {
			NSString *name = event[@"event"];
			if ([name isEqualToString:@"state"]) {
				FBSApplicationState state = [event[@"state"] integerValue];
				dispatch_async(_queue, ^{
					if (state == self->_applicationState)
						return;
					self->_applicationState = state;
					[self->_delegate workspace:self didChangeApplicationState:state];
				});
			} else if ([name isEqualToString:@"terminate"]) {
				dispatch_async(_queue, ^{
					[self->_delegate workspaceDidRequestTermination:self];
				});
			}
		}
		dispatch_async(_queue, ^{
			if (self->_invalidated)
				return;
			id<FBSWorkspaceDelegate> delegate = self->_delegate;
			if ([delegate respondsToSelector:@selector(workspaceDidDisconnect:)])
				[delegate workspaceDidDisconnect:self];
		});
	}
}

- (void)invalidate
{
	_invalidated = YES;
	shutdown(_fd, SHUT_RDWR);
}

@end

@implementation FBSSystemService (FBSHome)

- (BOOL)backgroundForegroundApplication
{
	return FBSLiteRequest(@{ @"op": @"home" }) != nil;
}

- (NSArray<NSDictionary *> *)applicationStates
{
	return FBSLiteRequest(@{ @"op": @"list" })[@"processes"];
}

@end
