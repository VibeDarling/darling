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

#import <RunningBoardServices/RunningBoardServices.h>
#include <libproc.h>
#include <signal.h>
#include <errno.h>
#include <sys/sysctl.h>

NSErrorDomain const RBSRequestErrorDomain = @"RBSRequestErrorDomain";

@interface RBSProcessPredicate ()
- (RBSProcessIdentifier *)rbs_identifier;
@end

@interface RBSProcessState ()
- (instancetype)initWithProcess:(RBSProcessHandle *)process taskState:(RBSTaskState)taskState;
@end

/* The bundle a process runs from: the nearest enclosing .app of its
   executable (iOS bundles are flat, macOS ones keep it in Contents/MacOS). */
static NSString *RBSBundleIdentifierForExecutable(NSString *path)
{
	NSString *dir = [path stringByDeletingLastPathComponent];
	while ([dir length] > 1) {
		if ([[dir pathExtension] isEqualToString:@"app"]) {
			NSBundle *bundle = [NSBundle bundleWithPath:dir];
			return [bundle bundleIdentifier];
		}
		dir = [dir stringByDeletingLastPathComponent];
	}
	return nil;
}

@implementation RBSProcessIdentifier

+ (BOOL)supportsSecureCoding
{
	return YES;
}

+ (instancetype)identifierWithPid:(pid_t)pid
{
	RBSProcessIdentifier *identifier = [[self alloc] init];
	identifier->_pid = pid;
	return identifier;
}

+ (instancetype)identifierForCurrentProcess
{
	return [self identifierWithPid:getpid()];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]))
		_pid = [coder decodeInt32ForKey:@"pid"];
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:_pid forKey:@"pid"];
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (BOOL)isEqual:(id)other
{
	return [other isKindOfClass:[RBSProcessIdentifier class]] && ((RBSProcessIdentifier *)other)->_pid == _pid;
}

- (NSUInteger)hash
{
	return (NSUInteger)_pid;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ pid=%d>", [self class], _pid];
}

@end

@implementation RBSProcessPredicate {
	RBSProcessIdentifier *_identifier;
	NSSet<NSString *> *_bundleIdentifiers;
}

+ (instancetype)predicateMatchingIdentifier:(RBSProcessIdentifier *)identifier
{
	RBSProcessPredicate *predicate = [[self alloc] init];
	predicate->_identifier = identifier;
	return predicate;
}

+ (instancetype)predicateMatchingBundleIdentifier:(NSString *)bundleIdentifier
{
	return [self predicateMatchingBundleIdentifiers:@[ bundleIdentifier ]];
}

+ (instancetype)predicateMatchingBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
{
	RBSProcessPredicate *predicate = [[self alloc] init];
	predicate->_bundleIdentifiers = [NSSet setWithArray:bundleIdentifiers];
	return predicate;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (RBSProcessIdentifier *)rbs_identifier
{
	return _identifier;
}

- (BOOL)matchesProcess:(RBSProcessHandle *)process
{
	if (_identifier != nil)
		return [[process identifier] isEqual:_identifier];
	NSString *bundleIdentifier = [process bundleIdentifier];
	return bundleIdentifier != nil && [_bundleIdentifiers containsObject:bundleIdentifier];
}

- (NSString *)description
{
	if (_identifier != nil)
		return [NSString stringWithFormat:@"<%@ identifier=%@>", [self class], _identifier];
	return [NSString stringWithFormat:@"<%@ bundleIdentifiers=%@>", [self class], [[_bundleIdentifiers allObjects] componentsJoinedByString:@","]];
}

@end

@implementation RBSProcessState

- (instancetype)initWithProcess:(RBSProcessHandle *)process taskState:(RBSTaskState)taskState
{
	if ((self = [super init])) {
		_process = process;
		_taskState = taskState;
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (BOOL)isRunning
{
	return _taskState == RBSTaskStateRunning || _taskState == RBSTaskStateRunningScheduled;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ pid=%d taskState=%d>", [self class], [_process pid], _taskState];
}

@end

@implementation RBSProcessHandle {
	NSString *_executablePath;
	NSString *_bundleIdentifier;
	BOOL _resolved;
}

+ (instancetype)rbs_handleWithPid:(pid_t)pid
{
	RBSProcessHandle *handle = [[self alloc] init];
	handle->_identifier = [RBSProcessIdentifier identifierWithPid:pid];
	return handle;
}

+ (instancetype)currentProcess
{
	static RBSProcessHandle *current;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		current = [self rbs_handleWithPid:getpid()];
		current->_executablePath = [[NSBundle mainBundle] executablePath];
		current->_bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
		current->_resolved = YES;
	});
	return current;
}

+ (instancetype)handleForIdentifier:(RBSProcessIdentifier *)identifier error:(NSError **)error
{
	if ([identifier pid] == getpid())
		return [self currentProcess];

	RBSProcessHandle *handle = [self rbs_handleWithPid:[identifier pid]];
	if (![handle isValid]) {
		if (error != NULL)
			*error = [NSError errorWithDomain:RBSRequestErrorDomain code:RBSRequestErrorProcessNotFound
				userInfo:@{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"No process with pid %d", [identifier pid]] }];
		return nil;
	}
	return handle;
}

+ (NSArray<RBSProcessHandle *> *)handlesForPredicate:(RBSProcessPredicate *)predicate
{
	RBSProcessIdentifier *identifier = [predicate rbs_identifier];
	if (identifier != nil) {
		RBSProcessHandle *handle = [self handleForIdentifier:identifier error:NULL];
		return handle != nil ? @[ handle ] : @[];
	}

	/* sysctl rather than proc_listallpids: Darling's proc_listpids only
	   reports the caller, while kern.proc.all walks every Darling task. */
	NSMutableArray<RBSProcessHandle *> *matches = [NSMutableArray array];
	int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
	size_t size = 0;
	if (sysctl(mib, 4, NULL, &size, NULL, 0) != 0 || size == 0)
		return matches;
	size += 16 * sizeof(struct kinfo_proc);
	struct kinfo_proc *procs = malloc(size);
	if (sysctl(mib, 4, procs, &size, NULL, 0) != 0) {
		free(procs);
		return matches;
	}
	size_t count = size / sizeof(struct kinfo_proc);
	for (size_t i = 0; i < count; i++) {
		pid_t pid = procs[i].kp_proc.p_pid;
		RBSProcessHandle *handle = pid == getpid() ? [self currentProcess] : [self rbs_handleWithPid:pid];
		if ([predicate matchesProcess:handle])
			[matches addObject:handle];
	}
	free(procs);
	return matches;
}

+ (instancetype)handleForPredicate:(RBSProcessPredicate *)predicate error:(NSError **)error
{
	RBSProcessHandle *handle = [[self handlesForPredicate:predicate] firstObject];
	if (handle == nil && error != NULL)
		*error = [NSError errorWithDomain:RBSRequestErrorDomain code:RBSRequestErrorProcessNotFound
			userInfo:@{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"No process matches %@", predicate] }];
	return handle;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (BOOL)isEqual:(id)other
{
	return [other isKindOfClass:[RBSProcessHandle class]] && [((RBSProcessHandle *)other).identifier isEqual:_identifier];
}

- (NSUInteger)hash
{
	return [_identifier hash];
}

- (pid_t)pid
{
	return [_identifier pid];
}

- (pid_t)rbs_pid
{
	return [self pid];
}

- (void)rbs_resolve
{
	@synchronized (self) {
		if (_resolved)
			return;
		char path[PROC_PIDPATHINFO_MAXSIZE];
		if (proc_pidpath([self pid], path, sizeof(path)) > 0) {
			_executablePath = [NSString stringWithUTF8String:path];
			_bundleIdentifier = RBSBundleIdentifierForExecutable(_executablePath);
		}
		_resolved = YES;
	}
}

- (NSString *)executablePath
{
	[self rbs_resolve];
	return _executablePath;
}

- (NSString *)bundleIdentifier
{
	[self rbs_resolve];
	return _bundleIdentifier;
}

- (NSString *)name
{
	/* The executable's name first: under Darling the kernel-level process
	   name of every Mach-O process is that of its loader, mldr. */
	NSString *executable = [[self executablePath] lastPathComponent];
	if (executable != nil)
		return executable;
	char name[2 * MAXCOMLEN + 1];
	if (proc_name([self pid], name, sizeof(name)) > 0)
		return [NSString stringWithUTF8String:name];
	return nil;
}

- (RBSTaskState)rbs_taskState
{
	if (kill([self pid], 0) != 0 && errno != EPERM)
		return RBSTaskStateNone;
	struct proc_bsdinfo info;
	if (proc_pidinfo([self pid], PROC_PIDTBSDINFO, 0, &info, sizeof(info)) == sizeof(info)) {
		/* A zombie still answers kill(pid, 0) until its parent reaps it. */
		if (info.pbi_status == SZOMB)
			return RBSTaskStateNone;
		if (info.pbi_status == SSTOP)
			return RBSTaskStateRunningSuspended;
	}
	return RBSTaskStateRunning;
}

- (BOOL)isValid
{
	return [self rbs_taskState] != RBSTaskStateNone;
}

- (RBSProcessState *)currentState
{
	return [[RBSProcessState alloc] initWithProcess:self taskState:[self rbs_taskState]];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@(%d)>", [self class], [self bundleIdentifier] ?: [self name], [self pid]];
}

@end
