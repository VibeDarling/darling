/* Linux process handles for prefix-scoped shutdown. No process-name fallback. */
#ifndef DARLING_CONTAINER_SHUTDOWN_H
#define DARLING_CONTAINER_SHUTDOWN_H
#include <sys/syscall.h>

static pid_t shutdownParent(pid_t pid)
{
 char path[64], buf[1024], state; int parent;
 snprintf(path, sizeof(path), "/proc/%d/stat", pid);
 FILE *f = fopen(path, "r");
 if (!f) return 0;
 char *line = fgets(buf, sizeof(buf), f); fclose(f);
 char *end = line ? strrchr(buf, ')') : NULL;
 return end && sscanf(end + 1, " %c %d", &state, &parent) == 2 ? parent : 0;
}

static bool shutdownDescendant(pid_t pid, pid_t server)
{
 /* Bound traversal even if procfs changes while inspecting the ancestry. */
 for (unsigned depth = 0; pid > 1 && depth < 4096; ++depth) {
  pid_t parent = shutdownParent(pid);
  if (parent == server) return true;
  if (parent <= 0 || parent == pid) break;
  pid = parent;
 }
 return false;
}

static bool shutdownNamespace(pid_t pid, char *buf, size_t size)
{
 char path[64];
 snprintf(path, sizeof(path), "/proc/%d/ns/pid", pid);
 ssize_t n = readlink(path, buf, size - 1);
 if (n <= 0) return false;
 buf[n] = 0; return true;
}

/* Returns 1 if `pid` is a darlingserver for `expectedPrefix`; 0 if not (different binary,
 * different prefix, or process already dead); -1 on inspection failure (errno preserved). */
static int shutdownServerMatches(pid_t pid, const char *expectedPrefix)
{
 char path[64], buf[8192];
 snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);
 int fd = open(path, O_RDONLY | O_CLOEXEC);
 if (fd < 0) {
  if (errno == ENOENT || errno == ESRCH) return 0;
  return -1;
 }
 ssize_t n = read(fd, buf, sizeof(buf)); int err = errno; close(fd);
 if (n < 0) {
  if (err == ENOENT || err == ESRCH) return 0;
  errno = err;
  return -1;
 }
 if (n == 0) return 0;
 size_t first = strnlen(buf, n);
 if (first >= (size_t)n || strcmp(buf, "darlingserver")) return 0;
 size_t remain = n - first - 1;
 const char *arg = buf + first + 1;
 return (strnlen(arg, remain) < remain && !strcmp(arg, expectedPrefix)) ? 1 : 0;
}

static int shutdownHandle(pid_t pid)
{
 return syscall(SYS_pidfd_open, pid, 0);
}

/* True if the process's initial environment contains exactly `entry`. */
static bool shutdownEnvHas(pid_t pid, const char *entry)
{
 char path[64];
 snprintf(path, sizeof(path), "/proc/%d/environ", pid);
 FILE *f = fopen(path, "re");
 if (!f) return false;
 char *item = NULL; size_t cap = 0; bool found = false;
 while (!found && getdelim(&item, &cap, '\0', f) > 0) found = !strcmp(item, entry);
 free(item); fclose(f); return found;
}

static bool shutdownOwnedBy(pid_t pid, uid_t uid)
{
 char path[64], line[256]; unsigned real, effective; bool owned = false;
 snprintf(path, sizeof(path), "/proc/%d/status", pid);
 FILE *f = fopen(path, "re");
 if (!f) return false;
 while (fgets(line, sizeof(line), f))
  if (sscanf(line, "Uid: %u %u", &real, &effective) == 2) { owned = real == uid && effective == uid; break; }
 fclose(f); return owned;
}

/* Compared by path, not inode, so guests of a since-reinstalled mldr still match. */
static bool shutdownExeIs(pid_t pid, const char *const mldr[2])
{
 static const char deleted[] = " (deleted)";
 char path[64], exe[4096];
 snprintf(path, sizeof(path), "/proc/%d/exe", pid);
 ssize_t n = readlink(path, exe, sizeof(exe) - 1);
 if (n <= 0) return false;
 exe[n] = 0;
 size_t d = sizeof(deleted) - 1;
 if ((size_t)n > d && !strcmp(exe + n - d, deleted)) exe[n - d] = 0;
 return !strcmp(exe, mldr[0]) || !strcmp(exe, mldr[1]);
}

/* Stops what a dead darlingserver left behind: processes of `uid` running one of the `mldr`
 * binaries with this prefix's exact socket environment. Candidates are pinned before looking for a
 * live server, so a container that starts concurrently is left alone. Returns the number stopped;
 * 0 with *liveServer set when a server still serves the prefix; -1 on error (reason printed). */
static inline int shutdownOrphans(const char *prefix, uid_t uid, const char *const mldr[2], pid_t *liveServer)
{
 char entry[4096];
 int len = snprintf(entry, sizeof(entry), "__mldr_sockpath=%s/.darlingserver.sock", prefix);
 *liveServer = 0;
 if (len < 0 || (size_t)len >= sizeof(entry)) { fprintf(stderr, "Prefix path too long: %s\n", prefix); return -1; }
 DIR *dir = opendir("/proc");
 if (!dir) { perror("opendir /proc"); return -1; }
 struct pollfd *handles = NULL; pid_t *pids = NULL; size_t count = 0; int result = 0;
 struct dirent *e;
 while ((e = readdir(dir))) {
  pid_t pid = atoi(e->d_name);
  if (pid <= 1 || pid == getpid()) continue;
  int fd = shutdownHandle(pid);
  if (fd < 0) continue;
  if (!shutdownOwnedBy(pid, uid) || !shutdownExeIs(pid, mldr) || !shutdownEnvHas(pid, entry)) { close(fd); continue; }
  struct pollfd *h = realloc(handles, (count + 1) * sizeof(*handles));
  if (h) handles = h;
  pid_t *p = h ? realloc(pids, (count + 1) * sizeof(*pids)) : NULL;
  if (p) pids = p;
  if (!h || !p) { perror("realloc"); close(fd); result = -1; break; }
  handles[count] = (struct pollfd){ .fd = fd, .events = POLLIN }; pids[count++] = pid;
 }
 if (result == 0) {
  rewinddir(dir);
  while ((e = readdir(dir))) {
   pid_t pid = atoi(e->d_name);
   if (pid <= 1 || pid == getpid()) continue;
   if (!shutdownOwnedBy(pid, uid)) continue;
   int match = shutdownServerMatches(pid, prefix);
   if (match < 0) {
    fprintf(stderr, "Cannot inspect process %d: %s\n", pid, strerror(errno));
    result = -1;
    break;
   }
   if (match > 0) { *liveServer = pid; break; }
  }
 }
 closedir(dir);
 if (result == 0 && !*liveServer) {
  /* SIGKILL only: guest SIGTERM handlers need the dead server and would abort. */
  for (size_t i = 0; i < count; ++i)
   if (syscall(SYS_pidfd_send_signal, handles[i].fd, SIGKILL, NULL, 0) < 0 && errno != ESRCH) {
    fprintf(stderr, "Cannot stop process %d left by a dead darlingserver: %s\n", pids[i], strerror(errno));
    close(handles[i].fd); handles[i].fd = -1; result = -1;
   }
  for (size_t i = 0; i < count; ++i)
   if (handles[i].fd >= 0 && poll(&handles[i], 1, 1000) <= 0) {
    fprintf(stderr, "Process %d left by a dead darlingserver did not exit.\n", pids[i]);
    result = -1;
   }
  if (result == 0) result = (int)count;
 }
 for (size_t i = 0; i < count; ++i) if (handles[i].fd >= 0) close(handles[i].fd);
 free(handles); free(pids); return result;
}

/* Called with a pinned, prefix-validated server. Snapshot handles before TERM so
 * descendants that become orphaned are still covered by the subsequent KILL.
 * Root containers also include reparented tasks in their private PID namespace.
 * Nonroot containers use ancestry only, never the shared host namespace. */
static inline bool shutdownContainer(pid_t server, int serverHandle, pid_t shellspawn, int shellHandle)
{
 char serverNs[128], containerNs[128] = "";
 /* Android's SELinux policy hides /proc/<pid>/ns from apps: without it, ancestry alone decides,
  * as it does for every nonroot container. */
 bool namespaces = shutdownNamespace(server, serverNs, sizeof(serverNs));
 DIR *dir = opendir("/proc");
 if (!dir) return false;
 struct dirent *entry;
 while (namespaces && (entry = readdir(dir))) {
  pid_t pid = atoi(entry->d_name); char ns[128];
  if (pid > 1 && shutdownParent(pid) == server &&
      shutdownNamespace(pid, ns, sizeof(ns)) && strcmp(ns, serverNs)) {
   strcpy(containerNs, ns); break;
  }
 }
 struct pollfd *handles = NULL; size_t count = 0;
 if (shellHandle >= 0) {
  handles = malloc(sizeof(*handles));
  if (!handles) { closedir(dir); return false; }
  int copy = dup(shellHandle);
  if (copy < 0) { free(handles); closedir(dir); return false; }
  handles[count++] = (struct pollfd){ .fd = copy, .events = POLLIN };
 }
 bool ok = true;
 rewinddir(dir);
 while ((entry = readdir(dir))) {
  pid_t pid = atoi(entry->d_name); char ns[128];
  if (pid <= 1 || pid == server || pid == shellspawn || pid == getpid()) continue;
  bool member = containerNs[0] && shutdownNamespace(pid, ns, sizeof(ns)) && !strcmp(ns, containerNs);
  if (!member && !shutdownDescendant(pid, server) &&
      !(shellspawn > 1 && syscall(SYS_pidfd_send_signal, shellHandle, 0, NULL, 0) == 0 && shutdownDescendant(pid, shellspawn))) continue;
  int fd = shutdownHandle(pid);
  if (fd < 0) { if (errno != ESRCH) ok = false; continue; }
  /* Recheck membership after pinning, before retaining a signal target. */
  member = containerNs[0] && shutdownNamespace(pid, ns, sizeof(ns)) && !strcmp(ns, containerNs);
  if (!member && !shutdownDescendant(pid, server) &&
      !(shellspawn > 1 && syscall(SYS_pidfd_send_signal, shellHandle, 0, NULL, 0) == 0 && shutdownDescendant(pid, shellspawn))) { close(fd); continue; }
  struct pollfd *next = realloc(handles, (count + 1) * sizeof(*handles));
  if (!next) { close(fd); ok = false; break; }
  handles = next; handles[count++] = (struct pollfd){ .fd = fd, .events = POLLIN };
 }
 closedir(dir);
 if (!ok) goto done; /* Fail closed: never broaden cleanup on inspection errors. */
 for (size_t i = 0; i < count; ++i)
  if (syscall(SYS_pidfd_send_signal, handles[i].fd, SIGTERM, NULL, 0) < 0 && errno != ESRCH) ok = false;
 for (int attempt = 0; attempt < 20; ++attempt) {
  size_t alive = 0;
  for (size_t i = 0; i < count; ++i) {
   poll(&handles[i], 1, 0);
   if (!(handles[i].revents & POLLIN)) ++alive;
  }
  if (!alive) break;
  usleep(50000);
 }
 for (size_t i = 0; i < count; ++i)
  if (syscall(SYS_pidfd_send_signal, handles[i].fd, SIGKILL, NULL, 0) < 0 && errno != ESRCH) ok = false;
 syscall(SYS_pidfd_send_signal, serverHandle, SIGTERM, NULL, 0);
 struct pollfd serverPoll = { .fd = serverHandle, .events = POLLIN };
 if (poll(&serverPoll, 1, 1000) == 0)
  syscall(SYS_pidfd_send_signal, serverHandle, SIGKILL, NULL, 0);
 if (poll(&serverPoll, 1, 1000) <= 0) ok = false;
 for (size_t i = 0; i < count; ++i)
  if (poll(&handles[i], 1, 1000) <= 0) ok = false;
 done:
 for (size_t i = 0; i < count; ++i) close(handles[i].fd);
 free(handles); return ok;
}
#endif
