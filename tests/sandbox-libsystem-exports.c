#include <dlfcn.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// Guest test: libSystem (through libsystem_sandbox) exports the three functions that Disk Utility and System
// Settings import, with the Darling behaviour documented in the commits that added them.
int main(void) {
    char *(*issue)(const char *, const char *, uint32_t) = dlsym(RTLD_DEFAULT, "sandbox_extension_issue_file");
    int (*protected_volume)(const char *) = dlsym(RTLD_DEFAULT, "rootless_protected_volume");
    pid_t (*responsible)(pid_t) = dlsym(RTLD_DEFAULT, "responsibility_get_pid_responsible_for_pid");
    EXPECT(issue && protected_volume && responsible, "all three symbols are exported");
    errno = 0;
    EXPECT(issue("com.apple.app-sandbox.read", "/tmp", 0) == NULL && errno == ENOTSUP, "no extension token is issued");

    EXPECT(responsible(getpid()) == getpid(), "a process is responsible for itself");
    printf("PASS: libsystem sandbox exports\n");
    return 0;
}
