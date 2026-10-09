# Agent and contributor rules

Read this before changing anything in this repository. Two things here are not negotiable and are
checked in review:

1. the clean-room boundary: **no disassembly, no decompilation, no reading machine code**
2. the commit standard in [Commit standard](#2-commit-standard)

Section 1 is identical across every Darling repository, because the boundary does not change per
project. Section 2 is the same standard everywhere and differs only in the scope vocabulary under
"Format". Section 3 is specific to this checkout.

## 1. Clean room: no disassembly

### The rule

Never disassemble or decompile a binary to work out what it does, and never transcribe
decompiled output into source, a comment, an issue, or a pull request. This applies to Apple's
binaries without exception, and to every other binary whose source you are not the author of.

The line is drawn at **expression**, not at information:

- Names and interfaces are fair game when they come from a permitted source: rungs 1 to 4, or the
  demand analysis of rung 5 on a guest application. Extracting them from an Apple binary with any
  other tool is not, even if no instruction is read. Symbol names, class names, selector names,
  argument labels, type encodings, load commands, and the dependency list are facts about the
  *interface*.
- Implementation is off limits. The order of statements, the algorithm, the chosen data layout, the
  constant values, the error-handling strategy, the shape of a function: that is Apple's
  copyrighted expression, and copying it is both a licence violation and the thing that makes a
  clean-room reimplementation indefensible.

If you cannot state the behaviour without looking at how the original does it, you do not know the
behaviour yet. Go one rung down the ladder.

### Never, under any circumstances

Applied to any binary that is not your own build output or a public open-source artefact, including
third-party guest applications, and to core dumps, memory images and caches that contain Apple code
or data. A binary shipped in a macOS install, Xcode, an SDK or the dyld shared cache is never an
open-source artefact, even when Apple publishes source for it.

On a binary covered by this list, the only tools you may run that read or parse its contents are
those in "Binaries you may point tools at". Copying, hashing, and running a guest application under
Darling (rung 4) are not reading it. Everything else that reads or parses it is banned whether or
not it is named below, however it is invoked (directly, through `xcrun`, a wrapper or a script).
Named for clarity:

- `otool` / `llvm-otool` in any mode other than `-L`, and `otool-classic`
- `objdump` / `llvm-objdump` in any mode, including GNU `objdump -d`, `-s` and `-x`, and
  `llvm-objdump --disassemble`, `--macho`, `--universal-headers`, `--all-headers`,
  `--chained-fixups`, `--bind` and `--dylibs-used`
- `strings`, `dyldinfo`, `dyld_info`, `llvm-readobj`, `rabin2`, and hex dumpers (`hexdump`, `xxd`,
  `od`)
- `radare2`, `r2`, `cutter`, `Ghidra`, `Hopper`, `IDA`, `Binary Ninja`, `jtool2` / `jtool`, `lief`,
  `MachOView`
- `ipsw` in any subcommand that reads a binary, `dsc_extractor`, or any other tool that extracts or
  disassembles the dyld shared cache
- `lldb` or `gdb` on anything but your own build output and the core dumps described under
  "Binaries you may point tools at", and never to step into, disassemble, or read code, data,
  stack words or backtrace frames belonging to an Apple image a process has loaded
- `DYLD_INSERT_LIBRARIES`, `DYLD_PRINT_*` or `frida` injected into an Apple binary to hook its
  internals, or the `dyld` from a macOS install, or any Apple binary run under instrumentation that
  observes inside it (hooks, breakpoints, single-stepping, PC sampling). Darling's own loader and
  stubs recording calls that reach them are rung 4; what they record is limited as for
  missing-symbol traces under "Provenance": no caller or return addresses, backtraces, stack
  words, or contents behind a pointer.
- `dtrace` / `perf` / `kprobe` tracing of Apple code paths
- `class-dump`, or any other tool that reconstructs a class hierarchy from an Apple binary or a
  running Apple process
- the superproject's `tools/stub-gen-c-func`, `tools/stub-gen-objc`, `tools/darling-stub-gen`,
  `tools/darling-tier1-stub-gen` or `tools/generate-xcode-stubs.py`, or any script wrapping a tool
  on this list, pointed at any binary this list covers: any Apple binary wherever it was copied
  to, including a macOS install and Xcode
- decompilers of any kind, including LLM-based ones
- reading a disassembly listing produced by anyone else, including in a blog post, a conference
  talk, a chat message, or a reverse-engineering wiki

That last one is the one people break by accident. A public write-up that contains no disassembly
or decompiled code may be read as a description of behaviour; cite it, and treat it as rung 6 (a
guess) unless it cites a rung 1 to 3 source. One that quotes disassembly or pseudo-code must not be
read; if you have read it, follow "If a boundary is crossed".

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
5. **Demand analysis.** `nm -u`, `llvm-nm -u -m` (both flags together) and `otool -L` /
   `llvm-otool -L` tell you which symbols and libraries guest applications actually bind, so you
   can tell a missing symbol from a missing feature. See "Binaries you may point tools at" below.
6. **Nothing above answers it.** Leave the symbol out and let the link error say so, or implement
   the conservative behaviour the documentation implies and say in the commit body that it is a
   guess and why.

Jumping from rung 4 to reading code is the failure this section exists to prevent.

### Binaries you may point tools at

- **Your own build output.** Code compiled from source in Darling's repositories (the superproject
  and its submodules). It excludes any Apple
  binary or object the build copies, extracts, thins, re-signs or links in, and anything derived
  from one. It is fair game, including for disassembling Darling's own code when debugging it.
- **Binaries you wrote or that you are the author of.**
- **Guest applications inside a Darling prefix**, for **demand analysis only**: the app's
  executable and the code bundled inside its own app bundle, including Apple stock apps copied
  from a macOS install. Apple frameworks, dylibs, daemons, `dyld`, the dyld shared cache and
  extracts from it are macOS-install code and never guest binaries, wherever they are copied to,
  and no tool that reads or parses a binary, `nm -u` included, may be pointed at them. On a guest
  application the only tools allowed are `nm -u`, `llvm-nm -u -m` (both flags together) and
  `otool -L` / `llvm-otool -L`, to learn which symbols and libraries it imports; `otool -L` /
  `llvm-otool -L` is the way to list dylibs. `file` and `lipo -info` / `lipo -archs` are also
  allowed, on guest applications only, for the format and architecture only (header-level);
  `lipo -thin`, `-extract` and `-detailed_info` stay banned. That tells you what to implement. It
  does not tell you how Apple implemented it. Reading anything these tools print beyond names is
  not allowed either.
- **Apple's open-source releases from rung 1.** They are source. Read them; that is the point.

A core dump of a crashed process built by Darling (such as `mldr` running a guest) may be read
**only** for its register file and memory map (library names, load addresses). Nothing else in it
is read: no disassembly at the pc, no `x/i`, `x/s` or byte dumps of any region, no backtrace
symbolised against macOS-install code, no stepping. Cores are never searched for text; take a
diagnostic such as `dyld`'s `Library not loaded:` from the loader's stderr or log.

Apart from that demand analysis and the core-dump reading above, never point any of these tools at
a binary from a macOS install, and never run the stub generators named above against one. If a
script in this repository appears to do that, that is a bug in the script: fix it or report it.

### Provenance

Every non-obvious change records where its specification came from. The commit body names the rung
from the ladder, and names the specific file, header, documentation page, or observation. "Fixed
the behaviour" is not provenance.

For a change whose behaviour is not derivable from rungs 1 to 4, the commit body says so explicitly
and states which rung supplied the guess. A reviewer can then judge the risk, which is the only
reason the information is worth collecting.

A commit that adds a private name, constant, key or struct layout names the rung and its source
(file, documentation page, the observation described well enough to repeat: harness, inputs,
outputs; or for rung 5 the guest application whose imports name it, which supplies the name only,
never a value, signature or layout), or says GUESS. "GNUstep" and "as Apple does it" are not
sources.

GNUstep's (or any other reimplementation's) behaviour is not a specification of Apple's behaviour,
so citing it is not a rung; it can support a rung 1 to 4 source, never replace one. Reading GNUstep
code is not forbidden by this rule, but licence compatibility is a separate question: flag
the LGPL before copying anything from it.

Missing-symbol tracing in Darling's loader is planned, not yet merged. Where the loader offers it,
it is optional and off by default. A trace may hold only the names of imports the loader could not
resolve (rung 5) and, in modes that record them, raw argument words that reached Darling's own stub
(rung 4). It never holds caller or return addresses, backtraces, stack words, the contents behind a
pointer, or anything read from an Apple image; a trace that does is non-compliant: stop using it,
move the log aside and follow "If a boundary is crossed". A trace never replaces rungs 1 to 3: work
through them first, and name the rung for each fact taken from a trace.

### Never commit

- Mach-O binaries, `.dSYM` bundles, `.class` files, PDBs, or any compiled output of Apple's code
- disassembly listings, decompiler output, or class dumps
- header trees scraped from a local Xcode or macOS install that are not present in the upstream
  open-source release
- symbol dumps of Apple binaries, including raw `nm`/`otool -L` output; the names you implement in
  stubs are not dumps
- missing-symbol trace logs, which are also never attached or pasted raw into an issue or PR
- anything under `framework-include/` or `framework-private-include/` whose origin you cannot name

### If a boundary is crossed

This applies whether you ran a forbidden tool yourself or read such output by accident, including
output someone else produced.

Stop. Do not paste the listing into a source file, a comment, an issue, a PR, or a chat message,
and do not "clean it up" by rewriting it in your own words, which is still derived from it. Then:

1. Report it to whoever assigned the work: what was run, on which binaries, and which files were
   touched, never the output itself. An agent that has run a tool on the "Never" list, or read its
   output (disassembly, decompiled text, a class dump, a symbol or string dump, a trace holding
   anything forbidden above), on any binary the rule covers, stops there and is replaced by a
   fresh agent. Permitted demand-analysis output is not taint.
2. Move the artefact, and everything the tainted agent or person wrote for the task, out of the
   working tree into a directory outside any repository that is plainly marked as tainted. Nobody
   opens, copies or cites it again, and it is not deleted without the approval of the person who
   owns the work. Branches holding the tainted work are not merged or rebased onto; name them in
   the report.
3. For agent work, re-derive it cleanly: the specification is written by a fresh agent with no
   access to the tainted material, from rungs 1 to 3; where they do not answer, that author may
   perform rungs 4 and 5 afresh, never reusing observations, logs or demand lists from the tainted
   party, and otherwise the item is left out or marked GUESS (rung 6). It is implemented by a
   different fresh agent that sees only that specification. A human contributor needs no second
   person: the disclosure in step 4 plus maintainer review of the change is the rule, and the
   maintainer may require a clean re-derivation.
4. Say plainly in the PR body what happened: what was run, on which binaries, which files were
   touched, and whether anything was transcribed (anything that was is moved aside under step 2),
   so a reviewer can assess the damage.

An honest disclosure costs one paragraph; a hidden derivative implementation invalidates the whole
change.

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
release branch), so any script assuming one name silently skips the others. All 149 submodule URLs
in `.gitmodules` are relative (`../<name>` or `../<name>.git`; two have no `.git` suffix).

Operational notes (worktrees and submodules, `ninja -n`, running a build without installing it,
containers and prefixes, diagnosing) are in [CLAUDE.md](CLAUDE.md). Where this section and CLAUDE.md
disagree, CLAUDE.md wins.

- **Issues and PRs**: before working on a VibeDarling issue, follow `.claude/ISSUE_COLLABORATION.md`
  (claim it in a GitHub comment for 24 hours, renew while working). Every merged PR links an issue
  and needs the five-approval gate described there.
- **Build**: CMake with Ninja. Unit tests are the `ENABLE_TESTS` option in the top-level
  `CMakeLists.txt`, off by default, and install into a prefix rather than the host.
- **Heavy-build lock (host convention, not part of this repository)**: on a shared build host,
  serialise every build, install or prefix boot under that host's lock. On the maintainers' host it
  is `flock -w 1800 /tmp/agent-locks/darling-heavy-build.lock <command>`, with `ninja -j1` when
  `MemAvailable` in `/proc/meminfo` is low (not `MemFree`, see `docs/agent-knowledge.md`).
- **No prebuilt runtime exists.** The `v0.1.*` releases are GitHub-generated release notes (a "What's
  Changed" PR list, checked via the releases API for `v0.1.20260921`) with no assets. Build from source; update this bullet when a CI runtime release exists.
- **Recipe: build a private runtime from default branches and run it.**
  1. Use an independent clone with every submodule at its own default branch, not a worktree.
  2. Take the heavy-build lock if your host has one.
  3. `cmake -G Ninja` with `CMAKE_INSTALL_PREFIX=/usr/local`, then `ninja`; run `ninja -n` until it
     reports nothing left to do.
  4. Install and run as in CLAUDE.md, "Running a locally built runtime without installing it".
  5. Stop it with `darling shutdown`, not kill.
  Do not install or publish from a tree with uncommitted changes.
- **`darling shutdown`** exits 1 when it cannot verify the prefix's server (CLAUDE.md covers the
  rest of its behaviour).
- **`DSERVER_LOG_LEVEL`** reaches `darlingserver` through the setuid launcher's pass-through list
  (`g_darlingserverEnvAllowlist` in `src/startup/darling.c`); `DEFAULT_LOG_CUTOFF` in
  `src/external/darlingserver/src/logging.cpp` is where the default is set.

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
- Handing work to another agent: write `HANDOVER-<name>.md` in your scratch
  directory (not the checkout) with the task, what is done, what is in progress, branches and PRs,
  blockers, exact next steps, and paths to the evidence. Commit any work first, send the file's path
  to your coordinator or the agent taking over, then stop. Never move another agent's work before it
  has handed over.

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
