// Simulation of the launcher's id switching. See privilege-drop.sh for how the code under test is
// extracted from src/startup/darling.c. A real setuid exec is not exercised.
#define _GNU_SOURCE
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/auxv.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef USER_UID
#define USER_UID 1000
#endif
#ifndef USER_GID
#define USER_GID 1000
#endif

static uid_t ru, eu, su;
static gid_t rg, eg, sg;
static int ngroups;
static bool at_secure;
static const char* env_nonroot;
static bool fail_setuid, fail_setgid, fail_setresuid, fail_setresgid, fail_setgroups;

static bool priv(void) { return eu == 0; }

static int sim_setuid(uid_t u)
{
	if (fail_setuid) { errno = EAGAIN; return -1; }
	if (priv()) { ru = eu = su = u; return 0; }
	if (u == ru || u == su) { eu = u; return 0; }
	errno = EPERM; return -1;
}
static int sim_setgid(gid_t g)
{
	if (fail_setgid) { errno = EAGAIN; return -1; }
	if (priv()) { rg = eg = sg = g; return 0; }
	if (g == rg || g == sg) { eg = g; return 0; }
	errno = EPERM; return -1;
}
static int sim_seteuid(uid_t u)
{
	if (priv() || u == ru || u == eu || u == su) { eu = u; return 0; }
	errno = EPERM; return -1;
}
static int sim_setegid(gid_t g)
{
	if (priv() || g == rg || g == eg || g == sg) { eg = g; return 0; }
	errno = EPERM; return -1;
}
static int sim_setresuid(uid_t r, uid_t e, uid_t s)
{
	if (fail_setresuid) { errno = EAGAIN; return -1; }
	if (!priv()) {
		uid_t ok[3] = { ru, eu, su };
		uid_t want[3] = { r, e, s };
		for (int i = 0; i < 3; i++) {
			bool found = false;
			for (int k = 0; k < 3; k++) found |= want[i] == ok[k];
			if (!found) { errno = EPERM; return -1; }
		}
	}
	ru = r; eu = e; su = s; return 0;
}
static int sim_setresgid(gid_t r, gid_t e, gid_t s)
{
	if (fail_setresgid) { errno = EAGAIN; return -1; }
	if (!priv()) {
		gid_t ok[3] = { rg, eg, sg };
		gid_t want[3] = { r, e, s };
		for (int i = 0; i < 3; i++) {
			bool found = false;
			for (int k = 0; k < 3; k++) found |= want[i] == ok[k];
			if (!found) { errno = EPERM; return -1; }
		}
	}
	rg = r; eg = e; sg = s; return 0;
}
static int sim_setgroups(size_t n, const gid_t* g)
{
	(void) g;
	if (fail_setgroups) { errno = EAGAIN; return -1; }
	if (!priv()) { errno = EPERM; return -1; }
	ngroups = (int) n; return 0;
}
static int sim_getresuid(uid_t* r, uid_t* e, uid_t* s) { *r = ru; *e = eu; *s = su; return 0; }
static int sim_getresgid(gid_t* r, gid_t* e, gid_t* s) { *r = rg; *e = eg; *s = sg; return 0; }
static uid_t sim_geteuid(void) { return eu; }
static uid_t sim_getuid(void) { return ru; }
static gid_t sim_getgid(void) { return rg; }
static gid_t sim_getegid(void) { return eg; }
static unsigned long sim_getauxval(unsigned long t) { return t == AT_SECURE ? at_secure : 0; }
static char* sim_getenv(const char* n) { return strcmp(n, "DARLING_NONROOT") == 0 ? (char*) env_nonroot : NULL; }

#define setuid sim_setuid
#define setgid sim_setgid
#define seteuid sim_seteuid
#define setegid sim_setegid
#define setresuid sim_setresuid
#define setresgid sim_setresgid
#define setgroups sim_setgroups
#define getresuid sim_getresuid
#define getresgid sim_getresgid
#define geteuid sim_geteuid
#define getuid sim_getuid
#define getgid sim_getgid
#define getegid sim_getegid
#define getauxval sim_getauxval
#define getenv sim_getenv

uid_t g_originalUid = USER_UID;
gid_t g_originalGid = USER_GID;
bool g_rootless, g_nonroot;

#include "funcs.inc"

static int startup(void)
{
#include "startup.inc"
	return 0;
}

static int afterJoin(void)
{
#include "afterjoin.inc"
	return 0;
}

static int failures;
#define CHECK(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); failures++; } } while (0)

// A setuid-root launcher run by USER_UID: real ids are the user's, effective and saved are root.
static void reset(void)
{
	ru = USER_UID; eu = 0; su = 0;
	rg = USER_GID; eg = 0; sg = 0;
	ngroups = 5;
	at_secure = true;
	env_nonroot = NULL;
	fail_setuid = fail_setgid = fail_setresuid = fail_setresgid = fail_setgroups = false;
	g_nonroot = g_rootless = false;
}

int main(void)
{
	// 1. A caller-set DARLING_NONROOT must not select the non-root branch of a setuid launcher.
	reset();
	env_nonroot = "1";
	CHECK(startup() == 0, "startup with ids intact");
	CHECK(!g_nonroot, "DARLING_NONROOT honoured under AT_SECURE");

	// 2. Without AT_SECURE (a plain unprivileged run) the variable still selects non-root mode.
	reset();
	at_secure = false;
	ru = eu = su = USER_UID;
	rg = eg = sg = USER_GID;
	env_nonroot = "1";
	CHECK(startup() == 0 && g_nonroot, "DARLING_NONROOT not honoured without AT_SECURE");

	// 3. A failing setuid(0) or setgid(0) in root mode must stop startup.
	reset();
	fail_setuid = true;
	CHECK(startup() != 0, "setuid(0) failure ignored");
	reset();
	fail_setgid = true;
	CHECK(startup() != 0, "setgid(0) failure ignored");

	// 4. After the namespace join, root mode drops every real, effective and saved id.
	reset();
	CHECK(startup() == 0 && !g_nonroot, "startup in root mode");
	CHECK(afterJoin() == 0, "drop after join");
	CHECK(ru == USER_UID && eu == USER_UID && su == USER_UID, "uid not fully dropped");
	CHECK(rg == USER_GID && eg == USER_GID && sg == USER_GID, "gid not fully dropped");
	CHECK(sim_seteuid(0) != 0, "root regainable after the drop");
	CHECK(sim_setresuid(0, 0, 0) != 0, "root regainable through setresuid");

	// 5. A failing drop step must stop the client instead of continuing with root still saved.
	reset();
	startup();
	fail_setresuid = true;
	CHECK(afterJoin() != 0, "setresuid failure ignored after join");
	reset();
	startup();
	fail_setgroups = true;
	CHECK(afterJoin() != 0, "setgroups failure ignored after join");

	// 6. Non-root mode (already dropped) stays untouched by the post-join block.
	reset();
	ru = eu = su = USER_UID;
	rg = eg = sg = USER_GID;
	g_nonroot = true;
	CHECK(afterJoin() == 0 && eu == USER_UID, "non-root post-join block changed ids");

	if (failures) {
		printf("%d check(s) failed\n", failures);
		return 1;
	}
	puts("privilege-drop: all checks passed");
	return 0;
}
