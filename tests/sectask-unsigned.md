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
directories, and run
`darling shell /opt/ftservices-probes/sectask-unsigned`. Capture the exit code
and all fixture output. Stop only that prefix with `darling shutdown`.

This is a public API probe; it establishes no FTEntitlementSupport mapping,
private method ABI, signed-process semantics or cross-process authorization.

## Verified result

The unsigned ARM64 fixture built and ran against private snapshot
`runtime-display-link-e68d60cb`: Darling
`6b11337e0b6aaaf0eefa02d5cdedef0da51404c4`, Security
`d3165e9744fd566433ce5a09912eab2d388b62f2`. Guest execution exited 0 and
reported task creation, NULL without error for the invented entitlement,
and a NULL return with the optional error output omitted. The executable
was linked with `-no_adhoc_codesign`; its own Mach-O load-command metadata
also confirmed no code-signature command.

No retrieval failure occurred in this run. The error-reporting branch is
an observation path, not a demonstrated backend-failure test. No Security
implementation change is justified by these results.

The prefix maps guest `/tmp` to the host through virtual filesystem links.
Stage under its physical `opt/ftservices-probes` directory instead of
following guest `/tmp` symlinks from the host.
