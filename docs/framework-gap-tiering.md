# Triaging missing frameworks by bound-symbol ABI

Most macOS applications that fail to start under Darling abort in `dyld` with
`Library not loaded: ... Reason: image not found`. The obvious response is to add a stub
framework for whatever the message names. That works for some frameworks, is unnecessary for
others, and is not achievable at all for a third group. Which case you are in is not visible
from the error message, the framework's name, or its install path.

This document gives a procedure for telling them apart before spending effort, and records a
measurement taken on 2026-09-20.

## Start here

Given an app that aborts, in order:

1. **Confirm a missing framework is what stops it.** See *Not every abort is a missing
   framework* below. If the core has no `Library not loaded` payload, stop; a stub is the
   wrong tool.
2. **List what it actually needs.** `llvm-objdump --macho --dylibs-used <binary>`, then check
   each path against the prefix. Ignore anything under `LC_LOAD_WEAK_DYLIB`.
3. **Tier each genuinely-missing library** by what the binary binds from it (next section).
4. **Act on the tier.** Tier 1: a stub with the correct install name. Tier 2:
   `tools/darling-stub-gen`, subject to the `class-dump` dependency noted below. Tier 3: file an issue rather than a PR, unless you intend to
   implement Swift ABI records by hand.
5. **Check the next blocker before promising anything.** Clearing one image usually reveals
   the next. Say which one in the PR.

## The three tiers

| Tier | Condition | What it needs |
|---|---|---|
| 1 | Linked, but nothing binds from it | A stub with the correct install name |
| 2 | C / Objective-C symbols bound | `tools/darling-stub-gen`, which needs `class-dump` |
| 3 | Any Swift symbol bound, even alongside C/ObjC | Swift ABI records; no existing tooling helps |

Tier 3 is the hard one, and not because of volume. Satisfying a Swift import means emitting
nominal type descriptors, metadata accessors, protocol conformance records and async function
pointers whose layouts match the closed-source build. `class-dump` cannot see Swift types at
all, so `darling-stub-gen` produces a near-empty stub that still fails to link.

Two intuitions fail here, both toward wasted work:

**"Blocks the most apps" does not mean "most valuable to fix".** The dylibs appearing in the
most load commands are frequently Swift overlays recorded by autolinking and listed under
`LC_LOAD_WEAK_DYLIB`, which `dyld` tolerates when absent. Check the load command before
counting anything: `Audio MIDI Setup`, for instance, lists `libswiftOSLog.dylib` and
`libswiftSpatial.dylib` as weak, and its OSLog-adjacent undefined symbols are C symbols from
libSystem such as `__os_log_impl`, `__os_log_default` and `_os_log_type_enabled`.

**Framework size does not predict cost.** `Chess.app` references 8 Objective-C classes from
GameKit, a large public framework. `System Information.app` needs 20 Swift symbols from the
much smaller private `DeviceRegulatoryInfo`.

## Measurement, 2026-09-20

Apps built for macOS 26.6, in a prefix reporting itself as 11.7.4.

Against one populated prefix: **66** application bundles (`/Applications` and
`/Applications/Utilities`) containing **231** Mach-O binaries. A bundle contributes its main
executable plus helpers, XPC services and `.appex` plugins. Per-library counts below are
bundles.

- **635** distinct install paths missing as strong dependencies, resolving to **600** distinct
  library names, counting `/System` paths only. Including the 12 missing `/usr/lib` entries
  gives 647 and 612. The 35 difference is the same name requested at two paths, typically the
  normal path and the iOSSupport one.
- **Tier 1 (nothing binds them): 73 names.** Of these, 56 are plain frameworks a stub
  generator can emit; the remaining 17 are non-framework dylibs and iOSSupport paths.
- **Something binds them: 527 names.**

Of the 527 names that something binds, by the ABI of the symbols bound:

| Binds | Names |
|---|---|
| Only C / Objective-C | 307 |
| Only Swift | 134 |
| Both | 86 |

A framework binding even one Swift symbol needs real Swift ABI records, so for effort purposes
the mixed group belongs with tier 3: **307 potentially tractable, 220 not**.

By name, 307 of 527 are potentially tractable, roughly 58%. The imbalance is starker by
symbol: every pass measured put the Swift-mangled share of bound symbols near five sixths. No
figure is quoted for it here, because the passes disagree on absolute totals by more than 10%,
depending on slice handling and on which paths count as missing. The by-name table above is
what the tiering argument rests on; the by-symbol comparison is a direction, not a
measurement.

"Binds only C/ObjC" means tractable in principle, not generatable today: `darling-stub-gen`
shells out to `class-dump` to enumerate Objective-C classes, and `class-dump` is a macOS tool
with no Linux package. Obtaining or replacing it gates the whole 307.

Sample per-library demand, by bundle: `Combine` 30 bundles, `AppIntents` 28, `UIKit` 16.

## Method

Symbol-to-library attribution is exact rather than heuristic: the chained-fixups load command
records a `lib_ordinal` per imported symbol.

```sh
# Libraries a binary loads, and whether each load is weak.
llvm-objdump --macho --dylibs-used <binary>
llvm-objdump --macho --all-headers <binary>     # LC_LOAD_DYLIB vs LC_LOAD_WEAK_DYLIB

# Exact per-symbol attribution, with weak_import status.
# Pick the slice: arm64e on Apple Silicon, x86_64 otherwise.
# llvm-objdump --macho --universal-headers <binary> lists them.
llvm-objdump --macho --arch=arm64e --chained-fixups <binary>
```

For binaries without `LC_DYLD_CHAINED_FIXUPS` (older or Intel builds), the same ordinals are
in the bind opcodes: `llvm-objdump --macho --bind --lazy-bind <binary>`.

Count per slice. These bundles are fat (x86_64 plus arm64e) with equal import counts in
each, so tools that do not take an `--arch` report every symbol twice. `llvm-nm -u` without
`--arch` is the common way to double a count by accident.

Do not attribute symbols by matching a module name against the undefined-symbol list. That
works for Swift, whose mangling embeds the module name (`_$s<len><Module>`), but silently
misclassifies C and Objective-C symbols.

To see what a crashed guest was missing, read its core rather than relaunching. Darling cores
are recorded against `mldr`, with the guest command in the `Command Line:` field:

```sh
coredumpctl list /usr/local/libexec/darling/usr/libexec/darling/mldr
coredumpctl info <pid>                      # Command Line: names the guest app
coredumpctl dump <pid> --output=/tmp/x.core # write to a file, not stdout
strings /tmp/x.core | grep -A2 "Library not loaded"
```

## Not every abort is a missing framework

**Does the core carry a dyld payload?** A missing-library abort does, and it aborts on the
main thread (`TID` equals `PID` in `coredumpctl info`). A core with no `Library not loaded`
string, or whose `TID` differs from its `PID`, died elsewhere.

Measured example: `Terminal.app` aborted with SIGABRT and a 347MB core containing no
`Library not loaded` payload, on a secondary thread, with frames in the framework address
range rather than dyld's. It cleared dyld, loaded its frameworks, spawned threads, and aborted
inside framework code. No stub addresses that.

**Does the app have any missing strong dependencies?** Sixteen bundles had none in their main
executable:
Apps, Automator, Bluetooth File Exchange, ColorSync Utility, Dictionary, Digital Color Meter,
Grapher, Image Capture, Mission Control, Screenshot, Script Editor, Siri, Stickies, Terminal,
TextEdit, Time Machine. Darling's own `Darling Applications.app` also has none, and is left
out of the count as a non-Apple bundle. Whatever stops those is not a missing framework.

That list is main-executable-only. Embedded helpers and `.appex` plugins can have missing
dependencies of their own: `Screenshot.app` is clean in its executable but its
`ScreenshotControls.appex` is missing `AppIntents`, `SwiftUI` and `WidgetKit`.

That covers **direct** dependencies only. A present dependency may itself have missing
dependencies, so "zero missing direct" does not imply "will launch"; walk the closure
recursively if you need certainty. Beware of doing that with a tool that reports one header
line per slice for fat binaries: dropping only the first line leaves the second architecture
header to be parsed as a dependency, which manufactures missing entries for files that exist.

A third failure mode worth ruling out before blaming a framework: Darling reporting a page
size that does not match the host. A guest aligning `mmap` or `mprotect` to the value it is
given fails with `EINVAL`, often silently. Compare `sysctl hw.pagesize` inside the container
against `getconf PAGE_SIZE` outside it.

## What a stub does and does not buy

A stub gets `dyld` past one image. Where that is the only missing dependency, the app launches.
For Apple's own bundled applications it usually is not, because at least one remaining entry
is tier 3:

- **Calculator**: 29 strong dependencies, 12 missing. `TextInputUI`, the framework named in
  its abort, is tier 1 and binds nothing. The other eleven are tier 3, `SwiftUI` alone binding
  955 symbols. Stubbing `TextInputUI` changes the error message, not the outcome.
- **Chess**: 27 strong dependencies, 3 missing. GameKit is tier 2 and small (8 Objective-C
  classes), but `Combine` (8 Swift symbols) and `GroupActivities` (53) are tier 3. A GameKit
  stub gets Chess past GameKit and into `Combine`.

Describe stub work accordingly. "These stubs are well-formed and compile" is an honest claim;
"these stubs make the app launch" requires launching it. A stub that lets an app get further
before failing is useful and worth landing, as long as the PR says that is what it does and
names the next blocker.

## Catalyst apps are a separate problem

Some apps are Mac Catalyst and request frameworks under `/System/iOSSupport/...`. As measured
on 2026-09-20, several apparently-missing frameworks were already built and installed at the
normal path and "missing" only at the iOSSupport one, among them `AuthenticationServices`, `AVKit`,
`ContactsUI`, `MapKit`, `QuickLook`, `StoreKit`, `WebKit`, `AuthKitUI` and
`RecapPerformanceTesting`.

`add_framework()` accepts an `IOSSUPPORT` flag (`cmake/darling_framework.cmake`), but no call
site outside `src/external/` passes it, there is no UIKit in the tree, and a populated prefix
has no `/System/iOSSupport` directory. Catalyst apps need a UIKit substrate; stubs will not
reach them. Scope that work separately, and do not expect the path wiring alone to make a
Catalyst app launch: `Clock.app`'s executable has 24 missing strong dependencies, of
which `RecapPerformanceTesting` is one.

## Reusing existing open-source implementations

The unit of compatibility is a mangled symbol in a prebuilt Mach-O, not a source-level API.
Source-compatible reimplementations cannot satisfy a binary expecting Apple's exact mangled
symbols at Apple's install name, so they do not address tier 3:

- **OpenCombine**, **OpenSwiftUI**: active, but compile-time shims. They help only when you
  control the app's build, which for Apple's applications you do not.
- **Cocotron**: upstream `cocotron/cocotron` has been dormant for years. Darling's own fork is
  where the work happens and is actively developed.
- **GNUstep**: genuinely reusable beyond Foundation and AppKit, notably `libs-corebase`,
  `libs-quartzcore`, `libs-gscoredata` and `libs-opal`. Nothing for GameKit, EventKit,
  Security or SystemConfiguration.
- **apple-oss-distributions**: real source, but nothing above the kernel, runtime and crypto
  layer, and no private frameworks.
- **ravynOS**: integrates the same Cocotron and GNUstep pool rather than adding to it.
- **swift-corelibs-foundation**: the one case where building genuine upstream source beats
  reimplementing.

No open-source implementation exists for GameKit, `DeviceRegulatoryInfo`,
`CalendarUIKitInternal`, `TextInputUI` or `WeatherAnalytics`.

## Caveats

**Tier membership is a property of the measured binaries, not of the framework.** A tier-1
classification says that these binaries, at this build, bound nothing from that library. A
newer build of the same app can bind symbols and move it to tier 2 or 3 with no signal.
Re-measure rather than trusting the table, and date any stub justified by it.

**The aggregate counts are one pass, and a second pass disagreed slightly.** An independent
re-measurement over the same 66 bundles produced 72 tier-1 names against the 73 above, and a
correspondingly different ObjC-versus-Swift split. The
shape is robust across both passes, the exact figures are not. Treat them as indicative, and
re-derive rather than cite if a decision turns on the precise number.

**State the population and check it descends everywhere.** An earlier pass of this measurement
enumerated `/Applications/*.app` only and missed the 19 bundles under `/Applications/Utilities`.
Symbols bound by those apps went uncounted, which made two stubs unsafe until the population
was corrected. Counts of binaries and counts of bundles differ by roughly a factor of three
here, so label which one any figure is.
