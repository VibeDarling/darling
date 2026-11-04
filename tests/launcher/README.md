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
path interface and must be absolute; an empty or relative value is rejected. `DARLING_PROFILE=<name>` selects the isolated sibling prefix
`~/.darling.<name>`; using both selectors or a name containing path separators
is rejected. The harness does not create or access any prefix.

## Shellspawn socket path

Run without root or any Darling container:

```sh
sh tests/launcher/shellspawn-sockpath.sh /tmp/darling-shellspawn-sockpath-test
```

Extracts the path construction of `connectToShellspawn()` from `darling.c` and
checks that a prefix too long for `sun_path` is refused with an error instead of
overflowing it. The launcher accepts a `DPREFIX` of up to 255 bytes; `sun_path`
holds 107.

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

## Orphans of a dead server

Run without root or any Darling container:

```sh
cc -Wall -Wextra -Werror -O2 tests/launcher/orphan-cleanup.c -o /tmp/darling-orphan-cleanup-test
/tmp/darling-orphan-cleanup-test
```

Nonroot containers have no PID namespace, so when darlingserver dies its guests are
reparented to init and no longer descend from any server. `shutdownOrphans()` finds
them by exact prefix socket environment, the invoking user and an `mldr` executable
path (a replaced binary's ` (deleted)` suffix is ignored). The test copies itself to
two `mldr` paths and checks that a live server for the prefix blocks reaping; that
after it dies the prefix's guests, including a grandchild, a SIGTERM-resistant child
and one running a since-replaced binary, are stopped; and that a non-`mldr` process,
another prefix's guest and a process without the socket environment survive. The
prefix is the run's own temporary directory.

## Inspection failure on /proc/<pid>/cmdline

Run without root or any Darling container:

```sh
cc -Wall -Wextra -Werror -O2 -Wl,--wrap=open tests/launcher/proc-permission.c -o /tmp/darling-proc-permission-test
/tmp/darling-proc-permission-test
```

Under `/proc` mounted with `hidepid=1` or `hidepid=2`, inspecting another process's
`cmdline` requires `PTRACE_MODE_READ_FSCREDS`, which fails with `EACCES` or `EPERM`
when GIDs differ (for example, after `newgrp`). `shutdownServerMatches()` separates
inspection failure (-1) from mismatch (0), so `shutdownOrphans()` and `darling shutdown`
fail closed instead of treating an unreadable server as absent and killing guests
or spawning a duplicate server.

For container integration testing, use the fixed launcher with two disposable
prefixes. Boot both, shut down the first, check the second server PID remains
alive and serves another request, then shut down the second. Do not run the
historical launcher's shutdown path alongside any valuable running container.

Nonroot shellspawn has a separate process tree. The launcher records its host PID
at startup and validates its user and exact prefix socket environment before
obtaining a shutdown target. Existing nonroot containers started by an older
launcher lack this record and are refused rather than falling back to a global
process-name search. Start disposable nonroot tests with the fixed launcher.
