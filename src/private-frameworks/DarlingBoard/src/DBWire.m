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

#import "DBWire.h"
#import <DarlingBoard/DarlingBoard.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <spawn.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <arpa/inet.h>

extern char **environ;

NSString *DBWireSocketPath(void)
{
	const char *path = getenv("FRONTBOARD_SOCKET");
	return path != NULL ? [NSString stringWithUTF8String:path] : @"/private/var/run/frontboardd.sock";
}

static BOOL DBWireAddress(struct sockaddr_un *address)
{
	const char *path = [DBWireSocketPath() fileSystemRepresentation];
	memset(address, 0, sizeof(*address));
	address->sun_family = AF_UNIX;
	if (strlen(path) >= sizeof(address->sun_path))
		return NO;
	strcpy(address->sun_path, path);
	return YES;
}

int DBWireConnect(void)
{
	struct sockaddr_un address;
	if (!DBWireAddress(&address))
		return -1;
	int fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd < 0)
		return -1;
	if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
		close(fd);
		return -1;
	}
	fcntl(fd, F_SETFD, FD_CLOEXEC);
	return fd;
}

int DBWireListen(void)
{
	struct sockaddr_un address;
	if (!DBWireAddress(&address))
		return -1;
	int fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd < 0)
		return -1;
	unlink(address.sun_path);
	if (bind(fd, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(fd, 16) != 0) {
		close(fd);
		return -1;
	}
	fcntl(fd, F_SETFD, FD_CLOEXEC);
	return fd;
}

static BOOL DBWireWriteAll(int fd, const void *buffer, size_t length)
{
	const char *bytes = buffer;
	while (length > 0) {
		ssize_t written = write(fd, bytes, length);
		if (written < 0 && errno == EINTR)
			continue;
		if (written <= 0)
			return NO;
		bytes += written;
		length -= written;
	}
	return YES;
}

static BOOL DBWireReadAll(int fd, void *buffer, size_t length)
{
	char *bytes = buffer;
	while (length > 0) {
		ssize_t got = read(fd, bytes, length);
		if (got < 0 && errno == EINTR)
			continue;
		if (got <= 0)
			return NO;
		bytes += got;
		length -= got;
	}
	return YES;
}

BOOL DBWireSend(int fd, NSDictionary *message)
{
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:message format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
	if (data == nil)
		return NO;
	uint32_t length = htonl((uint32_t)[data length]);
	return DBWireWriteAll(fd, &length, sizeof(length)) && DBWireWriteAll(fd, [data bytes], [data length]);
}

NSDictionary *DBWireReceive(int fd)
{
	uint32_t length;
	if (!DBWireReadAll(fd, &length, sizeof(length)))
		return nil;
	length = ntohl(length);
	if (length > (16 << 20))
		return nil;
	NSMutableData *data = [NSMutableData dataWithLength:length];
	if (!DBWireReadAll(fd, [data mutableBytes], length))
		return nil;
	id message = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
	return [message isKindOfClass:[NSDictionary class]] ? message : nil;
}

NSDictionary *DBWireRequest(NSDictionary *message)
{
	int fd = DBWireConnect();
	if (fd < 0)
		return nil;
	NSDictionary *reply = DBWireSend(fd, message) ? DBWireReceive(fd) : nil;
	close(fd);
	return reply;
}

NSDictionary *DBWireOptions(NSDictionary *options)
{
	NSMutableDictionary *wire = [NSMutableDictionary dictionary];
	[options enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
		if ([value isKindOfClass:[NSURL class]])
			value = [value absoluteString];
		if ([key isKindOfClass:[NSString class]]
				&& [NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListXMLFormat_v1_0])
			wire[key] = value;
	}];
	return wire;
}

NSError *DBSpawnApplication(NSBundle *bundle, NSDictionary *options, pid_t *outPid)
{
	NSString *executable = [bundle executablePath];
	if (executable == nil)
		return [NSError errorWithDomain:DBOpenApplicationErrorDomain code:DBOpenApplicationErrorLaunchFailed
			userInfo:@{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"%@ has no executable", [bundle bundlePath]] }];

	NSDictionary *debug = options[DBOpenApplicationOptionDebugging];
	NSMutableArray<NSString *> *arguments = [NSMutableArray arrayWithObject:executable];
	[arguments addObjectsFromArray:debug[DBDebugOptionArguments] ?: @[]];

	/* Start from the raw environ, not NSProcessInfo: Darling's loader hides
	   its own __mldr_* variables from the latter, and exec needs them. */
	NSDictionary<NSString *, NSString *> *overrides = debug[DBDebugOptionEnvironment] ?: @{};
	NSMutableArray<NSString *> *environment = [NSMutableArray array];
	for (char **entry = environ; *entry != NULL; entry++) {
		NSString *string = [NSString stringWithUTF8String:*entry];
		NSRange equals = [string rangeOfString:@"="];
		if (string == nil || (equals.location != NSNotFound && overrides[[string substringToIndex:equals.location]] != nil))
			continue;
		[environment addObject:string];
	}
	[overrides enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
		[environment addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
	}];

	posix_spawn_file_actions_t actions;
	posix_spawn_file_actions_init(&actions);
	if (debug[DBDebugOptionStandardOutPath] != nil)
		posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, [debug[DBDebugOptionStandardOutPath] fileSystemRepresentation], O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (debug[DBDebugOptionStandardErrorPath] != nil)
		posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, [debug[DBDebugOptionStandardErrorPath] fileSystemRepresentation], O_WRONLY | O_CREAT | O_TRUNC, 0644);

	size_t argc = [arguments count];
	char **argv = calloc(argc + 1, sizeof(char *));
	for (size_t i = 0; i < argc; i++)
		argv[i] = strdup([arguments[i] UTF8String]);
	size_t envc = [environment count];
	char **envp = calloc(envc + 1, sizeof(char *));
	for (size_t i = 0; i < envc; i++)
		envp[i] = strdup([environment[i] UTF8String]);

	pid_t pid;
	int rc = posix_spawn(&pid, argv[0], &actions, NULL, argv, envp);
	posix_spawn_file_actions_destroy(&actions);
	for (size_t i = 0; i < argc; i++)
		free(argv[i]);
	free(argv);
	for (size_t i = 0; i < envc; i++)
		free(envp[i]);
	free(envp);

	if (rc != 0)
		return [NSError errorWithDomain:DBOpenApplicationErrorDomain code:DBOpenApplicationErrorLaunchFailed
			userInfo:@{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"posix_spawn %@: %s", executable, strerror(rc)] }];
	*outPid = pid;
	return nil;
}
