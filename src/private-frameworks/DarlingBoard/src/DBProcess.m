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
#include <libproc.h>
#include <signal.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>

/* The bundle a process runs from: the nearest enclosing .app of its
   executable (iOS bundles are flat, macOS ones keep it in Contents/MacOS). */
static NSString *DBBundleIdentifierForExecutable(NSString *path)
{
	NSString *dir = [path stringByDeletingLastPathComponent];
	while ([dir length] > 1) {
		if ([[dir pathExtension] isEqualToString:@"app"])
			return [[NSBundle bundleWithPath:dir] bundleIdentifier];
		dir = [dir stringByDeletingLastPathComponent];
	}
	return nil;
}

static NSString *DBBundleIdentifierForPid(pid_t pid)
{
	if (pid == getpid())
		return [[NSBundle mainBundle] bundleIdentifier];
	char path[PROC_PIDPATHINFO_MAXSIZE];
	if (proc_pidpath(pid, path, sizeof(path)) <= 0)
		return nil;
	return DBBundleIdentifierForExecutable([NSString stringWithUTF8String:path]);
}

NSArray<NSNumber *> *DBProcessesForApplication(NSString *bundleIdentifier)
{
	NSMutableArray<NSNumber *> *matches = [NSMutableArray array];
	if ([bundleIdentifier length] == 0)
		return matches;

	/* sysctl rather than proc_listallpids: Darling's proc_listpids only
	   reports the caller, while kern.proc.all walks every Darling task. */
	int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
	size_t size = 0;
	if (sysctl(mib, 4, NULL, &size, NULL, 0) != 0 || size == 0)
		return matches;
	size += 16 * sizeof(struct kinfo_proc);
	struct kinfo_proc *procs = malloc(size);
	if (procs == NULL)
		return matches;
	if (sysctl(mib, 4, procs, &size, NULL, 0) != 0) {
		free(procs);
		return matches;
	}
	size_t count = size / sizeof(struct kinfo_proc);
	for (size_t i = 0; i < count; i++) {
		pid_t pid = procs[i].kp_proc.p_pid;
		if ([DBBundleIdentifierForPid(pid) isEqualToString:bundleIdentifier])
			[matches addObject:@(pid)];
	}
	free(procs);
	return matches;
}

BOOL DBProcessIsAlive(pid_t pid)
{
	if (pid <= 0)
		return NO;
	if (kill(pid, 0) != 0 && errno != EPERM)
		return NO;
	/* A zombie still answers kill(pid, 0) until its parent reaps it. */
	struct proc_bsdinfo info;
	if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) == sizeof(info) && info.pbi_status == SZOMB)
		return NO;
	return YES;
}
