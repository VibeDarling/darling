# Reproducible VibeDarling PR prefix

`all-vibedarling-pr-prefix.py` creates a point-in-time lock of the current
VibeDarling default branch (the remote `HEAD`; `main` or `master` in practice) for the superproject and every repository
in its `.gitmodules`, plus all open VibeDarling PRs targeting those repositories.
The lock contains exact base and PR-head commit IDs. PRs in other VibeDarling
repositories are listed under `excluded_open_prs` with the reason.
Repositories whose default branch has another name are marked with
`branch_exception` in the lock; for example, `darling-openjdk` currently uses
`xcodejdk14-release` and has no `main` or `master` ref.
An explicit `.gitmodules` `branch` setting takes precedence. The four
LibreSSL checkout paths declare distinct `v2.x` branches because its `master`
branch does not contain their build sources. Those branch choices and commits
are recorded separately in the lock.

Use a clean, independent clone of `https://github.com/VibeDarling/darling.git`
at its current default branch for resolution. A linked worktree is insufficient
for checkout or building because submodule Git directories can be shared.

```sh
python3 tools/all-vibedarling-pr-prefix.py resolve \
  --source /path/to/clean-vibedarling-master \
  --output /path/to/refs.lock.json

python3 tools/all-vibedarling-pr-prefix.py checkout \
  --lock /path/to/refs.lock.json \
  --workspace /path/to/new-empty-workspace --jobs 6

python3 tools/all-vibedarling-pr-prefix.py resolve-nested \
  --workspace /path/to/new-empty-workspace \
  --output /path/to/nested.lock.json

python3 tools/all-vibedarling-pr-prefix.py checkout-nested \
  --workspace /path/to/new-empty-workspace \
  --lock /path/to/nested.lock.json

python3 tools/all-vibedarling-pr-prefix.py build \
  --workspace /path/to/new-empty-workspace --jobs 4
```

`checkout` requires a *nonexistent* workspace. It clones the superproject and
each submodule independently (shallow clones, deepened on demand when a PR branched behind
the locked base needs its merge base), checks out each locked base, merges PR head commits
in ascending PR number order, and commits the final submodule pointers. The
workspace contains `refs.lock.json` and `integrated.json` for review. A
superproject PR may add a GitHub submodule outside VibeDarling. Checkout uses
its exact PR gitlink commit, records the URL and SHA in `integrated.json`, and
does not search or merge PRs in that external repository. If a ref cannot be
fetched at its recorded SHA, a merge conflicts, or a superproject PR removes or
changes a locked submodule, checkout stops and leaves the workspace for inspection.
It never chooses a replacement ref or resolves a conflict automatically. Run
`resolve` again for a new snapshot after source changes.

Some top-level repositories have their own submodules. `resolve-nested` reads
the integrated parent trees and locks current VibeDarling default branches and
open PRs for those nested repositories. External nested dependencies retain
their parent gitlink pins. `checkout-nested` materializes those refs, commits
updated parent gitlinks, and records the final nested commits. The two lock
files together define the complete input set. A deeper nested layer stops
explicitly for review. `build` requires this step when nested modules exist.

To include a fix owned by another agent, obtain its committed SHA and apply it
after nested integration, before configuring or queuing the build:

```sh
python3 tools/all-vibedarling-pr-prefix.py supplement \
  --workspace /path/to/new-empty-workspace \
  --path src/external/cocotron \
  --from-repo /path/to/appzapper-private-cocotron \
  --commit FULL_40_CHARACTER_COMMIT_SHA \
  --reason 'AppZapper text measurement fix; verified by its runtime probe'
```

This merges the exact commit into the private submodule and commits its new
superproject gitlink. It preserves the original PR locks and records the donor
path, input SHA, purpose, prior commits, resulting commits, and status in
`supplements.json`. The donor is read only and must have the matching VibeDarling
origin. Only top-level VibeDarling submodules are supported; changes to nested
gitlinks or `.gitmodules` require a new dependency lock. Missing commits and
conflicts stop explicitly, retaining conflicts and their paths for inspection.
A failed attempt prevents further supplementation and building in that workspace.

An existing `build`, `image`, or `prefix` prevents supplementation. Create a new
independent workspace from the original locks to apply fixes when an earlier
build is queued or configured. The prefix builder verifies that its source HEAD
matches the final recorded supplement. This command integrates source commits;
SwiftUI's separate build and file staging remain the supplement owner's work.

`build` requires a completed checkout and creates only new `build`, `image`,
and `prefix` paths inside the workspace. It installs through `DESTDIR`, runs the
build-tree launcher with `DPREFIX` and `DARLING_INSTALL_PREFIX`, and verifies
that the new prefix initialized. Pass additional CMake options as repeated
`--cmake-arg=-DNAME=VALUE` arguments. It checks `ninja -n` after the build to
catch build-graph regeneration that still has pending work.
This builds the declared Darling source tree. Its Swift submodule currently has
no SwiftUI framework build or install target, so the resulting image does not
attest a functional SwiftUI runtime. Stage any separately built SwiftUI
supplement with its own locked source, toolchain, SDK, and installed-file record.
Use `build --configure-only` to run the light CMake check first. A later `build`
resumes only if its recorded source commit matches the configured tree, so a
heavy compile can wait for host capacity without discarding the build directory.
If compilation fails and a committed source correction is required, stop the
owned build first, record/apply its exact commits, and explicitly run
`build --configure-only --reconfigure`. This reuses the known private build
directory, records old and new source SHAs in `.darling-pr-prefix-history.json`,
and updates its source binding after successful CMake configuration. It refuses
any existing image or prefix. Normal resume still rejects a changed source SHA.
Source must remain clean after configuration and compilation, before staging.

For a limited network diagnostic, repeat `--repo NAME` with `resolve`. The
resulting lock has `complete: false`; `checkout` rejects it. The default
resolution scans every repository declared by `.gitmodules`.

Pass `--no-prs` to `resolve` to lock the default branches only. The open-PR search is
skipped entirely, no pull request is merged and `excluded_open_prs` is empty. The lock
records `"no_prs": true`; `resolve-nested` inherits it and rejects `--no-prs` against a
lock that includes PRs, so a run cannot mix the two modes.

A PR whose base branch is not the branch a repository is locked to (for example a
release branch) is not merged; it is listed in `excluded_open_prs` with a reason. The
base branch is read per PR from the pulls API (one call per PR of a selected repository), so set
`GITHUB_TOKEN` or run `gh auth login` for a full run: unauthenticated limits are 60 requests
an hour. Known limitation: a repository declared several times in `.gitmodules` matches PRs
only to entries with an explicit `branch`; a PR to the default branch of such a repository
would be excluded as untracked (all four darling-libressl entries declare branches).

Transient network and API errors (resets, 5xx, failed `git ls-remote`, command timeouts) are
retried a bounded number of times; permanent ones (repository not found, DNS, authentication)
are not. A rate limit that resets later than 60s, or a Retry-After above 60s, fails at once
with the reset time and the GITHUB_TOKEN hint. After the attempts, resolution fails naming the
repository and writes no lock.

The PR inventory uses GitHub's public search API. Set `GITHUB_TOKEN` if its
unauthenticated rate limit is insufficient. A later run needs network access to
the VibeDarling repositories and enough space for the full source and build.
The lock is a snapshot, so a later PR or default-branch change requires a new
resolution to enter the input set.

`checkout --seed-superproject /path/to/independent/clone` copies an existing
VibeDarling clone with `git clone --no-local` before applying the lock. This can
save a second superproject download while keeping Git object storage independent.
`checkout --seed-submodules-root /path/to/populated/tree` similarly copies
available submodules with `--no-local`, then points each new clone at its
VibeDarling origin for any missing locked commits. The seed tree is read only.
Seeded clones also copy cached LFS objects into their private Git directories
before checkout, without hardlinks or alternates. Git LFS verifies and expands
the pointer inputs during checkout; missing assets still fail explicitly.
`checkout-nested --seed-submodules-root /path/to/populated/tree` uses the same
read-only seeding for nested VibeDarling and externally pinned dependencies.
PR-added external top-level submodules also use the provided seed when present.

For an unfinished checkout, `checkout --resume` requires the original byte-identical
lock, matching origins, independent Git storage, and no build/image/prefix or
completed integration. It preserves already merged heads and continues remaining
inputs. Unrelated source changes are rejected. The default still stops on conflicts.

`--resolutions reviewed.json` permits only exact reviewed conflicts. Each rule
contains `repo`, `pr`, full `head`, `before_tree`, exact output of
`git ls-files --unmerged` in `stages`, `files` mapping the conflicted paths to
reviewed UTF-8 source, and `reason`. Every identity and conflict-stage blob must
match; the file set must exactly cover the conflicts. The merge remains a real
Git merge with both parents. Resulting trees/blobs and source contents are copied
into `integrated.json` for audit. Changed inputs or unexpected conflicts stop.
Do not use generic ours/theirs resolution policies.

Full SwiftUI supplement verification uses `tools/build-swiftui-supplement.py`
with the owner's clean pinned `--builder-repo`, exact `--builder-commit`,
`--inputs`, read-only `--runtime-root`, and nonexistent separate `--workspace`.
The input schema extends the owner interface with
`integration.link_targets` and `integration.install_targets` arrays of target
names. Compile-only manifests fail. Every output must belong to the separate
workspace; installed outputs must be under its `image`, including the actual
SwiftUI framework image. Dirty-source opt-ins and dynamic lookup links fail.
The owner entrypoint acquires the shared build lock; invoke this adapter after
releasing any outer runtime-build lock. It verifies a fresh build and a repeat
with no pending work, recording both results and install-file hashes in
`prefix-tooling-swiftui.json`. It never writes the input runtime or claims
actual app execution. Arm64 only; complete owner link/install inputs are required.
This adapter does not yet stage an overlay or turn a compile-only recipe into
functional SwiftUI. Keep the dated runtime image immutable.

`build --stage-only` completes the full runtime and DESTDIR install, writing
`runtime.manifest.json` with clean source/tree pins and lock hashes. It defers
prefix execution so a separately verified SwiftUI overlay can be integrated
before launching a final private prefix. SwiftUI readiness remains false until
its real closure passes; do not describe this base stage as a full SwiftUI prefix.

`verify-build --workspace WORKSPACE --jobs 2` requires the same clean source
binding and a completed no-work dry run, runs the real incremental build, and
checks another dry run. It writes `incremental.verify.json` without restaging
or launching a prefix. Both commands must hold the shared heavy-build flock.

If an open PR's target repository does not advertise `refs/pull/N/head`, the
resolver queries that exact VibeDarling PR's live API state and declared fork
head, then requires its branch to advertise the identical commit. The lock
records `head_source` with the URL, ref, SHA and missing-ref reason. Checkout
fetches that exact head and verifies the commit object; it never substitutes
`refs/pull/N/merge`. Closed/merged PRs, missing fork sources, changed branch heads
and unavailable locked commit objects stop explicitly. Fork source is the
source of this VibeDarling PR, not an additional external PR inventory.

`checkout-nested --resume --resolutions reviewed.json` applies the same exact
conflict rules to retained nested clones. The nested lock is saved before
materialization and must remain byte-identical and bound to the original top
lock/map. Built or completed workspaces, origin/storage mismatches and unexpected
conflicts fail. Nested resolution source/tree/blob records accompany each
realized dependency in `nested.integrated.json`; external dependencies stay pinned.

Prefix smoke executes `/usr/bin/true`, not a shell builtin. `--disable-ptrauth` sets
`DARLING_DISABLE_PTRAUTH=1` for the private guest smoke and records the mode; it
disables pointer authentication for guest processes only and is an explicit opt-in,
never a default. Use the matching build-tree launcher and runtime root outside the
sandbox for launch and shutdown; falling back to an installed launcher is not part of
this recipe.

After `build --stage-only`, verify a new private prefix separately:

```sh
python3 tools/all-vibedarling-pr-prefix.py verify-prefix \
  --workspace /absolute/private/workspace --prefix-name prefix-proof
```

Add `--disable-ptrauth` only for an explicit guest PAC opt-in. This gate checks
the clean staged source/build/lock binding, executes actual `/usr/bin/true`,
waits up to 60 seconds for natural completion, then uses matching supported
shutdown. It records the exact server executable, prefix argument, UID, PID,
remaining markers and process state in `prefix-proof.verify.json`, with separate
guest/shutdown logs. A pending wrapper, identity mismatch, shutdown refusal or
remaining server fails the readiness gate and preserves the prefix/evidence.
No timeout sends a signal, removes metadata or retries through an installed
launcher. Inspect a failure before retrying supported shutdown for your own
prefix. Successful verification proves this guest route, not GUI or SwiftUI.
Both expanded Unix socket paths must fit Linux `sun_path[108]`, including the
terminator. The verifier rejects longer paths before launching; choose a short
workspace/prefix name. Current launcher/socket translation otherwise truncates
the path, which can leave bootstrap waiting for a different shellspawn socket.
