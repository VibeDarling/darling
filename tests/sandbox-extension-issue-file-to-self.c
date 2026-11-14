#include <dlfcn.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// Guest test: libSystem (through libsystem_sandbox) exports sandbox_extension_issue_file_to_self, which Photos
// imports. It issues no token on Darling (no sandbox extensions exist): NULL with errno ENOTSUP, never a
// token that a caller would free() or consume. The prototype is GUESS (siblings in WebKit's SandboxSPI.h).
int main(void) {
    char *(*issue)(const char *, const char *, uint32_t) = dlsym(RTLD_DEFAULT, "sandbox_extension_issue_file_to_self");
    EXPECT(issue != NULL, "sandbox_extension_issue_file_to_self is exported");
    errno = 0;
    EXPECT(issue("com.apple.app-sandbox.read", "/tmp", 0) == NULL && errno == ENOTSUP, "no extension token is issued");
    errno = 0;
    EXPECT(issue(NULL, NULL, 0) == NULL && errno == ENOTSUP, "NULL arguments are not read");
    printf("PASS: sandbox_extension_issue_file_to_self\n");
    return 0;
}
