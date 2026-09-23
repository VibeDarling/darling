# Working on Darling locally

Operational notes for anyone, human or agent, doing local development and integration work on this
repository. These are things that are easy to get wrong in ways that produce a confident wrong
answer rather than an error.

Before starting work on a VibeDarling issue, follow the [issue collaboration protocol](.claude/ISSUE_COLLABORATION.md): claim it in a GitHub comment for 24 hours, renew while working, and let another contributor take over after the claim expires. The long-term goal is to launch Homebrew cask applications on Darling, with app testing divided across agents. Link every merged PR and direct commit to an issue, including older work found during history audits; audit existing code and file actionable issues for gaps. Before merging a PR, follow the independent review gate: five approvals from five different people on the current head commit.

## Repository layout

- This fork is the review hub. PRs go **here**, not to `darlinghq/darling`.
- In a typical checkout `origin` is `darlinghq/darling` and pushes go to a personal fork. Submodule
  URLs in `.gitmodules` are **relative** (`../darling-xnu.git`), so they resolve against whatever
  `origin` points at. Pointing `origin` at a personal fork breaks submodule init, because personal
  forks usually hold only the superproject.
- Default branches differ between repositories: this one uses `master`, `darling-xnu` uses `main`.
  Any script that assumes one will silently skip the other.

## Worktrees do not isolate submodules

Submodule gitdirs live centrally in the main clone's `.git/modules`, and a linked worktree points at
the *same* ones. Running `git submodule update`, `init`, `sync`, or anything `--recursive` inside a
worktree **moves the main clone's submodule HEADs**, visible to every other worktree on it.

Safe in a worktree: superproject-only edits, and resolving a submodule-pointer conflict with
`git update-index --cacheinfo 160000,<sha>,src/external/<name>`, which writes the superproject index
and never enters the submodule.

Anything needing populated submodules or a build gets an **independent clone**:

```sh
git clone --reference <existing-checkout> <url> <dest>
git -c submodule.alternateLocation=superproject \
    -c submodule.alternateErrorStrategy=info \
    submodule update --init --recursive --jobs 4
```

Objects are borrowed through alternates, so this is cheap, while refs and HEAD stay private. The
clone then depends on the reference's object store: never `git gc`, `prune` or `repack` the tree it
borrows from, and note that a branch created inside a submodule lives in that shared ref space too.

## Building

CMake with Ninja. Roughly 27k edges from cold; expect tens of minutes at low parallelism, and a few
minutes for an incremental pass after a handful of PRs.

**A clean `ninja` exit does not mean the build is finished.** When new targets appear, the first run
regenerates the build graph and then executes the *old* one, exiting 0 with thousands of edges still
pending. Always confirm with `ninja -n` before believing a build is complete.

## Running a locally built runtime without installing it

Prefer this over replacing `/usr/local`:

```sh
DESTDIR=<dir> ninja install          # unprivileged; needs no root
DPREFIX=<disposable prefix> \
DARLING_INSTALL_PREFIX=<dir>/usr/local \
  <build>/src/startup/darling shell <program>
```

Use the build tree's **own, non-setuid** launcher. The installed setuid launcher ignores
`DARLING_INSTALL_PREFIX` on purpose: it is read through a helper that returns nothing when
`AT_SECURE` is set, because a hardlink of the launcher beside a planted `bin/darlingserver` would
otherwise run that binary as root. That guard is correct; do not route around it.
`DARLING_LIBEXEC_PATH` is an **output** the launcher sets for its children and is not read from you.

Confirm the swap actually happened by looking for something that exists only in your payload rather
than assuming it took.

## Containers and prefixes

- **Stop a container with `darling shutdown`, never by killing it.** The launcher's child runs as
  root under the setuid binary, so the kill fails with `Operation not permitted` and leaves the
  container running while the script believes it cleaned up. This includes `timeout`, which kills
  the child it launched. `shutdown` is prefix-scoped and exits 0 even when nothing is running.
- **A free lock file does not mean the runtime is idle.** Anything started outside your locking
  convention holds no lock. Ask the host: a prefix's `.init.pid` names its own container, and
  `darlingserver`'s prefix is its first argument, which stays readable even for containers owned by
  others. Every container has exactly one server, so an unattributable guest process cannot exist
  without an attributable server.
- **Identify guest processes by `comm` or `/proc/<pid>/exe`, never by cmdline.** `mldr` rewrites its
  own cmdline to the guest program name, so `ps aux | grep mldr` misses all of them.
- **Container startup fails intermittently** with `Timed out waiting for shellspawn in container`.
  One clean run is therefore weak evidence for anything.

## Diagnosing

- **A prefix takes its frameworks from the installed runtime**, and a *stopped* prefix shows only a
  directory skeleton. Do not conclude a framework or backend is missing by listing one: a working
  backend looks equally empty there.
- **The reported macOS version lives in the prefix.** Prefixes created before a runtime change keep
  reporting the old version; only a fresh prefix shows the new one.
- **When a guest dies with 128+N, read the coredump before designing an experiment.**
  `coredumpctl` records these automatically. Triage in order: signal, then `si_code`, then sibling
  timestamps. Several deaths in the same second under one command line is a process-group kill;
  a single process dying alone is a self-abort. `coredumpctl info` gives the guest's real command line,
  since `EXE` is always `mldr`. Never use `coredumpctl dump --output=-`: it truncates to roughly 2KB
  and exits 0.
- **Raise the log level before concluding a line is absent.** `kern_printf` logs at `info` while
  `darlingserver`'s default cutoff is `Error`, so at the default an absence means nothing. Set
  `DSERVER_LOG_LEVEL=info` so that a missing line becomes evidence.

## Provenance

Never install or publish an artifact built from a tree with uncommitted changes. The moment that
working tree is cleaned, nobody can rebuild what was installed. Commit first, even to a throwaway
branch, and record what was actually built rather than what should have been.
