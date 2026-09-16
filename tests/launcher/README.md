# Launcher shutdown isolation

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
