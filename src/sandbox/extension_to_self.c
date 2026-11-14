#include <errno.h>
#include <stddef.h>
#include <stdint.h>

// Private; Photos imports it. GUESS (rung 6): no permitted source gives the prototype. The siblings the
// vendored WTF SandboxSPI.h declares (sandbox_extension_issue_file and its _to_process, _generic and _mach
// relatives) all return a malloc'ed token string, or NULL with errno set when none can be issued, so this one
// is taken to do the same for the file's path with the caller as the grantee. Darling has no sandbox
// extensions, so none is issued: NULL with ENOTSUP follows the honest-failure policy settled in #1545 (an
// invented token would be worse than a failure). No sibling extension function is implemented here. The
// function never reads its arguments, which stays correct for any argument list. The prototype is not in
// sandbox.h, which must not clash with WebKit's SPI header.
char *sandbox_extension_issue_file_to_self(void)
{
	errno = ENOTSUP;
	return NULL;
}
