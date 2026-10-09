# Agent and contributor rules

Read this before changing anything in this repository. Two things here are not negotiable and are
checked in review:

1. the clean-room boundary: **no disassembly, no decompilation, no reading machine code**
2. the commit standard in [Commit standard](#2-commit-standard)

Sections 1 and 2 are identical across every Darling repository, because the boundary and the
standard do not change per project. Section 3 is specific to this checkout.

## 1. Clean room: no disassembly

### The rule

Never disassemble or decompile a binary to work out what it does, and never transcribe
decompiled output into source, a comment, an issue, or a pull request. This applies to Apple's
binaries without exception, and to every other binary whose source you are not the author of.

The line is drawn at **expression**, not at information:

- Names and interfaces are fair game. Symbol names, class names, selector names, argument labels,
  type encodings, load commands, and the dependency list are facts about the *interface*. You can
  learn them without reading a single instruction, and the superproject's `tools/stub-gen-c-func`
  and `tools/stub-gen-objc` do exactly that.
- Implementation is off limits. The order of statements, the algorithm, the chosen data layout, the
  constant values, the error-handling strategy, the shape of a function: that is Apple's
  copyrighted expression, and copying it is both a licence violation and the thing that makes a
  clean-room reimplementation indefensible.

If you cannot state the behaviour without looking at how the original does it, you do not know the
behaviour yet. Go one rung down the ladder.

### Never, under any circumstances

Applied to any binary that is not your own build output or a public open-source artefact:

- `otool -tV`, `otool -t`, `otool -f`, `otool -s`, `otool -l` on a Mach-O from a macOS install
- `objdump -d`, `llvm-objdump --disassemble`, `radare2`, `r2`, `cutter`, `Ghidra`, `Hopper`, `IDA`,
  `Binary Ninja`, `jtool2` / `jtool`, `lief`, `MachOView`, `otool-classic`
- `lldb` or `gdb` attached to a macOS process, a system daemon, or a system framework, for the
  purpose of stepping through or dumping code
- `DYLD_INSERT_LIBRARIES`, `DYLD_PRINT_*` or `frida` injected into an Apple binary to hook its
  internals
- `dtrace` / `perf` / `kprobe` tracing of Apple code paths
- `class-dump`, or any other tool that reconstructs a class hierarchy from a running Apple process
- decompilers of any kind, including LLM-based ones
- reading a disassembly listing produced by anyone else, including in a blog post, a conference
  talk, a chat message, or a reversed-engineering wiki

That last one is the one people break by accident. A public write-up is *readable as
specification*, and section "Escalation ladder" covers how, but it must never become the source of
an implementation.

### Escalation ladder

Work down this list in order. Stop at the first rung that answers the question, and record which
rung you used in the commit body.

1. **Apple's published open-source releases** ([apple-oss-distributions][oss]). `xnu`, `Libc`,
   `Libsystem`, `libobjc`, `libdispatch`, `Libxpc`, `Libclosure`, `Security`, `AvailabilityVersions`,
   `corecrypto`, `swift-corelibs-foundation`, and the Swift compiler runtime are all published
   source under licences that permit reuse. This is where most of the low-level code in this tree
   came from, and it is the correct first stop.
2. **Headers already vendored in this tree**, in particular the superproject's `framework-include/`,
   `framework-private-include/` and `basic-headers/`, plus this repository's own header
   directories. If a prototype is declared there, the answer is already written down; read it
   instead of guessing.
3. **Apple's public documentation.** developer.apple.com, the archived documentation sets, the
   `man` pages, and the header comments shipped with the sources from rung 1. Public API behaviour
   is specified, and implementing a specification is the whole point.
4. **Dynamic observation at the API boundary.** Call the function, class or syscall with known
   inputs and record what comes out. A guest program under Darling, a small harness in the tests
   directory, or the target platform itself are all legitimate instruments here, because observing
   a documented interface from outside is what a compatibility layer is for. Observe inputs and
   outputs; do not step into the callee.
5. **Demand analysis.** `nm` and `otool -L` tell you which symbols and libraries binaries actually
   bind, so you can tell a missing symbol from a missing feature. See "Binaries you may point
   tools at" below.
6. **Nothing above answers it.** Leave the symbol out and let the link error say so, or implement
   the conservative behaviour the documentation implies and say in the commit body that it is a
   guess and why.

Jumping from rung 4 to reading code is the failure this section exists to prevent.

### Binaries you may point tools at

- **Your own build output.** Anything produced by this repository's build is fair game, including
  for disassembling Darling's own code when debugging it.
- **Binaries you wrote or that you are the author of.**
- **Guest applications running inside a Darling prefix**, for **demand analysis only**: which
  symbols they import, which frameworks they load, which classes they reference. That tells you
  what to implement. It does not tell you how Apple implemented it, and you must not read their
  code to find out.
- **Apple's open-source releases from rung 1.** They are source. Read them; that is the point.

Never point any of these tools at a binary from a macOS install, and never run
`tools/stub-gen-c-func` or `tools/stub-gen-objc` against one. If a script in this repository appears
to do that, that is a bug in the script: fix it or report it.

### Provenance

Every non-obvious change records where its specification came from. The commit body names the rung
from the ladder, and names the specific file, header, documentation page, or observation. "Fixed
the behaviour" is not provenance.

For a change whose behaviour is not derivable from rungs 1 to 4, the commit body says so explicitly
and states which rung supplied the guess. A reviewer can then judge the risk, which is the only
reason the information is worth collecting.

### Never commit

- Mach-O binaries, `.dSYM` bundles, `.class` files, PDBs, or any compiled output of Apple's
- disassembly listings, decompiler output, or class dumps
- header trees scraped from a local Xcode or macOS install that are not present in the upstream
  open-source release
- symbol dumps of Apple binaries
- anything under `framework-include/` or `framework-private-include/` whose origin you cannot name

### If you break the rule

Stop. Do not paste the listing into a source file, a comment, an issue, a PR, or a chat message,
and do not "clean it up" by rewriting it in your own words, which is still derived from it. Delete
the artefact, then say plainly in the PR body what happened and which files were touched, so a
reviewer can assess the damage. An honest disclosure costs one paragraph; a hidden derivative
implementation invalidates the whole change.

## 2. Commit standard

### Format

`<scope>: <summary>` in the imperative mood, lowercase, no trailing period.

The scope is the subsystem or framework, matching the vocabulary the surrounding commits already
use. Check the last 20 commits before writing one; do not invent a scope scheme for a repository
that already has one. The superproject and `xnu` use `<subsystem>: <summary>`, `cocotron` uses
Conventional Commits (`feat(appkit):`, `fix(appkit):`), and `foundation` is mixed. Follow the
branch you are on, not the branch you wish existed.

Keep the subject under 72 characters. If it does not fit, the change is too big or the scope is
wrong, both of which are fixable.

### Body

Required for anything non-obvious, and expected in this project: a reviewer here reads the body to
find out *why*, because the diff cannot tell them.

- **Why** the change is needed, in terms of the observable failure it removes. Not a restatement of
  the diff.
- **Where the behaviour came from**, naming the ladder rung from section 1, for anything whose
  specification was not already in the tree.
- **What was verified, and how it was run.** A command, a prefix, a test name. "Tests pass" is not
  verification; the command and its result are.
- **What is deliberately left out**, when that is a judgement worth recording, and why.

A table beats prose when there are several items:

```
  APFSCancelContainerResize         one pointer, result masked to a byte, so int
  APFSVolumeRole                    imported but never called, so unconstrained
  CacheDeletePurgeSpaceWithInfo     two arguments, result discarded, so void
```

Prose is right when there is one idea and a reason behind it. Match the density of the recent
history; the existing bodies in this project run a few paragraphs, not a paragraph.

### Atomicity

One commit, one thing. A commit that both fixes a bug and reformats the surrounding file, or that
adds a feature and its logging, is two commits. The test is whether the commit can be reverted on
its own without leaving the tree broken, and whether its subject could be read as a single entry in
a changelog.

Split before you push, not after review asks.

### Never in a commit

- `wip`, `fix`, `tmp`, `asdf`, or a subject that only you can decode
- a `--no-verify` run, an amended commit that was already pushed, a force-push to a shared branch
- unrelated reformatting, reordering, or whitespace churn: that is its own commit, or nothing
- commented-out code, `TODO` without an owner and a reason, debug prints, or a debugger left in
- build output, logs, coredumps, or a prefix directory
- a submodule pointer bump you did not mean to make, and especially a bump that mixes unrelated
  submodule work into a source change: those are separate commits
- anything from the "Never commit" list in section 1

### Before you commit

- `git status` shows only the files you meant to change, and no submodule you did not touch
- the change builds, and you have run the thing, not just the compiler
- a bug fix carries a regression test that fails without the fix
- the body says how it was verified, with the command
- the commit was reviewed before staging, not only after

Never commit with a broken tree because a hook complained: fix the hook's complaint or the code.
Skipping hooks is not a workflow.

### Branch and PR

- Branch: `<type>/<short-description>`, matching the repository's existing branches.
- A PR is one concern, under 400 changed lines where the project allows it, with a subject in the
  same format as a commit.
- The PR body states what problem this solves, how it was verified, and the ladder rung for
  anything non-obvious. Reviewers read the PR body before the diff.

[oss]: https://github.com/apple-oss-distributions

## 3. This repository

The superproject. A Mach-O loader (`mldr`) plus `darlingserver` plus 149 submodules under
`src/external/`, wired by `src/CMakeLists.txt`. Default branch `master`; submodule default branches
vary (most `master`, some `main`, such as `darling-xnu` and `darlingserver`, a few pinned to a
release branch), so any script assuming one name silently skips the others.

- **Issues**: before working on a VibeDarling issue, follow `.claude/ISSUE_COLLABORATION.md` (claim
  it in a GitHub comment for 24 hours, renew while working).
- **Build**: CMake with Ninja. Unit tests are the `ENABLE_TESTS` option in the top-level
  `CMakeLists.txt`, off by default, and install into a prefix rather than the host.
- **Heavy-build lock**: the build machine is shared and short on RAM. Every build, install or
  prefix boot runs under `flock -w 1800 /tmp/agent-locks/darling-heavy-build.lock <command>`, and
  uses `ninja -j1` when `MemAvailable` in `/proc/meminfo` is low (not `MemFree`, see
  `docs/agent-knowledge.md`). Downloading or extracting a runtime needs no lock.
- **Prebuilt runtime** (status: planned, no CI release exists yet).
  Planned: CI publishes releases on `VibeDarling/darling` tagged `vYYYY.MM.DD-<sha7>` with
  `darling-runtime-<tag>-linux-<uname -m>.tar.zst`, `SHA256SUMS`, `manifest.json`,
  `refs.lock.json` and `nested.refs.lock.json`, with build attestation. The images are built
  from every module's default-branch HEAD with no open PRs, packaged with setuid bits stripped
  (private, user-owned installs only), and `manifest.json` lists per-arch (`uname -m`) file,
  sha256 and the host sonames the wrapper dylibs need. Source: the ci-binaries design, not yet in
  this repository.
  Today: the only releases are `v0.1.YYYYMMDD[-N]` (latest `v0.1.20260921` on 2026-10-09). They
  are GitHub-generated changelogs on a tag, have no assets, and are not runtime images. Do not
  look for a download; use the source build below.
  After the first CI release, check `gh release list -R VibeDarling/darling` for a `vYYYY.MM.DD-*`
  tag, verify the sha256 and `gh attestation verify <file> --repo VibeDarling/darling`, extract into a
  new private directory, and run it as in "Run a local build without installing it" with
  `DARLING_INSTALL_PREFIX=<dir>/usr/local`. Then, and only then, update this bullet to drop the
  "planned" marker.
  Limits to keep when it lands: prebuilts contain default branches only, so an open PR needs a
  source build; changes to CMake, `mldr`, `darlingserver` or `libsystem_kernel` need a full
  build; an overlay of one rebuilt component on a COPY of the image is valid only for
  ABI-compatible changes and cannot delete files; wrapper dylibs embed the build host's library
  versions, so fall back to a source build if the image will not load.

- **Recipe: build a private runtime from default branches and run it** (works today).
  1. Use an independent clone with every submodule at its own default branch; not a worktree
     (see the worktree bullet).
  2. Take the heavy-build lock (see the heavy-build lock bullet).
  3. `cmake -G Ninja` with `CMAKE_INSTALL_PREFIX=/usr/local`, then `ninja`; run `ninja -n` until it
     reports nothing left to do.
  4. Install and run as in "Run a local build without installing it" below.
  5. Stop it with `darling shutdown`, not kill.
  Do not install or publish from a tree with uncommitted changes.
- **Submodule URLs are relative**: all 149 entries in `.gitmodules` are `../<name>.git`, so they
  resolve against whatever `origin` points at. Pointing `origin` at a personal fork breaks
  `submodule init`, because a fork usually holds only the superproject.
- **Worktrees do not isolate submodules.** Submodule gitdirs live in the main clone's
  `.git/modules`, and a linked worktree shares them, so `git submodule update` inside a worktree
  moves the main clone's HEADs for every worktree on it. Anything needing populated submodules or a
  build wants an independent clone instead.
- **A clean `ninja` exit does not mean the build finished.** When new targets appear the first run
  regenerates the build graph and then executes the old one, exiting 0 with work still pending.
  Confirm with `ninja -n`.
- **Run a local build without installing it**: `DESTDIR=<dir> ninja install` needs no root, then
  `DPREFIX=<prefix> DARLING_INSTALL_PREFIX=<dir>/usr/local <build>/src/startup/darling shell <prog>`.
  Use the build tree's own non-setuid launcher. The installed setuid launcher deliberately ignores
  `DARLING_INSTALL_PREFIX`: it is read through `getenvTrusted()`, which returns nothing under
  `AT_SECURE`, so a hardlink beside a planted `bin/darlingserver` cannot run that binary as root.
  That guard is correct, do not route around it. `DARLING_LIBEXEC_PATH` is an output the launcher
  sets for its children (`setenv` in `src/startup/darling.c`), not an input.
- **Stop a container with `darling shutdown`**, never by killing it. The launcher's child runs as
  root under the setuid binary, so a kill fails with `Operation not permitted`, and `timeout` kills
  the child it launched. Shutdown is prefix-scoped and exits 0 when nothing is running; it exits 1
  when it cannot verify the prefix's server.
- **A prefix takes its frameworks from the installed runtime**, and a stopped prefix shows only a
  directory skeleton, so listing one proves nothing about a missing backend.
- **Identify guest processes by `comm` or `/proc/<pid>/exe`, never by cmdline**: `mldr` rewrites its
  own cmdline to the guest program name, so `ps aux | grep mldr` finds none of them.
- **Raise the log level before concluding a line is absent.** `kern_printf` logs at `info` while
  `darlingserver` defaults to `Error` (`DEFAULT_LOG_CUTOFF` in
  `src/external/darlingserver/src/logging.cpp`), so set `DSERVER_LOG_LEVEL=info` before treating
  silence as evidence. The setuid launcher passes it through (`g_darlingserverEnvAllowlist` in
  `src/startup/darling.c`).
- **Provenance**: never install or publish an artifact built from a tree with uncommitted changes.
  Commit first, even to a throwaway branch, and record what was actually built.

## 4. How to work in this repository

Sections 1-3 cover what the code requires. This section covers how to arrive at a correct change.

### Understand before changing
Read the file you are about to edit, and the callers of what you are changing, before writing a line.
Map the area first (`grep`/`rg` plus reading the sources); this codebase is large enough that
directory structure does not tell you where behaviour lives.

### Plan before non-trivial changes
For anything beyond a few obvious steps, write what you will change, where, and how you will prove it,
before implementing. State what breaks without each part; a step you cannot justify is a step to cut.
Keep plans in source control or your own notes, not only in conversation.

### Reuse before writing
Before adding a function, type, or helper, search for something that already does the job or about 80%
of it. Exact fit: reuse. Close fit: refactor the existing code and say so. Never silently copy-paste.

### Root cause, not symptom
When something fails, fix the faulty assumption, not the observable. A patch that only makes a test pass
is usually hiding the real issue. Ask what would have to be true for this to work, and check that.

### No "done" without proof
Tests passing is necessary, not sufficient. Exercise the real path the user takes: launch the actual
app, hit the actual endpoint, drive the actual code. If you cannot verify, say so explicitly rather
than implying success. A regression test must replicate the real failing scenario and be shown to fail
before the fix.

### Measure; do not infer
This is the failure mode that costs the most time here. Process liveness, elapsed time, wait channels,
symbol tables and tool output on unfamiliar binaries are all *indirect*, and each has misled a
diagnosis: an app whose main thread sat in `epoll_wait` was read as "hung" and also as "idle"
conclusively, and both readings were wrong. Confirm a runtime claim with the thing itself, not a proxy.

Two corollaries that cost real time:
- **Probe at the entry of what you are debugging, not after the statement you suspect.** A probe placed
  after the failing statement reports "the code before it never ran", which is indistinguishable from
  "the method was never called".
- **Check that a log line is absent for the right reason.** An empty log often means the run never
  happened (the container failed, the binary was not installed) rather than that the event did not occur.

### Verify before asserting status
Re-read the live source before reporting any count or state. Do not report success, cleanliness or
readiness from memory or from an earlier turn; stale or optimistic status is a defect, not a courtesy.

### Fail loud
No silent fallbacks, no invented defaults, no magic constants, no stringly-typed enums standing in for
a real type. If something required is missing or wrong, return an explicit error. Validate external
input at the boundary and reject what you do not recognise.

### Elegance over cleverness
Prefer fewer moving parts: fewer lines, fewer concepts, fewer names. Treat "this feels like a hack" as a
signal to look for the clean version. Skip the ceremony for the obvious one-liner.

### Minimal impact
Touch only what the task requires. No drive-by refactors, reformatting, or added comments in code you
were not asked to change. Leave existing problems noted rather than fixed in passing.

### Comments earn their line
Default to none. Add a comment only where the *why* is not deducible from the code. Generated comments
are where filler accumulates; prune them, and treat the pruning as a chance to notice real design
problems.

### Flag what you find
If you notice an existing bug or sharp edge, record it (see section 5) rather than fixing it silently
inside an unrelated change.

## 5. Knowledge base and record-keeping

- **Durable technical knowledge**: [`docs/agent-knowledge.md`](docs/agent-knowledge.md) - measured facts,
  worked recipes, and expensive-to-rediscover pitfalls. Add to it when you learn something that cost real
  time and is still true.
- **Per-checkout notes**: keep a short `STATUS.md` in your own scratch directory. Current state, what you
  verified, what is blocked, what you tried that failed.
- **Known problems**: the repository already has `known-issues.md`. Add an entry when you find a real,
  reproducible defect, with how to reproduce it. This is for defects, not for status.

### Scratch layout and handover
- One scratch directory per task, outside the checkout and outside `/tmp` (`/tmp` is a small shared
  tmpfs; use it only for locks, sockets and files a tool creates itself).
- `STATUS.md` at the top of that directory, with its owner and the date of the last update. Rewrite
  it as state changes rather than appending; when the task ends, mark it done and say where the
  result landed (commit, PR, or file).
- Handing work to another agent: write `HANDOVER-<name>.md` in your working directory with the task,
  what is done, what is in progress, branches and PRs, blockers, exact next steps, and paths to the
  evidence. Commit any work first, tell whoever takes over where the file is, then stop. Never move
  another agent's work before it has handed over.

Deliberately **not** kept here: per-app launch status, lists of currently-failing things, branch
inventories, or anything that goes stale on its own. Those belong in a scratch `STATUS.md`, not in a
document that will be read months later and trusted.

### Safety: never signal through an empty variable
Compare or kill processes only against a variable you have checked is non-empty, and prefer
`darling shutdown` (section 3) over signalling at all. An empty variable makes comparisons match
*everything unreadable*, including `systemd --user`; this has taken down the desktop. Likewise, never
build a `kill` list by iterating `ps` output with a `for` loop and field extraction - `for` word-splits,
so a field you meant to read can be used as a PID. Pipe into `while read -r a b c`.

### Shared checkouts
Several agents work in these trees at once. Check for other sessions before editing or building, and do
not change shared build configuration, dependency versions, or install steps unilaterally - propose it,
and let the owner decide. Do not kill processes you did not start.
