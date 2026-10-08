# Unsigned SecTask self/absent-entitlement probe

This authored fixture queries only its own unsigned process and an invented
entitlement. It does not use accounts, credentials, keychains or registration.

Contract provenance: Apple published Security `sectask/SecTask.h` and
`sectask/SecTask.c` (clean-room rung 1), and Darling's vendored `SecTask.h`
(rung 2). The header distinguishes an absent entitlement (NULL without error)
from retrieval failure (NULL with optional error). This test preserves that
distinction: exit 0 is successful absence, 1 is an unexpected value or diagnostic
failure, and 77 reports unavailable task creation or entitlement retrieval.
A retrieval error is not proof of a missing entitlement. The NULL-error-output
query also runs after retrieval failure if task creation succeeded.

Published sources:
- https://github.com/apple-oss-distributions/Security/blob/main/sectask/SecTask.h
- https://github.com/apple-oss-distributions/Security/blob/main/sectask/SecTask.c

Compile using Darling Darwin headers with blocks enabled, link against Security,
CoreFoundation and libSystem, and pass `-no_adhoc_codesign` to ld64.lld to keep the
fixture unsigned. Hold `/tmp/agent-locks/darling-heavy-build.lock` for every
compile/link and use at most two jobs. Use `-syslibroot` pointing at the private
runtime's guest root so libSystem reexports resolve.

Commit the fixture before staging its executable. Bootstrap a new private prefix
with `darling shell true`, replace only its generated home symlinks with empty
directories, and run `darling shell /tmp/sectask-unsigned`. Capture the exit code
and all fixture output. Stop only that prefix with `darling shutdown`.

This is a public API probe; it establishes no FTEntitlementSupport mapping,
private method ABI, signed-process semantics or cross-process authorization.
