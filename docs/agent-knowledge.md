# Agent knowledge base

Measured facts, recipes, and pitfalls that cost real time to rediscover. Each item was measured once
on one host; items marked (unverified) were not re-checked against this tree. Keep it free of status that goes stale: defects belong in
[`../known-issues.md`](../known-issues.md), and per-app progress belongs in each agent's own
scratch `STATUS.md`.

## Reading this codebase

- **Method declarations often have no parentheses around the return type.** Both
  `- (void) foo` and `- foo` occur, sometimes in the same file. A grep for `^- *\([^)]*\)foo`
  therefore misses real implementations and will make you conclude a method does not exist when it
  does. Match `^- .*foo` instead. This has produced two wrong diagnoses in one sitting.
- **`NSUnimplementedMethod()` logs; it does not abort.** It expands to `NSLog(@"-[%@ %s]
  unimplemented in %s at %d", ...)`. So "no `unimplemented in` line" means the stub was not hit - it
  does not mean anything crashed. `NSUnimplementedFunction()` behaves the same way.
- **`NS_DURING`/`NS_HANDLER` are real `@try`/`@catch`**, not `setjmp`. If an `NSException` escapes
  code wrapped in them, the handler runs; look for whatever the handler does (often
  `[self reportException:]`, which may only log).
- **Silence is not evidence.** `kern_printf` logs at `info` while `darlingserver` defaults to
  `Error`; raise the level before concluding a line is absent. `DSERVER_LOG_LEVEL` is read from the
  environment of the launching process.

## Tools that mislead here

- **Which binaries these tools may touch** (`AGENTS.md` section 1, "Binaries you may point tools
  at"): `nm`, `objdump`, `strings` and debuggers on our own build output only. On guest app
  binaries, only `nm` and `otool -L`, for demand analysis (ladder rung 5). Nothing on a binary from
  a macOS install.
- **`ninja` can report "no work to do" on a stale binary (unverified, seen once)** when a header change did not invalidate
  what it should. `touch` the source file to force the relink.
- **`MemFree` is the wrong memory gate.** It excludes reclaimable page cache. Read
  `MemAvailable` from `/proc/meminfo` instead; the two can differ by gigabytes.

## Debugging an app that starts but shows no window

Establish the facts in this order, and do not skip a step because the symptom seems obvious:

1. **Health-check the container first**: `darling shell true`. A failed launch and an app that runs
   silently produce the same empty log.
2. **Confirm the log is non-empty and belongs to the app you launched** (check for its pid in the
   output). An empty log means "did not run", not "no output".
3. **If using the X11 backend, confirm the display exists** before blaming the app: an absent
   `/tmp/.X11-unix/X<n>` socket for your `$DISPLAY` surfaces as "Failed to connect to a window
   server". A headless Xvfb can die; restart it detached with your own display number.
4. **Probe at the entry of the methods on the path**, not after the statement you suspect. Insert
   before a statement or after a method's opening brace - never inside a multi-line message send,
   which breaks the build with misleading parser errors.
5. **Verify the probe is in the binary that actually loads** (our own AppKit build):
   `strings <prefix>/.../AppKit | grep -c <TAG>`.
6. **Distinguish the three cases explicitly**, since they have different fixes: window never created;
   created but never ordered (`orderWindow:`/`makeKeyAndOrderFront:` never called); ordered but never
   mapped (ordering called, no platform window appears).

A document-based app with no document is not expected to have a window. Establish whether a document
should exist before treating its absence as a bug.

## Inspecting a guest process

There is no reliable way to get a native backtrace of a guest process in the default configuration.
Debuggers apply to our own build output only (`darlingserver`, `mldr`, the launcher, frameworks
built from this tree), never to step through guest app code or anything from a macOS install
(`AGENTS.md` section 1). Know these before spending time on them:

- `gdb -p <darlingserver>` failed on one host (unverified elsewhere): `ptrace_scope` was 1, so only a
  direct parent may trace.
- The setuid launcher refuses to run traced ("Failed to drop privileges for non-root mode"). A
  non-setuid copy runs, but `follow-fork-mode child` then breaks `popen`'s fork+exec, and `darling`
  daemonises the container so you are never its parent.
- `/proc/<pid>/task/*/syscall` and `/proc/<pid>/task/*/stack` are permission denied for setuid
  processes (non-dumpable). `/proc/<pid>/maps` is readable.
- In-guest `SIGUSR1` + `backtrace()` does not work: the guest appears not to deliver signals or
  interval timers (guest `alarm()` also never fires).
- **objc message logging (unverified whether it is compiled in).** `instrumentObjcMessageSends()` is
  an empty stub unless `SUPPORT_MESSAGE_LOGGING`, which `objc-config.h` gates on `TARGET_OS_OSX`.
  `basic-headers/TargetConditionals.h` defines `TARGET_OS_OSX` as 1 under `__APPLE_CC__`, so it may
  already be on; check with `clang -E -dM` and the objc4 flags before changing anything. When
  enabled, objc4 writes every msgSend to `/tmp/msgSends-<pid>` inside the prefix. Foundation honours
  `NSObjCMessageLoggingEnabled=YES`.
- **Clean-room limit on all of the above.** Message logging, guest backtraces and probes are for
  confirming which of *our* framework entry points are reached. Never use them to record the internal
  call sequence of a binary from a macOS install, and never turn such a record into an implementation
  (`AGENTS.md` section 1). Probe our own build output; for guest apps use demand analysis only
  (`nm -u`, `otool -L`).

Getting a trace therefore needs a host change - relaxed `ptrace_scope`, a non-daemonising launcher, or
root - not a change to this source tree.

## Building stub frameworks

Apps often fail in dyld with a missing private framework that does not exist anywhere in the tree.
A stub satisfies the loader so the next, more specific error can appear.

    FLAGS=$(ninja -t commands CoreText | grep CTFont.m.o | tr ' ' '\n' \
            | grep -E '^-(D|I|W|O|std|f|no-|isystem|isysroot|mmacosx)' | tr '\n' ' ')
    # aarch64 host shown
    clang $FLAGS -target aarch64-apple-darwin20 -fuse-ld=/usr/bin/ld64.lld -nostdlib -dynamiclib \
          -Wl,-platform_version,macos,11.0,11.0 -install_name '<guest path>' \
          -o '<prefix><guest path>' stub.c

Details that each cost an attempt: `ld64.lld` worked (the build's own cctools ld64 was not tried); `-nostdlib` is required or it looks
for a `-lSystem` that does not exist here; `-platform_version` is a *linker* flag, so pass it as
`-Wl,-platform_version,...`; dependency flags (`-MD`, `-MT`, `-MF`) hijack the `-o` output name, so
whitelist the flags you keep rather than stripping the ones you do not; the path dyld reports is a
**guest** path and must be created under the prefix on the **host**; create the *dirname* of the binary
path, not the path itself. A ~120-byte result is a bare Mach-O header that will never load - a real
stub is tens of kilobytes.

**Stub only private shims.** Stubbing a framework the app genuinely calls in converts a clean
"library not loaded" into undefined symbols later, which is a worse failure. The signal that stubbing
has run out of road is a missing **symbol** rather than a missing library.

## Working in these trees

- **Prebuilt runtime: planned, not available.** No CI runtime image exists yet, so a full build
  from source is the only route (`AGENTS.md` section 3). One measurement on an 8-core aarch64 host:
  about 28k ninja steps, 15-24 minutes wall; re-measure before quoting. Rebuild only what you
  changed, in a private prefix, under the heavy-build lock.
- When an image or prefix fails to load a wrapped library, compare the host soname it was generated
  against with the host's: `strings <dylib> | grep '\.so\.'` on our own build output shows it.
- A prefix must be initialised by the launcher - point `DPREFIX` at an absent or empty directory and
  let it bootstrap. A hand-assembled prefix is rejected ("non-empty but is not an initialized Darling prefix").
  A prefix holds only deltas; one that has grown to gigabytes is accumulated cruft.
- Install frameworks from the build into the prefix explicitly rather than assuming the payload has
  them - verify the binary exists and is the right size, since an empty framework directory or a
  self-referential symlink (`A -> A`) otherwise fails much later and far from the cause.
