#!/usr/bin/env python3
"""
Host test: launchd reaps zombies it inherits without a job, and only those.
usage: python3 tests/launchd-reap-orphaned-zombies.py [REPO_ROOT]
In the guest PID namespace launchd is init, so Linux reparents every orphan to
it; XNU would have reaped those itself. The harness becomes a child subreaper
(the host stand-in for namespace init), cuts jobmgr_reap_orphaned_children()
and jobmgr_find_by_pid_deep() out of core.c with the real job and job manager
lists, and runs the reaper once against real processes:
  - an orphaned grandchild that exited: must be reaped;
  - a job in a nested job manager that exited: must stay a zombie so job_reap()
    still gets its status (c38f5c2: a root-only lookup reaped it);
  - an anonymous job that exited: must stay a zombie until job_reap() drops the
    job record, so the PID cannot be reused while the record names it;
  - a live untracked child: must be left alone.
proc_pidinfo(PROC_PIDT_SHORTBSDINFO) reads /proc/<pid>/stat like Darling's
emulation does. It also checks that jobmgr_init() arms the timer and that
jobmgr_callback() dispatches it to the reaper.
"""

import os
import re
import shlex
import subprocess
import sys
import tempfile

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(root, "src/launchd/src/core.c"), encoding="utf-8") as f:
    core = f.read()

if not os.path.isdir("/proc/self"):
    print("SKIP: /proc not available on this host")
    sys.exit(0)

def cut(pattern, what):
    m = re.search(pattern, core, re.M | re.S)
    if not m:
        print(f"FAIL: {what}")
        sys.exit(1)
    return m.group(1)

reaper = cut(r"^(void\njobmgr_reap_orphaned_children\(void\)\n\{.*?^\}\n)",
             "core.c has no reaper for zombies launchd inherits without a job; they stay zombies until shutdown")
deep = cut(r"^(job_t\njobmgr_find_by_pid_deep\(.*?^\}\n)", "jobmgr_find_by_pid_deep not found in core.c")
shallow = cut(r"^(job_t\njobmgr_find_by_pid\(.*?^\}\n)", "jobmgr_find_by_pid not found in core.c")
cut(r"^jobmgr_init\(bool sflag\)\n\{(?:(?!^\}).)*?(kevent_mod\(\(uintptr_t\)&stray_reap_timer, EVFILT_TIMER, EV_ADD,)",
    "jobmgr_init() does not arm the reaper timer")
cut(r"^jobmgr_callback\(void \*obj, struct kevent \*kev\)\n\{(?:(?!^\}).)*?(\(uintptr_t\)&stray_reap_timer\) \{\n\t+jobmgr_reap_orphaned_children\(\);)",
    "jobmgr_callback() does not dispatch the reaper timer")

probe = r"""#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/queue.h>
#include <sys/wait.h>
#include <unistd.h>

#define FAIL(...) do { printf("FAIL: " __VA_ARGS__); putchar('\n'); exit(1); } while (0)
#define ACTIVE_JOB_HASH_SIZE 32
#define ACTIVE_JOB_HASH(x) ((x) & (ACTIVE_JOB_HASH_SIZE - 1))
typedef struct job_s { LIST_ENTRY(job_s) pid_hash_sle; pid_t p; bool anonymous; } *job_t;
typedef struct jobmgr_s {
	SLIST_ENTRY(jobmgr_s) sle;
	SLIST_HEAD(, jobmgr_s) submgrs;
	LIST_HEAD(, job_s) active_jobs[ACTIVE_JOB_HASH_SIZE];
} *jobmgr_t;
static jobmgr_t root_jobmgr;
#define jobmgr_log(...) ((void) 0)

#define SZOMB 5
#define PROC_PIDT_SHORTBSDINFO 13
struct proc_bsdshortinfo { pid_t pbsi_pid; pid_t pbsi_ppid; unsigned pbsi_status; };
#define PROC_PIDT_SHORTBSDINFO_SIZE ((int) sizeof(struct proc_bsdshortinfo))
static int proc_pidinfo(pid_t pid, int flavor, unsigned long long arg, void *buf, int size) {
	char path[64], stat[512], *p, state;
	struct proc_bsdshortinfo *info = buf;
	FILE *f;
	size_t n;
	(void) arg;
	if (flavor != PROC_PIDT_SHORTBSDINFO || size != PROC_PIDT_SHORTBSDINFO_SIZE) FAIL("unexpected proc_pidinfo call");
	snprintf(path, sizeof(path), "/proc/%d/stat", pid);
	if (!(f = fopen(path, "r"))) return 0;
	n = fread(stat, 1, sizeof(stat) - 1, f);
	fclose(f);
	stat[n] = 0;
	if (!(p = strrchr(stat, ')')) || sscanf(p + 1, " %c %d", &state, &info->pbsi_ppid) != 2) return 0;
	info->pbsi_pid = pid;
	info->pbsi_status = state == 'Z' ? SZOMB : 0;
	return size;
}

static job_t job_new_anonymous(jobmgr_t jm, pid_t p) { (void) jm; FAIL("the orphan scan created an anonymous job for PID %d", p); }
static job_t jobmgr_find_by_pid_deep(jobmgr_t jm, pid_t p, bool anon_okay);
static job_t jobmgr_find_by_pid(jobmgr_t jm, pid_t p, bool create_anon);
static void jobmgr_reap_orphaned_children(void);
""" + deep + shallow + reaper + r"""
static void wait_zombie(pid_t pid) {
	for (int i = 0; i < 500; i++) {
		struct proc_bsdshortinfo info;
		if (proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 1, &info, PROC_PIDT_SHORTBSDINFO_SIZE) && info.pbsi_status == SZOMB
			&& info.pbsi_ppid == getpid())
			return;
		usleep(10000);
	}
	FAIL("PID %d did not become our zombie child", pid);
}
static pid_t exiting_child(void) {
	pid_t pid = fork();
	if (pid == 0) _exit(7);
	wait_zombie(pid);
	return pid;
}
static void add_job(jobmgr_t jm, job_t j, pid_t pid, bool anonymous) {
	j->p = pid;
	j->anonymous = anonymous;
	LIST_INSERT_HEAD(&jm->active_jobs[ACTIVE_JOB_HASH(pid)], j, pid_hash_sle);
}

int main(void) {
	static struct jobmgr_s rootm, session;
	static struct job_s nested_job, anon_job;
	int fds[2], gate[2], status;
	pid_t mid, orphan, nested, anon, live;

	if (prctl(PR_SET_CHILD_SUBREAPER, 1) != 0) { printf("SKIP: no PR_SET_CHILD_SUBREAPER\n"); return 0; }
	SLIST_INSERT_HEAD(&rootm.submgrs, &session, sle);
	root_jobmgr = &rootm;

	/* fds: the middle process reports the grandchild's PID; gate: the
	 * grandchild exits only once its parent is gone, so it is reparented. */
	if (pipe(fds) != 0 || pipe(gate) != 0) FAIL("pipe");
	mid = fork();
	if (mid == 0) {
		pid_t g = fork();
		if (g == 0) { char c; close(gate[1]); read(gate[0], &c, 1); _exit(3); }
		write(fds[1], &g, sizeof(g));
		_exit(0);
	}
	close(gate[0]);
	if (read(fds[0], &orphan, sizeof(orphan)) != sizeof(orphan)) FAIL("orphan pid");
	if (waitpid(mid, &status, 0) != mid) FAIL("waitpid parent of orphan");
	close(gate[1]);
	close(fds[1]);
	close(fds[0]);
	wait_zombie(orphan);

	nested = exiting_child();
	add_job(&session, &nested_job, nested, false);
	anon = exiting_child();
	add_job(&rootm, &anon_job, anon, true);
	live = fork();
	if (live == 0) { pause(); _exit(0); }

	jobmgr_reap_orphaned_children();

	pid_t live_wait = waitpid(live, &status, WNOHANG);
	kill(live, SIGKILL);
	waitpid(live, &status, 0);
	if (live_wait != 0)
		FAIL("live untracked child was touched");
	if (kill(orphan, 0) == 0 || errno != ESRCH)
		FAIL("orphaned zombie PID %d was not reaped", orphan);
	if (waitpid(nested, &status, WNOHANG) != nested || !WIFEXITED(status) || WEXITSTATUS(status) != 7)
		FAIL("job in a nested job manager was reaped by the orphan scan; job_reap() loses its exit status");
	if (waitpid(anon, &status, WNOHANG) != anon || WEXITSTATUS(status) != 7)
		FAIL("anonymous job was reaped by the orphan scan while its job record still holds the PID");

	root_jobmgr = NULL;
	jobmgr_reap_orphaned_children();
	printf("PASS: launchd reaps orphaned zombies and leaves tracked jobs and live children alone\n");
	return 0;
}
"""

cc = shlex.split(os.environ.get("CC", "cc"))
with tempfile.TemporaryDirectory() as tmp:
    src = os.path.join(tmp, "probe.c")
    exe = os.path.join(tmp, "probe")
    with open(src, "w", encoding="utf-8") as f:
        f.write(probe)
    build = subprocess.run(cc + ["-std=gnu11", "-Wall", "-Wno-unused-result", "-Wno-unused-function", "-o", exe, src],
                           capture_output=True, text=True)
    if build.returncode != 0:
        sys.stderr.write(build.stdout + build.stderr)
        sys.exit("launchd orphan reaping: probe did not build")
    run = subprocess.run([exe], capture_output=True, text=True, timeout=60)
    sys.stdout.write(run.stdout)
    sys.stderr.write(run.stderr)
    sys.exit(run.returncode)
