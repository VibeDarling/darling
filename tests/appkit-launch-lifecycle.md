# AppKit launch lifecycle prerequisite

An authored public AppKit baseline probe for UIApplication startup planning.
It exercises an existing NSApplication, not UIApplication or Messages, and
establishes no private FTServices/ChatKit/iMessage contract.

## Scope and evidence

Own only this fixture and recipe. No AppKit/UIKit/Security implementation changes.
The public delegate callbacks must arrive in will-launch/did-launch order, with
the application as notification object. The did-launch callback creates and
orders one synthetic NSWindow. Its view paints one opaque cyan 64-by-64 square
on white, using the actual AppKit graphics port and save/restore state. A 30-second authored NSTimer checks that the main
run loop delivered both callbacks, then requests normal application termination.
The same delegate identity is checked during launch, drawing and timer dispatch.
The delegate returns NSTerminateNow and checks the will-terminate notification.
Checks set an explicit failure flag and print diagnostics; the timer/termination
path exits nonzero on failure, so AppKit catching callback exceptions cannot
turn a failed assertion into a PASS. Missing drawing also fails at the timer.
The interval and window geometry are test inputs, not compatibility defaults.

Provenance: rung 2, Cocotron AppKit/include/AppKit/NSApplication.h and NSWindow.h,
and AppKit/NSApplication.m run/finishLaunching/registerDelegate/terminate paths;
rung 3, Apple's public [run](https://developer.apple.com/documentation/appkit/nsapplication/run()),
[will-launch](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationwillfinishlaunching(_:)),
[did-launch](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationdidfinishlaunching(_:))
and [terminate](https://developer.apple.com/documentation/appkit/nsapplication/terminate(_:))
contracts. Public signatures come from the vendored headers, not inferred ABI.

The fixture reuses the synthetic window/no-document-arguments/timer/native-proof
approach of the existing `UIKit/tests/graphics-context-window.m` and its recipe.
It adds delegate lifecycle assertions and does not duplicate that fixture's
context bridge, painter or pixel checks. Run both if graphics proof is needed;
lifecycle success alone does not prove native pixels or UIKit UI startup.

## Build and run gate

Verified on 2026-10-08: serial compile/link and the isolated native guest run
exited 0. See the measured baseline below.
The full-runtime heavy-build queue takes priority. Wait for a coordinator-granted
focused slot before compiling; hold the shared heavy-build flock for every
compile/link, at most two jobs. Compile as Objective-C with Darling's pinned
headers and blocks support, linking existing AppKit/Foundation/objc/system.
Use no positional arguments (AppKit may consume them as document input).

Commit source provenance before staging any executable. Use the immutable
runtime and a new private DPREFIX; bootstrap `darling shell true` and replace
its generated host-home symlinks with empty directories. Stage the committed
fixture under physical `opt/appkit-probes` rather than host-mapped guest tmp.

Reuse the existing graphics-context-window recipe's owned headless Sway setup:
headless/pixman, a short task-local XDG_RUNTIME_DIR, Xwayland disabled and an
independent WAYLAND_DISPLAY. Set DARLING_APPKIT_BACKEND=wayland and run:

```
darling shell /opt/appkit-probes/appkit-launch-lifecycle
```

Before the timer expires, capture only the owned compositor's get_tree and
require a native xdg_shell surface titled `AppKit synthetic launch lifecycle`,
with no X11 window ID. Capture HEADLESS-1 with grim at scale 1, using the
existing graphics-context-window pixel-measurement approach: require exactly
4096 opaque cyan (RGB 0,255,255) pixels forming a contiguous 64-by-64 square.
Placement depends on the compositor and is not a fixed screen coordinate.
Capture only the isolated synthetic output. AppKit isVisible, draw logs and
callback logs are not surface/pixel proof. Record compositor focus separately;
do not infer activation from allocation/order or treat a UIKit NO launch result
as a general startup failure. The fixture uses no UIKit launch result.
Require fixture exit 0 and the final PASS line plus callback/timer sequence.
Record exact source/runtime/dependency pins, commands, log/tree and exit status
in private scratch evidence; do not commit built artifacts or screenshots.

The timer bounds a responsive application run, not a stopped event loop. If
it fails to complete, report that separately and stop only this prefix with
`darling shutdown`; never use timeout to signal the launcher/container. Exit
only the owned compositor through its IPC socket. Do not read host user data
or sign in, register a device or access accounts/keychains/services.

## Startup/responder boundary

ChatKit owns the bounded NSObject-based UIResponder prerequisite: base
nextResponder nil, eligibility defaults, and canPerformAction traversal through
actual subclass nextResponder overrides. UIKit owns its build/umbrella wiring.
This AppKit fixture neither constructs that chain nor implements focus or dispatch.
AppKit become/resign first-responder callbacks do not establish UIKit's
become/resign request behavior. Window attachment, per-window focus, target
selection and action dispatch remain deferred to coordinated public UIKit owners.
Callback ordering here is AppKit evidence only; the UIApplication startup planner
must establish its own public lifecycle mapping before using it.

## Measured baseline

The unchanged fixture from commit `cd9e871ad` compiled and linked under a
coordinator-granted, nonblocking shared-lock slot; standalone exit 0, with both
START and RELEASE at 2026-10-08T10:30:54Z. The executable SHA256 was
`a058c40a2dfb347ed13d3e0c92699963e895b1162c44cea3dcc0b1c7fcdb0074`.
Header inputs were independent copies pinned to Foundation `9ec86fda`,
Cocotron `ec245a01` and CoreFoundation `bceef4f7`; their transitive closure
was recorded before compilation. No mutable donor objects were used.

The first run used runtime snapshot `runtime-display-link-e68d60cb` (Darling
`6b11337e`, Cocotron `17d49dec`) and a new sanitized private prefix; bootstrap
and the guest command exited 0.

The fixture was re-validated on 2026-10-08 after rebasing onto master
`a8f3d4c7c`, against the rebuilt runtime image whose AppKit, Foundation and
CoreGraphics SHA256 values were `9c697a84`, `bd5d35d1` and `5fd1eed9`
(prefixes). A clean recompile under the shared lock produced a byte-identical
object (`c9ff221a`) and executable (`a058c40a`). A fresh private prefix,
bootstrapped with a non-setuid copy of that image's launcher, ran the guest in
the background while the compositor tree and screenshot were captured, then
the guest exited 0. The guest printed will-launch, did-launch, two draws,
timer, should-terminate and final PASS; no assertion failure was recorded.
The tree and screenshot must be captured while the guest runs: the window is
gone once the 30-second timer ends the application.

Owned headless Sway reported one matching `xdg_shell` surface, no X11 window
ID, and native focus. Its 640-by-480 scale-1 output contained exactly 4096
cyan pixels with bounds (220,180)-(284,244), a complete 64-by-64 square.
Pixel measurement reused the existing graphics-context-window checker approach.
Prefix shutdown exited 0 and the owned compositor was exited through its IPC socket. Logs, command/artifact hashes, tree and screenshot remain private
scratch evidence, outside source control.

This verifies the public AppKit baseline on that snapshot. It establishes no
UIKit lifecycle mapping, responder dispatch, private entitlement contract or
readiness of another runtime. No framework defect or source patch was needed.
