# Launcher shutdown isolation

## Prefix initialization state

Run without root or any Darling container:

```sh
cc -Wall -Wextra -Werror -O2 tests/launcher/prefix-state.c -o /tmp/darling-prefix-state-test
/tmp/darling-prefix-state-test
```

An empty pre-created directory is treated like an absent prefix and follows
normal setup. A non-empty directory must contain the structural files created
by `setupPrefix()`; otherwise the launcher fails closed instead of overwriting
user data.

## Profile selection

Run without root or any Darling container:

```sh
cc -Wall -Wextra -Werror -O2 tests/launcher/profile-prefix.c -o /tmp/darling-profile-prefix-test
/tmp/darling-profile-prefix-test
```

This tests the launcher's pure prefix selector. `DPREFIX` remains the explicit
path interface. `DARLING_PROFILE=<name>` selects the isolated sibling prefix
`~/.darling.<name>`; using both selectors or a name containing path separators
is rejected. The harness does not create or access any prefix.

## Root-mode /proc

Run without root or any Darling container:

```sh
cc -Wall -Wextra -Werror -O2 tests/launcher/proc-dir.c -o /tmp/darling-proc-dir-test
/tmp/darling-proc-dir-test
```

Non-root mode makes the prefix's `/proc` a symlink to the host procfs, and root
mode must mount a procfs for launchd's PID namespace on a directory there. The
root-mode launcher replaces exactly that symlink with a directory; any other
entry, including a symlink with a different target, is left alone. The check
runs with the invoking user's ids.

## Shutdown isolation

Run without root or any Darling container:

```sh
cc -Wall -Wextra -Werror -O2 tests/launcher/shutdown-isolation.c -o /tmp/darling-shutdown-isolation-test
/tmp/darling-shutdown-isolation-test
```

This exercises the launcher's actual shutdown helpers on a private process tree.
The target children and grandchildren ignore SIGTERM, checking the SIGKILL phase
and preservation of process handles after reparenting. An unrelated process
named darlingserver and the test caller must survive. A different prefix must
fail the server identity check. The test reaps its children, including orphans.
Linux pidfd syscalls are required; unsupported kernels fail closed.

For container integration testing, use the fixed launcher with two disposable
prefixes. Boot both, shut down the first, check the second server PID remains
alive and serves another request, then shut down the second. Do not run the
historical launcher's shutdown path alongside any valuable running container.

Nonroot shellspawn has a separate process tree. The launcher records its host PID
at startup and validates its user and exact prefix socket environment before
obtaining a shutdown target. Existing nonroot containers started by an older
launcher lack this record and are refused rather than falling back to a global
process-name search. Start disposable nonroot tests with the fixed launcher.
