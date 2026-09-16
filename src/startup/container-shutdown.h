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

static bool shutdownServerMatches(pid_t pid, const char *expectedPrefix)
{
 char path[64], buf[8192];
 snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);
 int fd = open(path, O_RDONLY | O_CLOEXEC);
 if (fd < 0) return false;
 ssize_t n = read(fd, buf, sizeof(buf)); close(fd);
 if (n <= 0) return false;
 size_t first = strnlen(buf, n);
 if (first >= (size_t)n || strcmp(buf, "darlingserver")) return false;
 size_t remain = n - first - 1;
 const char *arg = buf + first + 1;
 return strnlen(arg, remain) < remain && !strcmp(arg, expectedPrefix);
}

static int shutdownHandle(pid_t pid)
{
 return syscall(SYS_pidfd_open, pid, 0);
}

/* Called with a pinned, prefix-validated server. Snapshot handles before TERM so
 * descendants that become orphaned are still covered by the subsequent KILL.
 * Root containers also include reparented tasks in their private PID namespace.
 * Nonroot containers use ancestry only, never the shared host namespace. */
static bool shutdownContainer(pid_t server, int serverHandle, pid_t shellspawn, int shellHandle)
{
 char serverNs[128], containerNs[128] = "";
 if (!shutdownNamespace(server, serverNs, sizeof(serverNs))) return false;
 DIR *dir = opendir("/proc");
 if (!dir) return false;
 struct dirent *entry;
 while ((entry = readdir(dir))) {
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
