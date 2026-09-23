/*
This file is part of Darling.

Copyright (C) 2016-2023 Lubos Dolezel

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

#include <stdio.h>
#include <dirent.h>
#include <sys/types.h>
#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <alloca.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <signal.h>
#include <stdbool.h>
#include <sched.h>
#include <sys/poll.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <getopt.h>
#include <termios.h>
#include <pty.h>
#include <pwd.h>
#include <grp.h>
#include <sys/auxv.h>
#include "../shellspawn/shellspawn.h"
#include "darling.h"
#include "darling-config.h"
#include "prefix-state.h"
#include "profile-prefix.h"
#include "proc-dir.h"

// Between Linux 4.9 and 4.11, a strange bug has been introduced
// which prevents connecting to Unix sockets if the socket was
// created in a different mount namespace or under overlayfs
// (dunno which one is really responsible for this).
#define USE_LINUX_4_11_HACK 1
#define SHELLSPAWN_WAIT_RETRIES 1200 // 60s (1200 * 50ms) to allow darlingserver to sync prefix on first run

char *prefix;
uid_t g_originalUid, g_originalGid;
bool g_fixPermissions = false;
bool g_rootless = false;
bool g_nonroot = false;
char g_workingDirectory[4096];

// The launcher is installed setuid root, so its caller controls the environment. Variables
// that select binaries or files to use (the darlingserver executed as root, the libexec tree
// used as the overlay lower layer, CA bundles, ...) are ignored when running setuid.
static const char* getenvTrusted(const char* name)
{
	if (getauxval(AT_SECURE))
		return NULL;
	return getenv(name);
}

// Permanently drop to the given uid/gid. Group privileges and the supplementary
// groups must be given up before the uid, because once the uid is no longer
// privileged we can no longer change them. Every step is checked and the final
// identity is verified, so we never continue while root could still be regained.
static bool dropPrivilegesPermanently(uid_t uid, gid_t gid)
{
	gid_t groups[1] = { gid };
	if (setgroups(1, groups) != 0)
		return false;
	if (setresgid(gid, gid, gid) != 0)
		return false;
	if (setresuid(uid, uid, uid) != 0)
		return false;

	uid_t ruid, euid, suid;
	gid_t rgid, egid, sgid;
	if (getresuid(&ruid, &euid, &suid) != 0 || ruid != uid || euid != uid || suid != uid)
		return false;
	if (getresgid(&rgid, &egid, &sgid) != 0 || rgid != gid || egid != gid || sgid != gid)
		return false;

	return true;
}

// In root mode, temporarily switch the effective ids to the invoking user for
// work done on their behalf. The gid must change while the euid is still 0, and
// on the way back the euid must be restored first. Non-root mode has already
// dropped to the invoking user, so there is nothing to switch.
static void useOriginalIds(void)
{
	if (g_nonroot)
		return;
	if (setegid(g_originalGid) != 0 || seteuid(g_originalUid) != 0)
	{
		fprintf(stderr, "Cannot switch to the invoking user's identity: %s\n", strerror(errno));
		exit(1);
	}
}

static void restoreRootIds(void)
{
	if (g_nonroot)
		return;
	if (seteuid(0) != 0 || setegid(0) != 0)
	{
		fprintf(stderr, "Cannot restore the launcher's identity: %s\n", strerror(errno));
		exit(1);
	}
}

// Test for a path's existence with the invoking user's ids. In root mode a plain
// access() uses the real uid (0); switching the effective ids to the user and
// testing with faccessat(AT_EACCESS) checks with the invoking user's rights
// instead. Non-root mode has already dropped, so this matches a plain access().
static int existsAsOriginalUser(const char* path)
{
	useOriginalIds();
	int r = faccessat(AT_FDCWD, path, F_OK, AT_EACCESS);
	restoreRootIds();
	return r;
}

// When the prefix does not yet exist and the caller is not really root, make
// sure the invoking user could create it themselves before we do it for them.
// In root mode the real ids are already 0 at this point, so the check runs with
// the effective ids switched to the invoking user (AT_EACCESS), which is the same
// identity setupPrefix() creates the prefix with.
static void checkPrefixCreatable(void)
{
	if (g_originalUid == 0)
		return;

	char parentBuf[4096];
	strncpy(parentBuf, prefix, sizeof(parentBuf) - 1);
	parentBuf[sizeof(parentBuf) - 1] = '\0';

	size_t len = strlen(parentBuf);
	while (len > 1 && parentBuf[len - 1] == '/')
		parentBuf[--len] = '\0';

	char* slash = strrchr(parentBuf, '/');
	const char* parent;
	if (slash == parentBuf)
		parent = "/";
	else if (slash)
	{
		*slash = '\0';
		parent = parentBuf;
	}
	else
		parent = ".";

	useOriginalIds();
	int allowed = faccessat(AT_FDCWD, parent, W_OK | X_OK, AT_EACCESS) == 0;
	restoreRootIds();

	if (!allowed)
	{
		fprintf(stderr, "You do not have permission to create the prefix directory.\n");
		exit(1);
	}
}

// darlingserver starts as real root without AT_SECURE, so its dynamic loader and its getenv() calls
// trust the environment. In root mode a setuid launcher passes it only these variables.
static const char* const g_darlingserverEnvAllowlist[] = {
	"HOME",
	"XDG_CONFIG_HOME",
	"DARLING_DEBUG",
	"DSERVER_LOG_STDERR",
	"DSERVER_LOG_LEVEL",
	"DARLING_LAUNCHD_STDERR",
	"DARLING_SHELLSPAWN_DEBUG",
	"DTAPE_LOG_SAFE_STUBS",
};

static void restrictEnvironmentForDarlingserver(void)
{
	if (!getauxval(AT_SECURE) || g_nonroot)
		return;

	const size_t count = sizeof(g_darlingserverEnvAllowlist) / sizeof(g_darlingserverEnvAllowlist[0]);
	char* values[count];

	for (size_t i = 0; i < count; i++)
	{
		const char* value = getenv(g_darlingserverEnvAllowlist[i]);
		values[i] = value ? strdup(value) : NULL;
		if (value && !values[i])
		{
			fprintf(stderr, "Cannot copy the environment for darlingserver\n");
			exit(1);
		}
	}

	if (clearenv() != 0)
	{
		fprintf(stderr, "Cannot clear the environment for darlingserver\n");
		exit(1);
	}

	for (size_t i = 0; i < count; i++)
	{
		if (values[i] && setenv(g_darlingserverEnvAllowlist[i], values[i], 1) != 0)
		{
			fprintf(stderr, "Cannot set %s for darlingserver: %s\n", g_darlingserverEnvAllowlist[i], strerror(errno));
			exit(1);
		}
		free(values[i]);
	}
}

static const char* getInstallPrefix(void)
{
	static char prefixBuf[4096] = {0};
	if (prefixBuf[0])
		return prefixBuf;

	const char* env = getenvTrusted("DARLING_INSTALL_PREFIX");
	if (env && env[0])
	{
		strncpy(prefixBuf, env, sizeof(prefixBuf) - 1);
		return prefixBuf;
	}

	// When setuid, the install location must not depend on where the caller placed the
	// binary: a hardlink of the launcher next to a planted bin/darlingserver would run
	// that binary as root. Use only the compiled-in prefix.
	if (getauxval(AT_SECURE))
	{
		strncpy(prefixBuf, INSTALL_PREFIX, sizeof(prefixBuf) - 1);
		return prefixBuf;
	}

	char exePath[4096];
	ssize_t len = readlink("/proc/self/exe", exePath, sizeof(exePath) - 1);
	if (len > 0)
	{
		exePath[len] = '\0';
		char* lastSlash = strrchr(exePath, '/');
		if (lastSlash)
		{
			*lastSlash = '\0';
			char* secondSlash = strrchr(exePath, '/');
			if (secondSlash && strcmp(secondSlash, "/bin") == 0)
			{
				*secondSlash = '\0';
				char checkPath[4096];
				snprintf(checkPath, sizeof(checkPath), "%s/bin/darlingserver", exePath);
				if (access(checkPath, X_OK) == 0)
				{
					strncpy(prefixBuf, exePath, sizeof(prefixBuf) - 1);
					return prefixBuf;
				}
			}
		}
	}

	strncpy(prefixBuf, INSTALL_PREFIX, sizeof(prefixBuf) - 1);
	return prefixBuf;
}

#include "container-shutdown.h"

// Nonroot shellspawn is launched separately from darlingserver. Pin its
// recorded host PID and verify its uid and exact prefix socket environment.
static pid_t shellspawnPeer(int *handle)
{
	char path[4096], environment[65536], expected[4096];
	pid_t pid = 0;
	snprintf(path, sizeof(path), "%s/.shellspawn.pid", prefix);
	useOriginalIds();
	int fd = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
	if (fd >= 0) {
		FILE *file = fdopen(fd, "r");
		if (file) { if (fscanf(file, "%d", &pid) != 1) pid = 0; fclose(file); }
		else close(fd);
	}
	if (pid <= 1) { restoreRootIds(); return 0; }
	int pinned = shutdownHandle(pid);
	struct stat st;
	snprintf(path, sizeof(path), "/proc/%d", pid);
	if (pinned < 0 || stat(path, &st) || st.st_uid != g_originalUid) {
		if (pinned >= 0) close(pinned);
		restoreRootIds(); return 0;
	}
	snprintf(path, sizeof(path), "/proc/%d/environ", pid);
	fd = open(path, O_RDONLY | O_CLOEXEC);
	ssize_t size = fd < 0 ? -1 : read(fd, environment, sizeof(environment));
	if (fd >= 0) close(fd);
	int len = snprintf(expected, sizeof(expected), "__mldr_sockpath=%s/.darlingserver.sock", prefix);
	bool match = false;
	if (len > 0 && (size_t)len < sizeof(expected) && size > 0) {
		for (size_t pos = 0; pos < (size_t)size;) {
			size_t n = strnlen(environment + pos, size - pos);
			if (n == (size_t)size - pos) break;
			if (!strcmp(environment + pos, expected)) { match = true; break; }
			pos += n + 1;
		}
	}
	restoreRootIds();
	if (!match) { close(pinned); return 0; }
	*handle = pinned;
	return pid;
}

static void spawnShellspawn(void)
{
	pid_t spid = fork();
	if (spid < 0)
	{
		perror("fork shellspawn");
		return;
	}
	if (spid == 0)
	{
		setsid();
		if (!getenv("DARLING_DEBUG"))
		{
			int devnull = open("/dev/null", O_RDWR);
			if (devnull >= 0)
			{
				dup2(devnull, STDIN_FILENO);
				dup2(devnull, STDOUT_FILENO);
				dup2(devnull, STDERR_FILENO);
				if (devnull > 2)
					close(devnull);
			}
			else
			{
				close(STDIN_FILENO);
				close(STDOUT_FILENO);
				close(STDERR_FILENO);
			}
		}

		char dserverSock[4096];
		snprintf(dserverSock, sizeof(dserverSock), "%s/.darlingserver.sock", prefix);

		const char* instPrefix = getInstallPrefix();
		char mldrDyldRoot[4096];
		snprintf(mldrDyldRoot, sizeof(mldrDyldRoot), "%s/libexec/darling", instPrefix);
		char vchrootArg0[4096];
		snprintf(vchrootArg0, sizeof(vchrootArg0), "mldr!%s/libexec/darling/usr/libexec/darling/vchroot", instPrefix);
		char mldrBin[4096];
		snprintf(mldrBin, sizeof(mldrBin), "%s/libexec/darling/bin/mldr", instPrefix);

		setenv("DARLING_NONROOT", "1", 1);
		setenv("__mldr_sockpath", dserverSock, 1);
		setenv("__mldr_DYLD_ROOT_PATH", mldrDyldRoot, 1);

		execl(mldrBin,
		      vchrootArg0,
		      "vchroot",
		      prefix,
		      "/usr/libexec/shellspawn",
		      NULL);
		_exit(1);
	}
	char pidPath[4096];
	snprintf(pidPath, sizeof(pidPath), "%s/.shellspawn.pid", prefix);
	int fd = open(pidPath, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC | O_NOFOLLOW, 0600);
	if (fd < 0 || dprintf(fd, "%d\n", spid) < 0) {
		fprintf(stderr, "Cannot record this prefix's shellspawn PID.\n");
		if (fd >= 0) close(fd);
		exit(1);
	}
	close(fd);
}

static void ensureProcSymlink(const char* prefixPath)
{
	char procPath[4096];
	struct stat st;
	snprintf(procPath, sizeof(procPath), "%s/proc", prefixPath);
	if (lstat(procPath, &st) == 0)
	{
		if (S_ISDIR(st.st_mode))
		{
			rmdir(procPath);
		}
		else if (S_ISLNK(st.st_mode))
		{
			char target[256];
			ssize_t len = readlink(procPath, target, sizeof(target) - 1);
			if (len > 0)
			{
				target[len] = '\0';
				if (strcmp(target, DARLING_PROC_SYMLINK_TARGET) != 0)
					unlink(procPath);
			}
		}
	}
	if (lstat(procPath, &st) != 0)
	{
		symlink(DARLING_PROC_SYMLINK_TARGET, procPath);
	}
}

static void ensureHostRootSymlinks(const char* prefixPath)
{
	const char* candidates[] = {
		getenvTrusted("PREFIX"),
		getenvTrusted("TERMUX__PREFIX"),
		getenvTrusted("TERMUX_PREFIX"),
		getInstallPrefix()
	};

	for (size_t i = 0; i < sizeof(candidates)/sizeof(candidates[0]); i++)
	{
		const char* pfx = candidates[i];
		if (!pfx || pfx[0] != '/')
			continue;

		char seg[256] = {0};
		const char* slash = strchr(pfx + 1, '/');
		size_t len = slash ? (size_t)(slash - (pfx + 1)) : strlen(pfx + 1);
		if (len == 0 || len >= sizeof(seg))
			continue;
		memcpy(seg, pfx + 1, len);
		seg[len] = '\0';

		if (strcmp(seg, "usr") == 0 || strcmp(seg, "bin") == 0 || strcmp(seg, "sbin") == 0 ||
		    strcmp(seg, "etc") == 0 || strcmp(seg, "var") == 0 || strcmp(seg, "dev") == 0 ||
		    strcmp(seg, "proc") == 0 || strcmp(seg, "System") == 0 || strcmp(seg, "Library") == 0 ||
		    strcmp(seg, "Volumes") == 0 || strcmp(seg, "Applications") == 0 || strcmp(seg, "Users") == 0 ||
		    strcmp(seg, "tmp") == 0 || strcmp(seg, "private") == 0)
		{
			continue;
		}

		char linkPath[4096];
		snprintf(linkPath, sizeof(linkPath), "%s/%s", prefixPath, seg);

		char expectedTarget[512];
		snprintf(expectedTarget, sizeof(expectedTarget), "Volumes/SystemRoot/%s", seg);

		struct stat st;
		if (lstat(linkPath, &st) == 0)
		{
			if (S_ISLNK(st.st_mode))
			{
				char currentTarget[512];
				ssize_t r = readlink(linkPath, currentTarget, sizeof(currentTarget) - 1);
				if (r > 0)
				{
					currentTarget[r] = '\0';
					if (strcmp(currentTarget, expectedTarget) == 0)
						continue;
				}
				unlink(linkPath);
			}
			else
			{
				continue;
			}
		}

		symlink(expectedTarget, linkPath);
	}
}

void createDir(const char* path);

static void ensureShSymlink(const char* prefixPath)
{
	char binDir[4096];
	snprintf(binDir, sizeof(binDir), "%s/bin", prefixPath);
	createDir(binDir);

	char shPath[4096];
	char bashPath[4096];
	struct stat st;
	snprintf(shPath, sizeof(shPath), "%s/bin/sh", prefixPath);
	snprintf(bashPath, sizeof(bashPath), "%s/bin/bash", prefixPath);

	const char* target = "bash";
	if (access(bashPath, X_OK) != 0)
	{
		char zshPath[4096];
		snprintf(zshPath, sizeof(zshPath), "%s/bin/zsh", prefixPath);
		if (access(zshPath, X_OK) == 0)
			target = "zsh";
	}

	if (stat(shPath, &st) != 0)
	{
		if (lstat(shPath, &st) == 0)
			unlink(shPath);
		symlink(target, shPath);
	}
}

static void relativizeNanobrewSymlinks(const char* dirPath)
{
	DIR* dir = opendir(dirPath);
	if (!dir) return;

	struct dirent* de;
	while ((de = readdir(dir)) != NULL)
	{
		if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0)
			continue;

		char binItem[4096];
		snprintf(binItem, sizeof(binItem), "%s/%s", dirPath, de->d_name);
		struct stat itemSt;
		if (lstat(binItem, &itemSt) == 0 && S_ISLNK(itemSt.st_mode))
		{
			char itemTarget[4096];
			ssize_t tlen = readlink(binItem, itemTarget, sizeof(itemTarget) - 1);
			if (tlen > 0)
			{
				itemTarget[tlen] = '\0';
				const char* pfxMatch = "/opt/nanobrew/prefix/";
				size_t pfxLen = strlen(pfxMatch);
				if (strncmp(itemTarget, pfxMatch, pfxLen) == 0)
				{
					char relTarget[4096];
					snprintf(relTarget, sizeof(relTarget), "../%s", itemTarget + pfxLen);
					unlink(binItem);
					symlink(relTarget, binItem);
				}
			}
		}
	}
	closedir(dir);
}

static void ensureSystemLibBridge(const char* prefixPath, const char* libName)
{
	char usrLib[4096];
	snprintf(usrLib, sizeof(usrLib), "%s/usr/lib/%s", prefixPath, libName);

	struct stat st;
	if (lstat(usrLib, &st) == 0)
		return;

	const char* const searchDirs[] = {
		"/usr/local/lib",
		"/opt/homebrew/lib",
		"/opt/nanobrew/prefix/lib",
		NULL
	};

	for (int i = 0; searchDirs[i]; i++)
	{
		char hostCandidate[4096];
		snprintf(hostCandidate, sizeof(hostCandidate), "%s%s/%s", prefixPath, searchDirs[i], libName);
		if (lstat(hostCandidate, &st) == 0)
		{
			char target[512];
			snprintf(target, sizeof(target), "%s/%s", searchDirs[i], libName);
			if (symlink(target, usrLib) == 0 || errno == EEXIST)
				break;
		}
	}
}

static void ensureHomebrewSymlinks(const char* prefixPath)
{
	char nanobrewBin[4096];
	snprintf(nanobrewBin, sizeof(nanobrewBin), "%s/opt/nanobrew/prefix/bin", prefixPath);

	struct stat st;
	if (stat(nanobrewBin, &st) != 0 || !S_ISDIR(st.st_mode))
		return;

	char nanobrewOpt[4096];
	snprintf(nanobrewOpt, sizeof(nanobrewOpt), "%s/opt/nanobrew/prefix/opt", prefixPath);
	relativizeNanobrewSymlinks(nanobrewBin);
	relativizeNanobrewSymlinks(nanobrewOpt);

	// 1. Ensure /opt/homebrew -> nanobrew/prefix
	char optDir[4096];
	snprintf(optDir, sizeof(optDir), "%s/opt", prefixPath);
	createDir(optDir);

	char optHomebrew[4096];
	snprintf(optHomebrew, sizeof(optHomebrew), "%s/opt/homebrew", prefixPath);
	if (lstat(optHomebrew, &st) == 0)
	{
		if (S_ISLNK(st.st_mode))
		{
			char target[4096];
			ssize_t len = readlink(optHomebrew, target, sizeof(target) - 1);
			if (len > 0)
			{
				target[len] = '\0';
				if (strcmp(target, "nanobrew/prefix") != 0)
				{
					unlink(optHomebrew);
					symlink("nanobrew/prefix", optHomebrew);
				}
			}
		}
	}
	else
	{
		symlink("nanobrew/prefix", optHomebrew);
	}

	// 2. Ensure /usr/local, /usr/local/bin, /usr/local/opt, /usr/local/Cellar
	char usrLocalDir[4096];
	snprintf(usrLocalDir, sizeof(usrLocalDir), "%s/usr/local", prefixPath);
	createDir(usrLocalDir);

	char usrLocalBin[4096];
	snprintf(usrLocalBin, sizeof(usrLocalBin), "%s/usr/local/bin", prefixPath);
	createDir(usrLocalBin);

	char usrLocalOpt[4096];
	snprintf(usrLocalOpt, sizeof(usrLocalOpt), "%s/usr/local/opt", prefixPath);
	if (lstat(usrLocalOpt, &st) == 0)
	{
		if (S_ISDIR(st.st_mode))
		{
			DIR* d = opendir(usrLocalOpt);
			if (d)
			{
				struct dirent* de;
				bool has_real_content = false;
				while ((de = readdir(d)) != NULL)
				{
					if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0)
						continue;
					if (strcmp(de->d_name, "opt") == 0)
					{
						char dummy[4096];
						snprintf(dummy, sizeof(dummy), "%s/opt", usrLocalOpt);
						unlink(dummy);
						continue;
					}
					has_real_content = true;
					break;
				}
				closedir(d);
				if (!has_real_content)
				{
					rmdir(usrLocalOpt);
					symlink("../../opt/nanobrew/prefix/opt", usrLocalOpt);
				}
			}
		}
		else if (S_ISLNK(st.st_mode))
		{
			char target[4096];
			ssize_t len = readlink(usrLocalOpt, target, sizeof(target) - 1);
			if (len > 0)
			{
				target[len] = '\0';
				if (strcmp(target, "../../opt/nanobrew/prefix/opt") != 0 && strcmp(target, "/opt/nanobrew/prefix/opt") != 0)
				{
					unlink(usrLocalOpt);
					symlink("../../opt/nanobrew/prefix/opt", usrLocalOpt);
				}
			}
		}
	}
	else
	{
		symlink("../../opt/nanobrew/prefix/opt", usrLocalOpt);
	}

	char usrLocalCellar[4096];
	snprintf(usrLocalCellar, sizeof(usrLocalCellar), "%s/usr/local/Cellar", prefixPath);
	if (lstat(usrLocalCellar, &st) == 0)
	{
		if (S_ISDIR(st.st_mode))
		{
			DIR* d = opendir(usrLocalCellar);
			if (d)
			{
				struct dirent* de;
				bool has_real_content = false;
				while ((de = readdir(d)) != NULL)
				{
					if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0)
						continue;
					has_real_content = true;
					break;
				}
				closedir(d);
				if (!has_real_content)
				{
					rmdir(usrLocalCellar);
					symlink("../../opt/nanobrew/prefix/Cellar", usrLocalCellar);
				}
			}
		}
		else if (S_ISLNK(st.st_mode))
		{
			char target[4096];
			ssize_t len = readlink(usrLocalCellar, target, sizeof(target) - 1);
			if (len > 0)
			{
				target[len] = '\0';
				if (strcmp(target, "../../opt/nanobrew/prefix/Cellar") != 0 && strcmp(target, "/opt/nanobrew/prefix/Cellar") != 0)
				{
					unlink(usrLocalCellar);
					symlink("../../opt/nanobrew/prefix/Cellar", usrLocalCellar);
				}
			}
		}
	}
	else
	{
		symlink("../../opt/nanobrew/prefix/Cellar", usrLocalCellar);
	}

	char usrLocalEtc[4096];
	snprintf(usrLocalEtc, sizeof(usrLocalEtc), "%s/usr/local/etc", prefixPath);
	if (lstat(usrLocalEtc, &st) == 0)
	{
		if (S_ISDIR(st.st_mode))
		{
			DIR* d = opendir(usrLocalEtc);
			if (d)
			{
				struct dirent* de;
				bool has_real_content = false;
				while ((de = readdir(d)) != NULL)
				{
					if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0)
						continue;
					has_real_content = true;
					break;
				}
				closedir(d);
				if (!has_real_content)
				{
					rmdir(usrLocalEtc);
					symlink("../../opt/nanobrew/prefix/etc", usrLocalEtc);
				}
			}
		}
		else if (S_ISLNK(st.st_mode))
		{
			char target[4096];
			ssize_t len = readlink(usrLocalEtc, target, sizeof(target) - 1);
			if (len > 0)
			{
				target[len] = '\0';
				if (strcmp(target, "../../opt/nanobrew/prefix/etc") != 0 && strcmp(target, "/opt/nanobrew/prefix/etc") != 0)
				{
					unlink(usrLocalEtc);
					symlink("../../opt/nanobrew/prefix/etc", usrLocalEtc);
				}
			}
		}
	}
	else
	{
		symlink("../../opt/nanobrew/prefix/etc", usrLocalEtc);
	}

	char usrLocalShare[4096];
	snprintf(usrLocalShare, sizeof(usrLocalShare), "%s/usr/local/share", prefixPath);
	if (lstat(usrLocalShare, &st) == 0)
	{
		if (S_ISDIR(st.st_mode))
		{
			DIR* d = opendir(usrLocalShare);
			if (d)
			{
				struct dirent* de;
				bool has_real_content = false;
				while ((de = readdir(d)) != NULL)
				{
					if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0)
						continue;
					has_real_content = true;
					break;
				}
				closedir(d);
				if (!has_real_content)
				{
					rmdir(usrLocalShare);
					symlink("../../opt/nanobrew/prefix/share", usrLocalShare);
				}
			}
		}
		else if (S_ISLNK(st.st_mode))
		{
			char target[4096];
			ssize_t len = readlink(usrLocalShare, target, sizeof(target) - 1);
			if (len > 0)
			{
				target[len] = '\0';
				if (strcmp(target, "../../opt/nanobrew/prefix/share") != 0 && strcmp(target, "/opt/nanobrew/prefix/share") != 0)
				{
					unlink(usrLocalShare);
					symlink("../../opt/nanobrew/prefix/share", usrLocalShare);
				}
			}
		}
	}
	else
	{
		symlink("../../opt/nanobrew/prefix/share", usrLocalShare);
	}

	char usrLocalLib[4096];
	snprintf(usrLocalLib, sizeof(usrLocalLib), "%s/usr/local/lib", prefixPath);
	if (lstat(usrLocalLib, &st) == 0)
	{
		if (S_ISDIR(st.st_mode))
		{
			DIR* d = opendir(usrLocalLib);
			if (d)
			{
				struct dirent* de;
				bool has_real_content = false;
				while ((de = readdir(d)) != NULL)
				{
					if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0)
						continue;
					has_real_content = true;
					break;
				}
				closedir(d);
				if (!has_real_content)
				{
					rmdir(usrLocalLib);
					symlink("../../opt/nanobrew/prefix/lib", usrLocalLib);
				}
			}
		}
		else if (S_ISLNK(st.st_mode))
		{
			char target[4096];
			ssize_t len = readlink(usrLocalLib, target, sizeof(target) - 1);
			if (len > 0)
			{
				target[len] = '\0';
				if (strcmp(target, "../../opt/nanobrew/prefix/lib") != 0 && strcmp(target, "/opt/nanobrew/prefix/lib") != 0)
				{
					unlink(usrLocalLib);
					symlink("../../opt/nanobrew/prefix/lib", usrLocalLib);
				}
			}
		}
	}
	else
	{
		symlink("../../opt/nanobrew/prefix/lib", usrLocalLib);
	}

	// 3. Symlink all binaries from /opt/nanobrew/prefix/bin into /usr/local/bin
	DIR* dir = opendir(nanobrewBin);
	if (dir)
	{
		struct dirent* de;
		while ((de = readdir(dir)) != NULL)
		{
			if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0)
				continue;

			char linkPath[4096];
			snprintf(linkPath, sizeof(linkPath), "%s/%s", usrLocalBin, de->d_name);

			char expectedTarget[4096];
			snprintf(expectedTarget, sizeof(expectedTarget), "../../../opt/nanobrew/prefix/bin/%s", de->d_name);

			if (lstat(linkPath, &st) == 0)
			{
				if (S_ISLNK(st.st_mode))
				{
					char curTarget[4096];
					ssize_t len = readlink(linkPath, curTarget, sizeof(curTarget) - 1);
					if (len > 0)
					{
						curTarget[len] = '\0';
						if (strcmp(curTarget, expectedTarget) == 0)
							continue;
					}
					unlink(linkPath);
				}
				else
				{
					continue;
				}
			}

			symlink(expectedTarget, linkPath);
		}
		closedir(dir);
	}

	// 4. Python and Pip aliases and /usr/bin/python3
	char nbPython3[4096];
	snprintf(nbPython3, sizeof(nbPython3), "%s/python3", nanobrewBin);
	if (lstat(nbPython3, &st) == 0)
	{
		char usrBinPython3[4096];
		snprintf(usrBinPython3, sizeof(usrBinPython3), "%s/usr/bin/python3", prefixPath);
		if (lstat(usrBinPython3, &st) != 0)
		{
			symlink("../../opt/nanobrew/prefix/bin/python3", usrBinPython3);
		}

		char usrLocalPython[4096];
		snprintf(usrLocalPython, sizeof(usrLocalPython), "%s/python", usrLocalBin);
		if (lstat(usrLocalPython, &st) != 0)
		{
			symlink("python3", usrLocalPython);
		}
	}

	char nbPip3[4096];
	snprintf(nbPip3, sizeof(nbPip3), "%s/pip3", nanobrewBin);
	if (lstat(nbPip3, &st) == 0)
	{
		char usrLocalPip[4096];
		snprintf(usrLocalPip, sizeof(usrLocalPip), "%s/pip", usrLocalBin);
		if (lstat(usrLocalPip, &st) != 0)
		{
			symlink("pip3", usrLocalPip);
		}
	}

	// 5. Ensure /etc/paths.d has 10-nanobrew and 20-homebrew
	char pathsD[4096];
	snprintf(pathsD, sizeof(pathsD), "%s/etc/paths.d", prefixPath);
	createDir(pathsD);

	char nbPathFile[4096];
	snprintf(nbPathFile, sizeof(nbPathFile), "%s/10-nanobrew", pathsD);
	if (access(nbPathFile, F_OK) != 0)
	{
		FILE* f = fopen(nbPathFile, "w");
		if (f)
		{
			fputs("/opt/nanobrew/prefix/bin\n", f);
			fclose(f);
		}
	}

	char brewPathFile[4096];
	snprintf(brewPathFile, sizeof(brewPathFile), "%s/20-homebrew", pathsD);
	if (access(brewPathFile, F_OK) != 0)
	{
		FILE* f = fopen(brewPathFile, "w");
		if (f)
		{
			fputs("/opt/homebrew/bin\n", f);
			fclose(f);
		}
	}

	// 6. Bridge libpcap into nanobrew opt/libpcap/lib
	char nbPcapDir[4096], nbPcapLib[4096];
	snprintf(nbPcapDir, sizeof(nbPcapDir), "%s/libpcap", nanobrewOpt);
	snprintf(nbPcapLib, sizeof(nbPcapLib), "%s/libpcap/lib", nanobrewOpt);
	createDir(nbPcapDir);
	createDir(nbPcapLib);
	char nbPcapDylibA[4096];
	snprintf(nbPcapDylibA, sizeof(nbPcapDylibA), "%s/libpcap.A.dylib", nbPcapLib);
	if (lstat(nbPcapDylibA, &st) != 0)
	{
		symlink("/usr/lib/libpcap.A.dylib", nbPcapDylibA);
	}
	char nbPcapDylib[4096];
	snprintf(nbPcapDylib, sizeof(nbPcapDylib), "%s/libpcap.dylib", nbPcapLib);
	if (lstat(nbPcapDylib, &st) != 0)
	{
		symlink("libpcap.A.dylib", nbPcapDylib);
	}

	// 7. Ensure system library bridges into /usr/lib if provided by package managers (/usr/local/lib, /opt/homebrew/lib, /opt/nanobrew/prefix/lib)
	ensureSystemLibBridge(prefixPath, "libmd.dylib");

	const char* const pcre2Libs[] = {
		"libpcre2-8.0.dylib",
		"libpcre2-8.dylib",
		"libpcre2-16.0.dylib",
		"libpcre2-16.dylib",
		"libpcre2-32.0.dylib",
		"libpcre2-32.dylib",
		"libpcre2-posix.3.dylib",
		"libpcre2-posix.dylib",
		NULL
	};
	for (int i = 0; pcre2Libs[i]; i++)
	{
		ensureSystemLibBridge(prefixPath, pcre2Libs[i]);
	}
}

static const char* findHostCaBundle(void)
{
	static const char* cached_bundle = NULL;
	if (cached_bundle)
		return cached_bundle;

	// 1. SSL_CERT_FILE environment variable
	const char* ssl_cert_file = getenvTrusted("SSL_CERT_FILE");
	if (ssl_cert_file && access(ssl_cert_file, R_OK) == 0)
	{
		cached_bundle = ssl_cert_file;
		return cached_bundle;
	}

	// 2. Termux environment ($PREFIX / $TERMUX_PREFIX)
	const char* termux_prefix = getenvTrusted("PREFIX");
	if (!termux_prefix || !termux_prefix[0])
		termux_prefix = getenvTrusted("TERMUX_PREFIX");

	if (termux_prefix && termux_prefix[0])
	{
		static char termux_path[4096];
		const char* subpaths[] = {
			"/etc/tls/cert.pem",
			"/etc/ssl/certs/ca-certificates.crt",
			"/etc/ssl/cert.pem",
			"/glibc/etc/ssl/certs/ca-certificates.crt"
		};
		for (size_t i = 0; i < sizeof(subpaths)/sizeof(subpaths[0]); i++)
		{
			snprintf(termux_path, sizeof(termux_path), "%s%s", termux_prefix, subpaths[i]);
			if (access(termux_path, R_OK) == 0)
			{
				cached_bundle = termux_path;
				return cached_bundle;
			}
		}
	}

	// 3. Fallback standard Termux static paths
	static const char* termux_static_paths[] = {
		"/data/data/com.termux/files/usr/etc/tls/cert.pem",
		"/data/data/com.termux/files/usr/etc/ssl/certs/ca-certificates.crt",
		"/data/data/com.termux/files/usr/etc/ssl/cert.pem",
		"/data/data/com.termux/files/usr/glibc/etc/ssl/certs/ca-certificates.crt"
	};
	for (size_t i = 0; i < sizeof(termux_static_paths)/sizeof(termux_static_paths[0]); i++)
	{
		if (access(termux_static_paths[i], R_OK) == 0)
		{
			cached_bundle = termux_static_paths[i];
			return cached_bundle;
		}
	}

	// 4. Standard Linux / BSD paths
	static const char* standard_paths[] = {
		"/etc/ssl/certs/ca-certificates.crt",
		"/etc/pki/tls/certs/ca-bundle.crt",
		"/etc/ssl/ca-bundle.pem",
		"/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",
		"/etc/ssl/cert.pem"
	};
	for (size_t i = 0; i < sizeof(standard_paths)/sizeof(standard_paths[0]); i++)
	{
		if (access(standard_paths[i], R_OK) == 0)
		{
			cached_bundle = standard_paths[i];
			return cached_bundle;
		}
	}

	// 5. Android system cacerts directory
	if (access("/system/etc/security/cacerts", R_OK) == 0)
	{
		cached_bundle = "/system/etc/security/cacerts";
		return cached_bundle;
	}

	return NULL;
}

static inline int b64CharValue(char c)
{
	if (c >= 'A' && c <= 'Z') return c - 'A';
	if (c >= 'a' && c <= 'z') return c - 'a' + 26;
	if (c >= '0' && c <= '9') return c - '0' + 52;
	if (c == '+') return 62;
	if (c == '/') return 63;
	return -1;
}

static uint8_t* decodeBase64(const char* src, size_t src_len, size_t* out_len)
{
	if (!src || src_len == 0) {
		*out_len = 0;
		return NULL;
	}
	uint8_t* out = (uint8_t*)malloc(src_len * 3 / 4 + 4);
	if (!out) {
		*out_len = 0;
		return NULL;
	}

	size_t o = 0;
	uint32_t val = 0;
	int bits = 0;

	for (size_t i = 0; i < src_len; i++)
	{
		char c = src[i];
		if (c == '=') break;
		int d = b64CharValue(c);
		if (d < 0) continue;

		val = (val << 6) | (uint32_t)d;
		bits += 6;
		if (bits >= 8)
		{
			bits -= 8;
			out[o++] = (uint8_t)((val >> bits) & 0xff);
			val &= ((1U << bits) - 1);
		}
	}

	if (o == 0)
	{
		free(out);
		*out_len = 0;
		return NULL;
	}

	*out_len = o;
	return out;
}

typedef struct {
	uint8_t* data;
	size_t len;
	size_t cap;
} KcBuffer;

static void kcBufInit(KcBuffer* b) {
	b->data = NULL;
	b->len = 0;
	b->cap = 0;
}

static void kcBufFree(KcBuffer* b) {
	free(b->data);
	b->data = NULL;
	b->len = 0;
	b->cap = 0;
}

static bool kcBufAppend(KcBuffer* b, const void* ptr, size_t size) {
	if (b->len + size > b->cap) {
		size_t new_cap = (b->cap == 0) ? 4096 : (b->cap * 2);
		while (new_cap < b->len + size) new_cap *= 2;
		uint8_t* new_data = (uint8_t*)realloc(b->data, new_cap);
		if (!new_data) return false;
		b->data = new_data;
		b->cap = new_cap;
	}
	memcpy(b->data + b->len, ptr, size);
	b->len += size;
	return true;
}

static bool kcBufWriteU32Be(KcBuffer* b, uint32_t val) {
	uint8_t bytes[4];
	bytes[0] = (uint8_t)((val >> 24) & 0xff);
	bytes[1] = (uint8_t)((val >> 16) & 0xff);
	bytes[2] = (uint8_t)((val >> 8) & 0xff);
	bytes[3] = (uint8_t)(val & 0xff);
	return kcBufAppend(b, bytes, 4);
}

static bool kcBufPad(KcBuffer* b, size_t alignment) {
	while (b->len % alignment != 0) {
		uint8_t zero = 0;
		if (!kcBufAppend(b, &zero, 1)) return false;
	}
	return true;
}

static bool buildKeychainData(KcBuffer* b, uint8_t** certs_der, size_t* certs_len, size_t cert_count)
{
	kcBufInit(b);

	// ApplDbHeader
	if (!kcBufAppend(b, "kych", 4)) return false;
	kcBufWriteU32Be(b, 0x00010000);  // version: HeaderVersion = 0x00010000
	kcBufWriteU32Be(b, 20);          // header_size
	kcBufWriteU32Be(b, 20);          // schema_offset
	kcBufWriteU32Be(b, 0);           // auth_offset

	// ApplDbSchema
	kcBufWriteU32Be(b, 0);  // schema_size
	kcBufWriteU32Be(b, 1);  // table_count
	kcBufWriteU32Be(b, 12); // table_offset (relative to schema_offset)

	// TableHeader
	kcBufWriteU32Be(b, 0);          // table_size
	kcBufWriteU32Be(b, 0x80001000); // table_id: X509_CERTIFICATE
	kcBufWriteU32Be(b, (uint32_t)cert_count); // record_count
	kcBufWriteU32Be(b, 0);          // records
	kcBufWriteU32Be(b, 0);          // indexes_offset
	kcBufWriteU32Be(b, 0);          // free_list_head
	kcBufWriteU32Be(b, 0);          // record_numbers_count

	if (cert_count == 0)
		return true;

	// Precompute record offsets relative to (schema_offset + table_offset)
	uint32_t cur_offset = (uint32_t)(28 + cert_count * 4);
	for (size_t i = 0; i < cert_count; i++)
	{
		if (cur_offset % 4 != 0)
			cur_offset += 4 - (cur_offset % 4);
		kcBufWriteU32Be(b, cur_offset);
		cur_offset += (uint32_t)(60 + certs_len[i]);
	}

	// Records
	for (size_t i = 0; i < cert_count; i++)
	{
		kcBufPad(b, 4);
		uint32_t rec_size = (uint32_t)(60 + certs_len[i]);
		uint32_t rec_num = (uint32_t)(i + 1);

		kcBufWriteU32Be(b, rec_size);
		kcBufWriteU32Be(b, rec_num);
		kcBufWriteU32Be(b, 0);
		kcBufWriteU32Be(b, 0);
		kcBufWriteU32Be(b, (uint32_t)certs_len[i]);

		for (int z = 0; z < 10; z++)
			kcBufWriteU32Be(b, 0);

		kcBufAppend(b, certs_der[i], certs_len[i]);
	}

	kcBufPad(b, 4);
	return true;
}

static bool writeAtomicFile(const char* targetPath, const void* data, size_t len)
{
	char tmpPath[4096];
	snprintf(tmpPath, sizeof(tmpPath), "%s.tmp.%d", targetPath, (int)getpid());

	FILE* f = fopen(tmpPath, "wb");
	if (!f) return false;

	if (len > 0 && fwrite(data, 1, len, f) != len)
	{
		fclose(f);
		unlink(tmpPath);
		return false;
	}

	fclose(f);
	if (rename(tmpPath, targetPath) != 0)
	{
		unlink(tmpPath);
		return false;
	}
	return true;
}

static void parsePemCertsFromFile(const char* filePath, uint8_t*** der_certs, size_t** der_lens, size_t* cert_count, size_t* max_certs)
{
	FILE* f = fopen(filePath, "rb");
	if (!f) return;

	fseek(f, 0, SEEK_END);
	long fsize = ftell(f);
	fseek(f, 0, SEEK_SET);
	if (fsize <= 0 || fsize > 32 * 1024 * 1024)
	{
		fclose(f);
		return;
	}

	char* pem = (char*)malloc(fsize + 1);
	if (!pem)
	{
		fclose(f);
		return;
	}
	if (fread(pem, 1, fsize, f) != (size_t)fsize)
	{
		free(pem);
		fclose(f);
		return;
	}
	fclose(f);
	pem[fsize] = '\0';

	const char* begin_tag = "-----BEGIN CERTIFICATE-----";
	const char* end_tag = "-----END CERTIFICATE-----";
	size_t begin_len = strlen(begin_tag);
	size_t end_len = strlen(end_tag);

	char* pos = pem;
	while (pos && *pos)
	{
		char* b = strstr(pos, begin_tag);
		if (!b) break;
		char* e = strstr(b + begin_len, end_tag);
		if (!e) break;

		char* b64_start = b + begin_len;
		size_t b64_len = e - b64_start;

		size_t der_len = 0;
		uint8_t* der = decodeBase64(b64_start, b64_len, &der_len);
		if (der && der_len > 0)
		{
			if (*cert_count >= *max_certs)
			{
				*max_certs *= 2;
				*der_certs = (uint8_t**)realloc(*der_certs, *max_certs * sizeof(uint8_t*));
				*der_lens = (size_t*)realloc(*der_lens, *max_certs * sizeof(size_t));
			}
			(*der_certs)[*cert_count] = der;
			(*der_lens)[*cert_count] = der_len;
			(*cert_count)++;
		}
		else if (der)
		{
			free(der);
		}
		pos = e + end_len;
	}

	free(pem);
}

static void ensureKeychains(const char* prefixPath)
{
	const char* bundlePath = findHostCaBundle();
	if (!bundlePath)
		return;

	struct stat st_bundle;
	if (stat(bundlePath, &st_bundle) != 0)
		return;

	char rootKeychainPath[4096];
	char sysKeychainPath[4096];
	char rootKcDir[4096];
	char sysKcDir[4096];

	snprintf(rootKcDir, sizeof(rootKcDir), "%s/System/Library/Keychains", prefixPath);
	snprintf(rootKeychainPath, sizeof(rootKeychainPath), "%s/SystemRootCertificates.keychain", rootKcDir);

	snprintf(sysKcDir, sizeof(sysKcDir), "%s/Library/Keychains", prefixPath);
	snprintf(sysKeychainPath, sizeof(sysKeychainPath), "%s/System.keychain", sysKcDir);

	struct stat st_kc;
	bool rootExists = (stat(rootKeychainPath, &st_kc) == 0);
	bool sysExists = (access(sysKeychainPath, F_OK) == 0);

	if (rootExists && sysExists && st_kc.st_mtime >= st_bundle.st_mtime)
		return;

	char sysDir[4096];
	char sysLibDir[4096];
	char libDir[4096];

	snprintf(sysDir, sizeof(sysDir), "%s/System", prefixPath);
	snprintf(sysLibDir, sizeof(sysLibDir), "%s/System/Library", prefixPath);
	snprintf(libDir, sizeof(libDir), "%s/Library", prefixPath);

	createDir(sysDir);
	createDir(sysLibDir);
	createDir(rootKcDir);

	createDir(libDir);
	createDir(sysKcDir);

	if (!sysExists)
	{
		KcBuffer emptyBuf;
		if (buildKeychainData(&emptyBuf, NULL, NULL, 0))
		{
			writeAtomicFile(sysKeychainPath, emptyBuf.data, emptyBuf.len);
			kcBufFree(&emptyBuf);
		}
	}

	size_t max_certs = 512;
	uint8_t** der_certs = (uint8_t**)malloc(max_certs * sizeof(uint8_t*));
	size_t* der_lens = (size_t*)malloc(max_certs * sizeof(size_t));
	size_t cert_count = 0;

	if (S_ISDIR(st_bundle.st_mode))
	{
		DIR* d = opendir(bundlePath);
		if (d)
		{
			struct dirent* ent;
			while ((ent = readdir(d)) != NULL)
			{
				if (ent->d_name[0] == '.') continue;
				char certPath[4096];
				snprintf(certPath, sizeof(certPath), "%s/%s", bundlePath, ent->d_name);
				parsePemCertsFromFile(certPath, &der_certs, &der_lens, &cert_count, &max_certs);
			}
			closedir(d);
		}
	}
	else
	{
		parsePemCertsFromFile(bundlePath, &der_certs, &der_lens, &cert_count, &max_certs);
	}

	if (cert_count > 0)
	{
		KcBuffer kcBuf;
		if (buildKeychainData(&kcBuf, der_certs, der_lens, cert_count))
		{
			writeAtomicFile(rootKeychainPath, kcBuf.data, kcBuf.len);
			kcBufFree(&kcBuf);
		}
	}

	for (size_t i = 0; i < cert_count; i++)
		free(der_certs[i]);
	free(der_certs);
	free(der_lens);
}

// Minimal validation: only digits and dots, length <= 32, no leading/trailing/consecutive dots
static bool isValidVersionFormat(const char* version)
{
	if (!version || *version == '\0')
		return false;

	size_t len = strlen(version);
	if (len > 32)
		return false;

	bool has_digit = false;
	for (size_t i = 0; i < len; i++)
	{
		char c = version[i];
		if (c >= '0' && c <= '9')
			has_digit = true;
		else if (c == '.')
		{
			if (i == 0 || i == len - 1 || version[i + 1] == '.')
				return false;
		}
		else
			return false;
	}

	return has_digit;
}

// Maps macOS major release to corresponding iOSSupportVersion
static void getIOSSupportVersion(const char* macosVersion, char* dst, size_t dst_size)
{
	int major = 0;
	if (sscanf(macosVersion, "%d", &major) == 1)
	{
		if (major >= 11 && major <= 20)
			snprintf(dst, dst_size, "%d.0", major + 3);
		else if (major >= 26)
			snprintf(dst, dst_size, "19.0");
		else
			snprintf(dst, dst_size, "%s", macosVersion);
	}
	else
	{
		snprintf(dst, dst_size, "%s", macosVersion);
	}
}

static bool writeSystemVersionPlist(const char* prefixPath, const char* version)
{
	char plistPath[4096];
	snprintf(plistPath, sizeof(plistPath), "%s/System/Library/CoreServices/SystemVersion.plist", prefixPath);

	char dirPath[4096];
	snprintf(dirPath, sizeof(dirPath), "%s/System/Library/CoreServices", prefixPath);
	createDir(dirPath);

	char iosVersion[64];
	getIOSSupportVersion(version, iosVersion, sizeof(iosVersion));

	FILE* f = fopen(plistPath, "w");
	if (!f)
		return false;

	fprintf(f,
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
		"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
		"<plist version=\"1.0\">\n"
		"<dict>\n"
		"\t<key>ProductBuildVersion</key>\n"
		"\t<string>Darling</string>\n"
		"\t<key>ProductCopyright</key>\n"
		"\t<string>2012-2023 Lubos Dolezel</string>\n"
		"\t<key>ProductName</key>\n"
		"\t<string>macOS</string>\n"
		"\t<key>ProductUserVisibleVersion</key>\n"
		"\t<string>%s</string>\n"
		"\t<key>ProductVersion</key>\n"
		"\t<string>%s</string>\n"
		"\t<key>iOSSupportVersion</key>\n"
		"\t<string>%s</string>\n"
		"</dict>\n"
		"</plist>\n",
		version, version, iosVersion
	);
	fclose(f);
	return true;
}

// Note: This parser assumes a well-formed single-line plist structure as produced
// by writeSystemVersionPlist. It is not an arbitrary XML parser.
static char* readSystemVersionFromPlist(const char* prefixPath)
{
	char plistPath[4096];
	snprintf(plistPath, sizeof(plistPath), "%s/System/Library/CoreServices/SystemVersion.plist", prefixPath);

	FILE* f = fopen(plistPath, "r");
	if (!f)
		return NULL;

	char line[512];
	bool nextIsVersion = false;
	char* version = NULL;

	while (fgets(line, sizeof(line), f))
	{
		if (strstr(line, "<key>ProductVersion</key>"))
		{
			nextIsVersion = true;
			continue;
		}
		if (nextIsVersion)
		{
			char* start = strstr(line, "<string>");
			char* end = strstr(line, "</string>");
			if (start && end && end > start)
			{
				start += 8;
				*end = '\0';
				version = strdup(start);
				break;
			}
			nextIsVersion = false;
		}
	}
	fclose(f);
	return version;
}

static void ensureSystemVersion(const char* prefixPath)
{
	const char* envVersion = getenv("DARLING_OS_VERSION");
	if (!envVersion)
		envVersion = getenv("DARLING_MACOS_VERSION");

	if (envVersion && envVersion[0] != '\0')
	{
		if (!isValidVersionFormat(envVersion))
		{
			fprintf(stderr, "darling: warning: invalid DARLING_OS_VERSION '%s' ignored (must be numeric, e.g. 11.7.4, 26.0)\n", envVersion);
			return;
		}

		char* cur = readSystemVersionFromPlist(prefixPath);
		if (!cur || strcmp(cur, envVersion) != 0)
		{
			fprintf(stderr, "darling: Note: DARLING_OS_VERSION overrides advertised macOS version to %s\n", envVersion);
			writeSystemVersionPlist(prefixPath, envVersion);
		}
		if (cur) free(cur);
	}
	else
	{
		char plistPath[4096];
		snprintf(plistPath, sizeof(plistPath), "%s/System/Library/CoreServices/SystemVersion.plist", prefixPath);
		if (access(plistPath, F_OK) != 0)
		{
			writeSystemVersionPlist(prefixPath, "26.0");
		}
	}
}

int main(int argc, char ** argv)
{
	pid_t pidInit;

	if (argc <= 1)
	{
		showHelp(argv[0]);
		return 1;
	}

	g_originalUid = getuid();
	g_originalGid = getgid();

	// Full non-root mode (e.g. Android): no user namespaces, no mount
	// permissions at all. The container runs without any namespace
	// isolation: the prefix is a plain directory and /proc is the real
	// (shared) procfs, exposed to the container via a symlink.
	g_nonroot = (getenv("DARLING_NONROOT") != NULL || geteuid() != 0);
	if (g_nonroot)
	{
		g_rootless = true;
		// Non-root mode must never keep the privileges the setuid bit grants.
		// If we were started with elevated privileges (running under AT_SECURE,
		// or with an effective uid/gid that differs from the real one),
		// permanently drop back to the real user before touching the filesystem
		// or spawning anything. A genuinely unprivileged, non-setuid run has
		// nothing to drop and its behaviour is unchanged.
		if (getauxval(AT_SECURE) || geteuid() != getuid() || getegid() != getgid())
		{
			if (!dropPrivilegesPermanently(g_originalUid, g_originalGid))
			{
				fprintf(stderr, "Failed to drop privileges for non-root mode.\n");
				return 1;
			}
		}
	}
	else
	{
		setuid(0);
		setgid(0);
		g_rootless = (geteuid() != 0);
	}

	enum darling_prefix_error prefixError;
	prefix = darlingSelectPrefix(getenv("DPREFIX"), getenv("DARLING_PROFILE"),
		getenv("HOME"), &prefixError);
	if (!prefix) {
		fprintf(stderr, "%s.\n", darlingPrefixError(prefixError));
		return 1;
	}
	unsetenv("DPREFIX");
	unsetenv("DARLING_PROFILE");
	getcwd(g_workingDirectory, sizeof(g_workingDirectory));

	if (!checkPrefixDir())
	{
		checkPrefixCreatable();
		setupPrefix();
		g_fixPermissions = true;
	}
	checkPrefixOwner();

	// These only act on the invoking user's prefix, through paths the user
	// controls, so run them with the user's ids (as setupPrefix() does).
	useOriginalIds();
	if (g_nonroot)
		ensureProcSymlink(prefix);
	else if (!darlingEnsureProcDir(prefix))
	{
		fprintf(stderr, "Cannot replace %s/proc with a directory: %s\n", prefix, strerror(errno));
		return 1;
	}
	ensureHostRootSymlinks(prefix);
	ensureShSymlink(prefix);
	ensureHomebrewSymlinks(prefix);
	ensureKeychains(prefix);
	ensureSystemVersion(prefix);
	restoreRootIds();

	int c;
	while (1)
	{
		static struct option long_options[] =
		{
			{"help", 	no_argument, 0, 0},
			{"version", no_argument, 0, 0},
			{0, 		0, 			 0, 0}
		};
		int option_index = 0;

		c = getopt_long(argc, argv, "+", long_options, &option_index);

		if (c == -1)
		{
			break;
		}

		switch (c)
		{
			case 0:
			if (strcmp(long_options[option_index].name, "help") == 0)
			{
				showHelp(argv[0]);
				exit(EXIT_SUCCESS);
			}
			else if (strcmp(long_options[option_index].name, "version") == 0)
			{
				showVersion(argv[0]);
				exit(EXIT_SUCCESS);
			}
			break;
			case '?':
			break;
			default:
			abort();
		}
	}

	pidInit = getInitProcess();

	if (strcmp(argv[1], "os-version") == 0)
	{
		useOriginalIds();
		if (argc <= 2 || strcmp(argv[2], "get") == 0)
		{
			char* cur = readSystemVersionFromPlist(prefix);
			printf("%s\n", cur ? cur : "26.0");
			if (cur) free(cur);
			restoreRootIds();
			return 0;
		}
		else if (strcmp(argv[2], "set") == 0)
		{
			if (argc <= 3)
			{
				fprintf(stderr, "Usage: %s os-version set <version>\n", argv[0]);
				restoreRootIds();
				return 1;
			}
			const char* ver = argv[3];
			if (!isValidVersionFormat(ver))
			{
				fprintf(stderr, "error: invalid macOS version format '%s' (expected numeric, e.g. 11.7.4, 12.0, 26.0)\n", ver);
				restoreRootIds();
				return 1;
			}
			if (writeSystemVersionPlist(prefix, ver))
			{
				printf("macOS version for prefix %s set to %s\n", prefix, ver);
				restoreRootIds();
				return 0;
			}
			else
			{
				fprintf(stderr, "Failed to write SystemVersion.plist for prefix %s\n", prefix);
				restoreRootIds();
				return 1;
			}
		}
		else if (strcmp(argv[2], "reset") == 0)
		{
			if (writeSystemVersionPlist(prefix, "26.0"))
			{
				printf("macOS version for prefix %s reset to default (26.0)\n", prefix);
				restoreRootIds();
				return 0;
			}
			else
			{
				fprintf(stderr, "Failed to reset SystemVersion.plist for prefix %s\n", prefix);
				restoreRootIds();
				return 1;
			}
		}
		else
		{
			fprintf(stderr, "Unknown os-version command '%s'. Usage: %s os-version [get | set <version> | reset]\n", argv[2], argv[0]);
			restoreRootIds();
			return 1;
		}
	}

	if (strcmp(argv[1], "shutdown") == 0)
	{
		pid_t pidInit = getInitProcess();
		if (pidInit > 0)
		{
			int handle = shutdownHandle(pidInit);
			if (handle < 0 || !shutdownServerMatches(pidInit, prefix))
			{
				if (handle >= 0) close(handle);
				fprintf(stderr, "Cannot verify this prefix's server for shutdown.\n");
				return 1;
			}
			int shellHandle = -1;
			pid_t shellspawn = g_nonroot ? shellspawnPeer(&shellHandle) : 0;
			if (g_nonroot && shellHandle < 0)
			{
				close(handle);
				fprintf(stderr, "Cannot obtain nonroot shellspawn process handle; shutdown refused.\n");
				return 1;
			}
			bool stopped = shutdownContainer(pidInit, handle, shellspawn, shellHandle);
			if (shellHandle >= 0) close(shellHandle);
			close(handle);
			if (!stopped)
			{
				fprintf(stderr, "Container shutdown incomplete; refusing broader cleanup.\n");
				return 1;
			}
		}

		char socketPath[4096];
		snprintf(socketPath, sizeof(socketPath), "%s" SHELLSPAWN_SOCKPATH, prefix);

		char pidPath[4096];
		snprintf(pidPath, sizeof(pidPath), "%s/.init.pid", prefix);

		char dserverSock[4096];
		snprintf(dserverSock, sizeof(dserverSock), "%s/.darlingserver.sock", prefix);

		// These paths are inside the user's prefix (the socket path also goes
		// through var/run), so remove them with the user's ids.
		useOriginalIds();
		unlink(socketPath);
		unlink(pidPath);
		unlink(dserverSock);
		char shellPidPath[4096];
		snprintf(shellPidPath, sizeof(shellPidPath), "%s/.shellspawn.pid", prefix);
		unlink(shellPidPath);
		restoreRootIds();

		fprintf(stderr, "Darling container shut down successfully.\n");
		return 0;
	}

	// If prefix's init is not running, start it up
	if (pidInit == 0)
	{
		char socketPath[4096];
		
		snprintf(socketPath, sizeof(socketPath), "%s"  SHELLSPAWN_SOCKPATH, prefix);

		char dserverSock[4096];
		snprintf(dserverSock, sizeof(dserverSock), "%s/.darlingserver.sock", prefix);

		// Stale sockets inside the user's prefix: remove them with the user's ids.
		useOriginalIds();
		unlink(socketPath);
		unlink(dserverSock);
		restoreRootIds();
		
		setupWorkdir();
		pidInit = spawnInitProcess();
		putInitPid(pidInit);
		
		if (g_nonroot)
			spawnShellspawn();

		// Wait until shellspawn starts. The socket lives inside the user's prefix
		// and is created by shellspawn with mode 0600 owned by the user, so probe
		// it with the user's ids rather than as root.
		for (int i = 0; i < SHELLSPAWN_WAIT_RETRIES; i++)
		{
			if (existsAsOriginalUser(socketPath) == 0)
				break;
			usleep(50000);
		}

		if (existsAsOriginalUser(socketPath) != 0)
		{
			fprintf(stderr, "Timed out waiting for shellspawn in container\n");
			return 1;
		}
	}
	else if (g_nonroot)
	{
		char socketPath[4096];
		snprintf(socketPath, sizeof(socketPath), "%s" SHELLSPAWN_SOCKPATH, prefix);
		if (existsAsOriginalUser(socketPath) != 0)
		{
			spawnShellspawn();
			for (int i = 0; i < SHELLSPAWN_WAIT_RETRIES; i++)
			{
				if (existsAsOriginalUser(socketPath) == 0)
					break;
				usleep(50000);
			}
			if (existsAsOriginalUser(socketPath) != 0)
			{
				fprintf(stderr, "Timed out waiting for shellspawn in container\n");
				return 1;
			}
		}
	}

#if USE_LINUX_4_11_HACK
	// In non-root mode there is no mount namespace (prefix is a plain dir,
	// /proc is the real shared procfs), so the shellspawn socket is
	// resolvable directly and joining is skipped.
	if (!g_nonroot)
		joinNamespace(pidInit, CLONE_NEWNS, "mnt");
#endif

	useOriginalIds();

	if (strcmp(argv[1], "toolchain") == 0)
	{
		if (argc <= 2 || strcmp(argv[2], "help") == 0)
		{
			fprintf(stderr, "Usage:\n"
			                "\t%s toolchain install <swift>\n", argv[0]);
			return (argc <= 2) ? 1 : 0;
		}

		if (strcmp(argv[2], "install") == 0)
		{
			const char* target = (argc > 3) ? argv[3] : "swift";
			if (strcmp(target, "swift") == 0)
			{
				// Runs swift_install.sh inside the container prefix (requires network access and curl/wget).
				const char* cmd[] = { "/usr/libexec/darling/swift_install.sh", NULL };
				spawnShell(cmd);
				// TODO: propagate exit status from spawnShell once supported by shellspawn protocol
				return 0;
			}
			else
			{
				fprintf(stderr, "Unknown toolchain '%s'. Available toolchains: swift\n", target);
				return 1;
			}
		}
		else
		{
			fprintf(stderr, "Unknown toolchain action '%s'. Usage: %s toolchain install <swift>\n", argv[2], argv[0]);
			return 1;
		}
	}

	if (strcmp(argv[1], "shell") == 0)
	{
		// Spawn the shell
		if (argc > 2)
			spawnShell((const char**) &argv[2]);
		else
			spawnShell(NULL);
	}
	else
	{
		bool doExec = strcmp(argv[1], "exec") == 0;
		int argvIndex = doExec ? 2 : 1;

		if (doExec && argc <= 2)
		{
			printf("'exec' subcommand requires a binary to execute.\n");
			return 1;
		}

		char *fullPath = NULL;
		const char *prog = argv[argvIndex];

		bool isContainerPath = false;
		if (prog[0] == '/')
		{
			if (strncmp(prog, "/Volumes/", 9) == 0 ||
			    strncmp(prog, "/bin/", 5) == 0 ||
			    strncmp(prog, "/sbin/", 6) == 0 ||
			    strncmp(prog, "/usr/", 5) == 0 ||
			    strncmp(prog, "/System/", 8) == 0 ||
			    strncmp(prog, "/Library/", 9) == 0 ||
			    strncmp(prog, "/Applications/", 14) == 0 ||
			    strncmp(prog, "/private/", 9) == 0 ||
			    strncmp(prog, "/etc/", 5) == 0 ||
			    strncmp(prog, "/tmp/", 5) == 0 ||
			    strncmp(prog, "/var/", 5) == 0 ||
			    strncmp(prog, "/dev/", 5) == 0 ||
			    strncmp(prog, "/proc/", 6) == 0)
			{
				isContainerPath = true;
			}
		}

		if (isContainerPath)
		{
			fullPath = strdup(prog);
		}
		else
		{
			char *path = realpath(prog, NULL);
			// On Android, host /bin points to /system/bin (toybox), do NOT treat /system/bin as host app unless explicitly requested with /system/
			if (path != NULL && !(strncmp(path, "/system/", 8) == 0 && strncmp(prog, "/system/", 8) != 0))
			{
				fullPath = malloc(strlen(SYSTEM_ROOT) + strlen(path) + 1);
				strcpy(fullPath, SYSTEM_ROOT);
				strcat(fullPath, path);
				free(path);
			}
			else
			{
				if (path) free(path);
				if (doExec)
				{
					if (prog[0] == '/')
					{
						fullPath = strdup(prog);
					}
					else
					{
						char testPath[4096];
						const char* testDirs[] = {"/usr/bin", "/bin", "/usr/sbin", "/sbin"};
						bool found = false;
						for (size_t i = 0; i < sizeof(testDirs)/sizeof(testDirs[0]); i++)
						{
							snprintf(testPath, sizeof(testPath), "%s%s/%s", prefix, testDirs[i], prog);
							if (access(testPath, X_OK) == 0)
							{
								snprintf(testPath, sizeof(testPath), "%s/%s", testDirs[i], prog);
								fullPath = strdup(testPath);
								found = true;
								break;
							}
						}
						if (!found)
						{
							snprintf(testPath, sizeof(testPath), "/usr/bin/%s", prog);
							fullPath = strdup(testPath);
						}
					}
				}
				else
				{
					fullPath = strdup(prog);
				}
			}
		}

		argv[argvIndex] = fullPath;

		if (doExec)
			spawnBinary(argv[argvIndex], (const char**) &argv[argvIndex]);
		else
			spawnShell((const char**) &argv[argvIndex]);
	}

	return 0;
}

void joinNamespace(pid_t pid, int type, const char* typeName)
{
	int fdNS;
	char pathNS[4096];
	
	snprintf(pathNS, sizeof(pathNS), "/proc/%d/ns/%s", pid, typeName);

	fdNS = open(pathNS, O_RDONLY);

	if (fdNS < 0)
	{
		fprintf(stderr, "Cannot open %s namespace file: %s\n", typeName, strerror(errno));
		exit(1);
	}

	// Calling setns() with a PID namespace doesn't move our process into it,
	// but our child process will be spawned inside the namespace
	if (setns(fdNS, type) != 0)
	{
		fprintf(stderr, "Cannot join %s namespace: %s\n", typeName, strerror(errno));
		exit(1);
	}
	close(fdNS);
}

static void pushShellspawnCommandData(int sockfd, shellspawn_cmd_type_t type, const void* data, size_t data_length)
{
	struct shellspawn_cmd* cmd;
	size_t length;

	length = sizeof(*cmd) + data_length;

	cmd = (struct shellspawn_cmd*) malloc(length);
	cmd->cmd = type;
	cmd->data_length = data_length;

	if (data != NULL)
		memcpy(cmd->data, data, data_length);

	if (write(sockfd, cmd, length) != length)
	{
		fprintf(stderr, "Error sending command to shellspawn: %s\n", strerror(errno));
		exit(EXIT_FAILURE);
	}

	free(cmd);
}

static void pushShellspawnCommand(int sockfd, shellspawn_cmd_type_t type, const char* value)
{
	if (!value)
		pushShellspawnCommandData(sockfd, type, NULL, 0);
	else
		pushShellspawnCommandData(sockfd, type, value, strlen(value) + 1);
}

static void pushShellspawnCommandFDs(int sockfd, shellspawn_cmd_type_t type, const int fds[3])
{
	struct shellspawn_cmd cmd;
	char cmsgbuf[CMSG_SPACE(sizeof(int) * 3)];
	struct msghdr msg;
	struct iovec iov;
	struct cmsghdr *cmptr;

	cmd.cmd = type;
	cmd.data_length = 0;

	iov.iov_base = &cmd;

	memset(&msg, 0, sizeof(msg));
	msg.msg_control = cmsgbuf;
	msg.msg_controllen = sizeof(cmsgbuf);

	iov.iov_base = &cmd;
	iov.iov_len = sizeof(cmd);
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;

	cmptr = CMSG_FIRSTHDR(&msg);
	cmptr->cmsg_len = CMSG_LEN(sizeof(int) * 3);
	cmptr->cmsg_level = SOL_SOCKET;
	cmptr->cmsg_type = SCM_RIGHTS;
	memcpy(CMSG_DATA(cmptr), fds, sizeof(fds[0])*3);

	if (sendmsg(sockfd, &msg, 0) < 0)
	{
		fprintf(stderr, "Error sending command to shellspawn: %s\n", strerror(errno));
		exit(EXIT_FAILURE);
	}
}

static int _shSockfd = -1;
static struct termios orig_termios;
static int pty_master;
static void signalHandler(int signo)
{
	// printf("Received signal %d\n", signo);

	// Forward window size changes
	if (signo == SIGWINCH && pty_master != -1)
	{
		struct winsize win;

		ioctl(0, TIOCGWINSZ, &win);
		ioctl(pty_master, TIOCSWINSZ, &win);
	}
	
	// Foreground process loopkup in shellspawn doesn't work
	// if we're not running in TTY mode, so shellspawn falls back
	// to forwarding signals to the Bash subprocess.
	// 
	// Hence we translate SIGINT to SIGTERM for user convenience,
	// because Bash will not terminate on SIGINT.
	if (pty_master == -1 && signo == SIGINT)
		signo = SIGTERM;

	pushShellspawnCommandData(_shSockfd, SHELLSPAWN_SIGNAL, &signo, sizeof(signo));
}

static void shellLoop(int sockfd, int master)
{
	struct sigaction sa;
	struct pollfd pfds[3];
	const int fdcount = (master != -1) ? 3 : 1; // do we do pty proxying?

	// Vars for signal handler
	_shSockfd = sockfd;
	pty_master = master;

	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = signalHandler;
	sigfillset(&sa.sa_mask);

	for (int i = 1; i < 32; i++)
		sigaction(i, &sa, NULL);

	pfds[2].fd = master;
	pfds[2].events = POLLIN;
	pfds[2].revents = 0;
	pfds[1].fd = STDIN_FILENO;
	pfds[1].events = POLLIN;
	pfds[1].revents = 0;
	pfds[0].fd = sockfd;
	pfds[0].events = POLLIN;
	pfds[0].revents = 0;

	if (master != -1)
		fcntl(master, F_SETFL, O_NONBLOCK);
	//fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK);
	fcntl(sockfd, F_SETFL, O_NONBLOCK);

	while (1)
	{
		char buf[4096];

		if (poll(pfds, fdcount, -1) < 0)
		{
			if (errno != EINTR)
			{
				perror("poll");
				break;
			}
		}

		if (pfds[2].revents & POLLIN)
		{
			int rd;
			do
			{
				rd = read(master, buf, sizeof(buf));
				if (rd > 0)
					write(STDOUT_FILENO, buf, rd);
			}
			while (rd == sizeof(buf));
		}

		if (pfds[1].revents & POLLIN)
		{
			int rd = 0;
			do
			{
				if (ioctl(STDIN_FILENO, FIONREAD, &rd) < 0) {
					perror("ioctl");
					exit(1);
				}
				if (rd > sizeof(buf)) {
					rd = sizeof(buf);
				}
				rd = read(STDIN_FILENO, buf, rd);
				if (rd > 0)
					write(master, buf, rd);
				else {
					perror("read");
					exit(1);
				}
			}
			while (rd == sizeof(buf));
		}

		if (pfds[0].revents & (POLLHUP | POLLIN))
		{
			int exitStatus;
			
			if (read(sockfd, &exitStatus, sizeof(int)) == sizeof(int))
				exit(exitStatus);
			else
				exit(1);
		}
	}
}

static void restoreTermios(void)
{
	tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
}

// Glibc openpty() fails for me on Debian, because grantpty() fails to chown() the pty node with error code EPERM.
// This is a more lenient version of openpty() that just works.
static int openpty_darling(int* amaster, int* aslave, char* name_unused, const struct termios* tos, const struct winsize* wsz)
{
	const char* slave_name;

	*amaster = posix_openpt(O_RDWR);
	if (*amaster == -1)
		return -1;

	grantpt(*amaster);
	if (unlockpt(*amaster) < 0)
		return -1;

	slave_name = ptsname(*amaster);
	*aslave = open(slave_name, O_RDWR | O_NOCTTY);
	if (*aslave == -1)
		return -1;

	if (tos != NULL)
		tcsetattr(*amaster, TCSANOW, tos);
	if (wsz != NULL)
		ioctl(*amaster, TIOCSWINSZ, wsz);

	return 0;
}

static void setupPtys(int fds[3], int* master)
{
	struct winsize win;
	struct termios termios;
	bool tty = true;

	if (tcgetattr(STDIN_FILENO, &termios) < 0)
		tty = false;

	if (openpty_darling(master, &fds[0], NULL, &termios, NULL) < 0)
	{
		perror("openpty");
		exit(1);
	}
	fds[2] = fds[1] = fds[0];

	if (tty)
	{
		orig_termios = termios;

		ioctl(0, TIOCGWINSZ, &win);

		termios.c_lflag &= ~(ICANON | ISIG | IEXTEN | ECHO);
		termios.c_iflag &= ~(BRKINT | ICRNL | IGNBRK | IGNCR | INLCR |
				INPCK | ISTRIP | IXON | PARMRK);
		termios.c_oflag &= ~OPOST;
		termios.c_cc[VMIN] = 1;
		termios.c_cc[VTIME] = 0;

		if (tcsetattr(STDIN_FILENO, TCSANOW, &termios) < 0)
		{
			perror("tcsetattr");
			exit(1);
		}
		ioctl(*master, TIOCSWINSZ, &win);

		atexit(restoreTermios);
	}
}

// Replace each quote character (') with the sequence '\''
// (copying the result to dest, if non-null)
// and return the length of the result.
static size_t escapeQuotes(char *dest, const char *src)
{
	size_t len = 0;

	for (; *src != 0; src++)
	{
		if (*src == '\'')
		{
			if (dest)
				memcpy(&dest[len], "'\\''", 4);
			len += 4;
		}
		else
		{
			if (dest)
				dest[len] = *src;
			len++;
		}
	}
	if (dest)
		dest[len] = 0;

	return len;
}

int connectToShellspawn(void)
{
	struct sockaddr_un addr;
	int sockfd;

	// Connect to the shellspawn daemon in the container
	addr.sun_family = AF_UNIX;
#if USE_LINUX_4_11_HACK
	addr.sun_path[0] = '\0';
	
	strcpy(addr.sun_path, prefix);
	strcat(addr.sun_path, SHELLSPAWN_SOCKPATH);
#else
	snprintf(addr.sun_path, sizeof(addr.sun_path), "%s"  SHELLSPAWN_SOCKPATH, prefix);
#endif

	sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (sockfd == -1)
	{
		fprintf(stderr, "Error creating a unix domain socket: %s\n", strerror(errno));
		exit(1);
	}

	if (connect(sockfd, (struct sockaddr*) &addr, sizeof(addr)) == -1)
	{
		if (g_nonroot && (errno == ECONNREFUSED || errno == ENOENT))
		{
			close(sockfd);
			unlink(addr.sun_path);
			spawnShellspawn();
			for (int i = 0; i < SHELLSPAWN_WAIT_RETRIES; i++)
			{
				if (access(addr.sun_path, F_OK) == 0)
					break;
				usleep(50000);
			}
			sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
			if (sockfd != -1 && connect(sockfd, (struct sockaddr*) &addr, sizeof(addr)) == 0)
			{
				return sockfd;
			}
		}
		fprintf(stderr, "Error connecting to shellspawn in the container (%s): %s\n", addr.sun_path, strerror(errno));
		exit(1);
	}

	return sockfd;
}

void setupShellspawnEnv(int sockfd)
{
	static const char* skip_vars[] = {
		"PATH",
		"TMPDIR",
		"HOME",
		"PERL5LIB",
	};

	char buffer2[4096];

	// Push environment variables
	pushShellspawnCommand(sockfd, SHELLSPAWN_SETENV, 
		"PATH=/opt/nanobrew/prefix/bin:"
		"/opt/homebrew/bin:"
		"/usr/local/bin:"
		"/usr/bin:"
		"/bin:"
		"/usr/sbin:"
		"/sbin");
	pushShellspawnCommand(sockfd, SHELLSPAWN_SETENV, "TMPDIR=/private/tmp");

	// Ensure native Linux Mesa/Vulkan drivers have a valid, shared host/guest path for shader caches.
	// In rootless Darling, host .so libraries (e.g. Mesa/RADV) execute direct Linux host syscalls,
	// bypassing vchroot. If HOME=/Users/<user> is inherited, Mesa attempts mkdir /Users on the host
	// root, which fails with Permission Denied and disables shader caching entirely.
	// We use /tmp/.darling-shader-cache-<uid> because /tmp is identical in both host and guest namespaces.
	// Note: While /tmp is typically on tmpfs and does not survive host reboots (requiring Mesa to
	// rebuild the cache once per boot session), it guarantees collision-free, ram-speed shader access
	// without needing host-path translation between /home and /Volumes/SystemRoot.
	char shaderCacheDir[4096];
	snprintf(shaderCacheDir, sizeof(shaderCacheDir), "/tmp/.darling-shader-cache-%u", geteuid());
	mkdir(shaderCacheDir, 0700);

	char envShaderCache[4096];
	snprintf(envShaderCache, sizeof(envShaderCache), "MESA_SHADER_CACHE_DIR=%s", shaderCacheDir);
	pushShellspawnCommand(sockfd, SHELLSPAWN_SETENV, envShaderCache);

	// Redirect XDG_CACHE_HOME to /tmp so host Linux libraries (such as Fontconfig or GUI backends)
	// running within Darling can store cache data on the host without failing against non-existent /Users paths.
	char xdgCacheDir[4096];
	snprintf(xdgCacheDir, sizeof(xdgCacheDir), "/tmp/.darling-cache-%u", geteuid());
	mkdir(xdgCacheDir, 0700);

	char envCache[4096];
	snprintf(envCache, sizeof(envCache), "XDG_CACHE_HOME=%s", xdgCacheDir);
	pushShellspawnCommand(sockfd, SHELLSPAWN_SETENV, envCache);
	pushShellspawnCommand(sockfd, SHELLSPAWN_SETENV,
		"PERL5LIB=/System/Library/Perl/5.28:"
		"/System/Library/Perl/5.28/darwin-thread-multi-2level:"
		"/Library/Perl/5.28:"
		"/System/Library/Perl/5.18:"
		"/System/Library/Perl/5.18/darwin-thread-multi-2level:"
		"/Library/Perl/5.18");

	const char* login = NULL;
	struct passwd* pw = getpwuid(geteuid());

	if (pw != NULL)
		login = pw->pw_name;

	if (!login)
		login = getlogin();
	if (!login)
	{
		fprintf(stderr, "Cannot determine your user name\n");
		exit(1);
	}

	snprintf(buffer2, sizeof(buffer2), "HOME=/Users/%s", login);
	pushShellspawnCommand(sockfd, SHELLSPAWN_SETENV, buffer2);

	for (char** var_ptr = environ; *var_ptr != NULL; ++var_ptr) {
		const char* var = *var_ptr;
		const char* equal = strchr(var, '=');
		size_t name_len = (equal != NULL) ? (size_t)(equal - var) : strlen(var);
		bool skip_it = false;

		for (size_t i = 0; i < sizeof(skip_vars) / sizeof(*skip_vars); ++i) {
			if (strlen(skip_vars[i]) == name_len && strncmp(var, skip_vars[i], name_len) == 0) {
				skip_it = true;
				break;
			}
		}

		if (skip_it) {
			continue;
		}

		pushShellspawnCommand(sockfd, SHELLSPAWN_SETENV, var);
	}
}

void setupWorkingDir(int sockfd)
{
	char buffer2[4096];
	snprintf(buffer2, sizeof(buffer2), SYSTEM_ROOT "%s", g_workingDirectory);
	pushShellspawnCommand(sockfd, SHELLSPAWN_CHDIR, buffer2);
}

void setupIDs(int sockfd)
{
	int ids[2] = { g_originalUid, g_originalGid };
	pushShellspawnCommandData(sockfd, SHELLSPAWN_SETUIDGID, ids, sizeof(ids));
}

void setupFDs(int fds[3], int* master)
{
	*master = -1;

	if (isatty(STDIN_FILENO))
		setupPtys(fds, master);
	else
		fds[0] = dup(STDIN_FILENO); // dup() because we close() after spawning
	
	if (*master == -1 || !isatty(STDOUT_FILENO))
		fds[1] = STDOUT_FILENO;
	if (*master == -1 || !isatty(STDERR_FILENO))
		fds[2] = STDERR_FILENO;
}

void spawnGo(int sockfd, int fds[3], int master)
{
	pushShellspawnCommandFDs(sockfd, SHELLSPAWN_GO, fds);
	close(fds[0]);

	shellLoop(sockfd, master);
	
	if (master != -1)
		close(master);
	close(sockfd);
}

void spawnShell(const char** argv)
{
	size_t total_len = 0;
	int count;
	int sockfd;
	char* buffer;
	int fds[3], master;

	if (argv != NULL)
	{
		for (count = 0; argv[count] != NULL; count++)
			total_len += escapeQuotes(NULL, argv[count]);

		buffer = malloc(total_len + count*3);

		char *to = buffer;
		for (int i = 0; argv[i] != NULL; i++)
		{
			if (to != buffer)
				to = stpcpy(to, " ");
			to = stpcpy(to, "'");
			to += escapeQuotes(to, argv[i]);
			to = stpcpy(to, "'");
		}
	}
	else
		buffer = NULL;

	sockfd = connectToShellspawn();

	setupShellspawnEnv(sockfd);

	// Push shell arguments
	if (buffer != NULL)
	{
		pushShellspawnCommand(sockfd, SHELLSPAWN_ADDARG, "-c");
		pushShellspawnCommand(sockfd, SHELLSPAWN_ADDARG, buffer);

		free(buffer);
	}

	setupWorkingDir(sockfd);
	setupIDs(sockfd);
	setupFDs(fds, &master);
	spawnGo(sockfd, fds, master);
}

void spawnBinary(const char* binary, const char** argv)
{
	int fds[3], master;
	int sockfd;

	sockfd = connectToShellspawn();
	setupShellspawnEnv(sockfd);

	pushShellspawnCommand(sockfd, SHELLSPAWN_SETEXEC, binary);

	for (; *argv != NULL; ++argv)
		pushShellspawnCommand(sockfd, SHELLSPAWN_ADDARG, *argv);

	setupWorkingDir(sockfd);
	setupIDs(sockfd);
	setupFDs(fds, &master);
	spawnGo(sockfd, fds, master);
}

void showHelp(const char* argv0)
{
	fprintf(stderr, "This is Darling, translation layer for macOS software.\n\n");
	fprintf(stderr, "Copyright (C) 2012-2023 Lubos Dolezel\n\n");

	fprintf(stderr, "Usage:\n");
	fprintf(stderr, "\t%s <program-path> [arguments...]\n", argv0);
	fprintf(stderr, "\t%s shell [arguments...]\n", argv0);
	fprintf(stderr, "\t%s exec <program-path> [arguments...]\n", argv0);
	fprintf(stderr, "\t%s toolchain [install <name>]\n", argv0);
	fprintf(stderr, "\t%s os-version [get | set <version> | reset]\n", argv0);
	fprintf(stderr, "\t%s shutdown\n", argv0);
	fprintf(stderr, "\n");
	fprintf(stderr, "Environment variables:\n"
		"DPREFIX - specifies the location of the Darling prefix, defaults to ~/.darling\n"
		"DARLING_PROFILE - selects an isolated named prefix at ~/.darling.<name>\n"
		"DARLING_OS_VERSION - specifies the advertised macOS version (e.g. 11.7.4, 12.7.4, 26.0)\n");
}

void showVersion(const char* argv0) {
	fprintf(stderr, "%s " GIT_BRANCH " @ " GIT_COMMIT_HASH "\n", argv0);
	fprintf(stderr, "Copyright (C) 2012-2023 Lubos Dolezel\n");
}

void missingSetuidRoot(void)
{
	char path[4096];
	int len;

	len = readlink("/proc/self/exe", path, sizeof(path)-1);
	if (len < 0)
		strcpy(path, "darling");
	else
		path[len] = '\0';

	fprintf(stderr, "Sorry, the `%s' binary is not setuid root, which is mandatory.\n", path);
	fprintf(stderr, "Darling needs this in order to create mount and PID namespaces and to perform mounts.\n");
}

pid_t spawnInitProcess(void)
{
	pid_t pid;
	int pipefd[2];
	char buffer[1];

	if (pipe(pipefd) == -1)
	{
		fprintf(stderr, "Cannot create a pipe for synchronization: %s\n", strerror(errno));
		exit(1);
	}

	// Non-root: no namespaces at all. Rootless: create a user namespace (mapping our own uid/gid to 0),
	// a mount namespace and UTS/IPC namespaces. Inside the user
	// namespace we get CAP_SYS_ADMIN, which darlingserver needs to
	// create a PID namespace for launchd and to do its mounts.
	if (g_nonroot)
	{
		// nothing: no unshare() calls of any kind
	}
	else if (g_rootless)
	{
		if (unshare(CLONE_NEWUSER | CLONE_NEWNS | CLONE_NEWUTS | CLONE_NEWIPC) != 0)
		{
			fprintf(stderr, "Cannot unshare namespaces for rootless mode: %s\n", strerror(errno));
			exit(1);
		}
	}
	else if (unshare(CLONE_NEWUTS | CLONE_NEWIPC) != 0)
	{
		fprintf(stderr, "Cannot unshare UTS and IPC namespaces to create darling-init: %s\n", strerror(errno));
		exit(1);
	}

	pid = fork();

	if (pid < 0)
	{
		fprintf(stderr, "Cannot fork() to create darling-init: %s\n", strerror(errno));
		exit(1);
	}

	if (pid == 0)
	{
		// The child

		char uid_str[21];
		char gid_str[21];
		char pipefd_str[21];

		snprintf(uid_str, sizeof(uid_str), "%d", g_originalUid);
		snprintf(gid_str, sizeof(gid_str), "%d", g_originalGid);
		snprintf(pipefd_str, sizeof(pipefd_str), "%d", pipefd[1]);

		close(pipefd[0]);

		restrictEnvironmentForDarlingserver();

		if (g_nonroot)
		{
			// Tell darlingserver that no namespaces were created and no
			// mounts are possible. It will use a plain directory prefix
			// (copy of the system root) and a symlink for /proc.
			setenv("DARLING_NONROOT", "1", 1);
		}
		else if (g_rootless)
		{
			// Map our real uid/gid to 0 inside the new user namespace so
			// that darlingserver runs as the namespace root and has the
			// CAP_SYS_ADMIN it needs. DARLING_ROOTLESS tells the server
			// that it is inside a user namespace and not real root (the
			// real uid is not mapped into the namespace, so chown(2) to
			// it is not possible).
			FILE* f;

			f = fopen("/proc/self/uid_map", "w");
			if (!f || fprintf(f, "0 %d 1\n", g_originalUid) < 0)
			{
				fprintf(stderr, "Cannot write uid_map: %s\n", strerror(errno));
				exit(1);
			}
			fclose(f);

			f = fopen("/proc/self/setgroups", "w");
			if (f)
			{
				fprintf(f, "deny\n");
				fclose(f);
			}

			f = fopen("/proc/self/gid_map", "w");
			if (!f || fprintf(f, "0 %d 1\n", g_originalGid) < 0)
			{
				fprintf(stderr, "Cannot write gid_map: %s\n", strerror(errno));
				exit(1);
			}
			fclose(f);

			setenv("DARLING_ROOTLESS", "1", 1);
		}

		setsid();
		if (!getenv("DSERVER_LOG_STDERR") && !getenv("DARLING_DEBUG"))
		{
			int devnull = open("/dev/null", O_RDWR);
			if (devnull >= 0)
			{
				dup2(devnull, STDIN_FILENO);
				dup2(devnull, STDOUT_FILENO);
				dup2(devnull, STDERR_FILENO);
				if (devnull > 2)
					close(devnull);
			}
		}

		const char* instPrefix = getInstallPrefix();
		char dserverBin[4096];
		snprintf(dserverBin, sizeof(dserverBin), "%s/bin/darlingserver", instPrefix);
		char libexecPath[4096];
		snprintf(libexecPath, sizeof(libexecPath), "%s/libexec/darling", instPrefix);
		setenv("DARLING_LIBEXEC_PATH", libexecPath, 1);

		execl(dserverBin, "darlingserver", prefix, uid_str, gid_str, pipefd_str, g_fixPermissions ? "1" : "0", NULL);

		fprintf(stderr, "Failed to start darlingserver\n");
		exit(1);
	}

	// Wait for the child to drop UID/GIDs and unshare stuff
	close(pipefd[1]);
	read(pipefd[0], buffer, 1);
	close(pipefd[0]);

	/*
	snprintf(idmap, sizeof(idmap), "/proc/%d/uid_map", pid);

	file = fopen(idmap, "w");
	if (file != NULL)
	{
		fprintf(file, "0 %d 1\n", g_originalUid); // all users map to our user on the outside
		fclose(file);
	}
	else
	{
		fprintf(stderr, "Cannot set uid_map for the init process: %s\n", strerror(errno));
	}

	snprintf(idmap, sizeof(idmap), "/proc/%d/gid_map", pid);

	file = fopen(idmap, "w");
	if (file != NULL)
	{
		fprintf(file, "0 %d 1\n", g_originalGid); // all groups map to our group on the outside
		fclose(file);
	}
	else
	{
		fprintf(stderr, "Cannot set gid_map for the init process: %s\n", strerror(errno));
	}
	*/

	// Here's where we resume the child
	// if we enable user namespaces

	return pid;
}

void putInitPid(pid_t pidInit)
{
	const char pidFile[] = "/.init.pid";
	char* pidPath;
	FILE *fp;

	pidPath = (char*) alloca(strlen(prefix) + sizeof(pidFile));
	strcpy(pidPath, prefix);
	strcat(pidPath, pidFile);

	useOriginalIds();
	fp = fopen(pidPath, "w");
	restoreRootIds();

	if (fp == NULL)
	{
		fprintf(stderr, "Cannot write out PID of the init process: %s\n", strerror(errno));
		return;
	}
	fprintf(fp, "%d", (int) pidInit);
	fclose(fp);
}

char* defaultPrefixPath(void)
{
	const char defaultPath[] = "/.darling";
	const char* home = getenv("HOME");
	char* buf;

	if (!home)
	{
		fprintf(stderr, "Cannot detect your home directory!\n");
		return NULL;
	}

	buf = (char*) malloc(strlen(home) + sizeof(defaultPath));
	strcpy(buf, home);
	strcat(buf, defaultPath);

	return buf;
}

void createDir(const char* path)
{
	struct stat st;

	if (stat(path, &st) == 0)
	{
		if (!S_ISDIR(st.st_mode))
		{
			fprintf(stderr, "%s already exists and is a file. Remove the file.\n", path);
			exit(1);
		}
	}
	else
	{
		if (errno == ENOENT)
		{
			if (mkdir(path, 0755) != 0)
			{
				fprintf(stderr, "Cannot create %s: %s\n", path, strerror(errno));
				exit(1);
			}
		}
		else
		{
			fprintf(stderr, "Cannot access %s: %s\n", path, strerror(errno));
			exit(1);
		}
	}
}

void setupWorkdir()
{
	char* workdir;
	const char suffix[] = ".workdir";
	size_t len;

	len = strlen(prefix);
	workdir = (char*) alloca(len + sizeof(suffix));
	strcpy(workdir, prefix);

	// Remove trailing /
	while (workdir[len-1] == '/')
		len--;
	workdir[len] = '\0';

	strcat(workdir, suffix);

	// Create the workdir with the user's ids, like the user-owned prefix next to it.
	useOriginalIds();
	createDir(workdir);
	restoreRootIds();
}

int checkPrefixDir()
{
	struct stat st;

	// The prefix belongs to the user; stat it with their ids, as the other
	// prefix operations do.
	useOriginalIds();
	int r = stat(prefix, &st);
	int e = errno;
	restoreRootIds();

	if (r == 0)
	{
		if (!S_ISDIR(st.st_mode))
		{
			fprintf(stderr, "%s is a file. Remove the file.\n", prefix);
			exit(1);
		}
		enum darling_prefix_state state;
		useOriginalIds();
		state = darlingClassifyPrefix(prefix);
		int classifyError = errno;
		restoreRootIds();
		if (state == DARLING_PREFIX_STATE_INSPECTION_ERROR)
		{
			fprintf(stderr, "Cannot inspect prefix %s: %s.\n", prefix, strerror(classifyError));
			exit(1);
		}
		if (state == DARLING_PREFIX_STATE_UNINITIALIZED)
		{
			fprintf(stderr,
				"Prefix %s is non-empty but is not an initialized Darling prefix; refusing to overwrite it.\n"
				"Use an absent/empty directory for a new prefix, or point DPREFIX at an initialized prefix.\n",
				prefix);
			exit(1);
		}
		return state == DARLING_PREFIX_STATE_INITIALIZED;
	}
	if (e == ENOENT)
		return 0; // not found
	fprintf(stderr, "Cannot access %s: %s\n", prefix, strerror(e));
	exit(1);
}

void setupPrefix()
{
	char path[4096];
	size_t plen;
	FILE* file;
	struct passwd* passwd_entry;
	
	const char* dirs[] = {
		"/Volumes",
		"/Applications",
		"/usr",
		"/usr/local",
		"/usr/local/share",
		"/private",
		"/private/var",
		"/private/var/log",
		"/private/var/db",
		"/private/etc",
		"/var",
		"/var/run",
		"/var/tmp",
		"/var/log"
	};

	fprintf(stderr, "Setting up a new Darling prefix at %s\n", prefix);

	useOriginalIds();

	createDir(prefix);
	strcpy(path, prefix);
	strcat(path, "/");
	plen = strlen(path);

	for (size_t i = 0; i < sizeof(dirs)/sizeof(dirs[0]); i++)
	{
		path[plen] = '\0';
		strcat(path, dirs[i]);
		createDir(path);
	}

	if (g_nonroot)
		ensureProcSymlink(prefix);
	ensureHostRootSymlinks(prefix);
	ensureShSymlink(prefix);
	ensureHomebrewSymlinks(prefix);
	ensureKeychains(prefix);

	// create passwd, master.passwd, and group

	passwd_entry = getpwuid(g_originalUid);
	if (!passwd_entry) {
		fprintf(stderr, "Failed to find Linux /etc/passwd entry for current user\n");
		exit(1);
	}

	path[plen] = '\0';
	strcat(path, "/private/etc/passwd");
	file = fopen(path, "w");
	if (!file) {
		fprintf(stderr, "Failed to open /private/etc/passwd within the prefix\n");
		exit(1);
	}

	fprintf(file,
		"root:*:0:0:System Administrator:/var/root:/bin/sh\n"
		"%s:*:%d:%d:Darling User:/Users/%s:/bin/bash\n",
		passwd_entry->pw_name,
		passwd_entry->pw_uid,
		passwd_entry->pw_gid,
		passwd_entry->pw_name
	);
	fclose(file);

	path[plen] = '\0';
	strcat(path, "/private/etc/master.passwd");
	file = fopen(path, "w");
	if (!file) {
		fprintf(stderr, "Failed to open /private/etc/master.passwd within the prefix\n");
		exit(1);
	}

	fprintf(file,
		"root:*:0:0::0:0:System Administrator:/var/root:/bin/sh\n"
		"%s:*:%d:%d::0:0:Darling User:/Users/%s:/bin/bash\n",
		passwd_entry->pw_name,
		passwd_entry->pw_uid,
		passwd_entry->pw_gid,
		passwd_entry->pw_name
	);
	fclose(file);

	path[plen] = '\0';
	strcat(path, "/private/etc/group");
	file = fopen(path, "w");
	if (!file) {
		fprintf(stderr, "Failed to open /private/etc/group within the prefix\n");
		exit(1);
	}

	fprintf(file,
		"wheel:*:0:root,%s\n"
		"%s:*:%d:%s\n",
		passwd_entry->pw_name,
		passwd_entry->pw_name,
		passwd_entry->pw_gid,
		passwd_entry->pw_name
	);
	fclose(file);

	restoreRootIds();
}

pid_t getInitProcess()
{
	const char pidFile[] = "/.init.pid";
	char* pidPath;
	pid_t pid;
	int pid_i;
	FILE *fp;
	char procBuf[100];
	char *exeBuf, *statusBuf;
	int uidMatch = 0, gidMatch = 0;
	pid_t result = 0;

	pidPath = (char*) alloca(strlen(prefix) + sizeof(pidFile));
	strcpy(pidPath, prefix);
	strcat(pidPath, pidFile);

	// The pidfile lives inside the user's prefix, so open and unlink it with the
	// invoking user's ids, as the other prefix operations do. The /proc lookups
	// below read only world-readable procfs and run with the same ids, which is
	// enough to confirm the pid is a darlingserver owned by the user. Every exit
	// path restores root ids via the label.
	useOriginalIds();

	fp = fopen(pidPath, "r");
	if (fp == NULL)
		goto out;

	if (fscanf(fp, "%d", &pid_i) != 1)
	{
		fclose(fp);
		unlink(pidPath);
		goto out;
	}
	fclose(fp);
	pid = (pid_t) pid_i;

	// Does the process exist?
	if (kill(pid, 0) == -1)
	{
		unlink(pidPath);
		goto out;
	}

	// Is it actually an init process?
	snprintf(procBuf, sizeof(procBuf), "/proc/%d/comm", pid);
	fp = fopen(procBuf, "r");
	if (fp == NULL)
	{
		unlink(pidPath);
		goto out;
	}

	if (fscanf(fp, "%ms", &exeBuf) != 1)
	{
		fclose(fp);
		unlink(pidPath);
		goto out;
	}
	fclose(fp);

	if (strcmp(exeBuf, "darlingserver") != 0)
	{
		free(exeBuf);
		unlink(pidPath);
		goto out;
	}
	free(exeBuf);

	// Is it owned by the current user?
	if (g_originalUid != 0)
	{
		snprintf(procBuf, sizeof(procBuf), "/proc/%d/status", pid);
		fp = fopen(procBuf, "r");
		if (fp == NULL)
		{
			unlink(pidPath);
			goto out;
		}

		while (1)
		{
			statusBuf = NULL;
			size_t len;
			if (getline(&statusBuf, &len, fp) == -1)
			{
				free(statusBuf);
				break;
			}
			int rid, eid, sid, fid;
			if (sscanf(statusBuf, "Uid: %d %d %d %d", &rid, &eid, &sid, &fid) == 4)
			{
				uidMatch = (rid == g_originalUid && eid == g_originalUid && (sid == g_originalUid || sid == 0));
			}
			if (sscanf(statusBuf, "Gid: %d %d %d %d", &rid, &eid, &sid, &fid) == 4)
			{
				gidMatch = (rid == g_originalGid && eid == g_originalGid && (sid == g_originalGid || sid == 0));
			}
			free(statusBuf);
		}
		fclose(fp);

		if (!uidMatch || !gidMatch)
		{
			unlink(pidPath);
			goto out;
		}
	}

	result = pid;
out:
	restoreRootIds();
	return result;
}

void checkPrefixOwner()
{
	struct stat st;

	useOriginalIds();
	int statResult = stat(prefix, &st);
	int statErrno = errno;
	restoreRootIds();

	if (statResult == 0)
	{
		if (g_originalUid != 0 && st.st_uid != g_originalUid)
		{
			fprintf(stderr, "You do not own the prefix directory.\n");
			exit(1);
		}
	}
	else if (statErrno == EACCES)
	{
		fprintf(stderr, "You do not own the prefix directory.\n");
		exit(1);
	}
}
