# Imported macOS apps: installed-runtime baseline (2026-09-23)

This is a fresh static scan of 65 imported System app bundles plus AppZapper 3000 from the local ZIP. It checks each main executable’s direct arm64/arm64e loads and imports against the installed Darling tree and `~/.darling` overlay. It resolves embedded `@rpath` frameworks inside the app. It does not yet prove transitive loads, initialization, rendering, or usable workflows.

Reproduce with `tools/darling-applications/scan-imported-apps.py` after extracting `~/Downloads/AppZapper-3000.zip` into a temporary directory and setting `VIBEDARLING_EXTRA_APP` to its `.app` path. Set `VIBEDARLING_SCAN_OUTPUT` for full JSON and per-symbol detail. The installed root is `/usr/local/libexec/darling`.

## App ranking by direct bind gaps

This orders apps by absent or wrong-architecture direct libraries, then missing direct symbols. Runtime observations take precedence over this static estimate.

Practical launch-test priority is: (1) TextEdit, where Wayland connection is already observed; (2) the other 12 apps with zero direct gaps, beginning with Stickies, Terminal, and Automator; (3) Dictionary, whose three missing AppKit exports are a bounded implementation target; (4) Digital Color Meter and ColorSync Utility, which have no absent direct libraries but more graphics gaps. This is a likelihood estimate, not evidence that any untested app works. AppZapper remains a separate priority despite its larger dependency chain.

| App | Absent libraries | Wrong architecture | Missing symbols |
|---|---:|---:|---:|
| Apps | 0 | 0 | 0 |
| Automator | 0 | 0 | 0 |
| Bluetooth File Exchange | 0 | 0 | 0 |
| Grapher | 0 | 0 | 0 |
| Image Capture | 0 | 0 | 0 |
| Mission Control | 0 | 0 | 0 |
| Screenshot | 0 | 0 | 0 |
| Script Editor | 0 | 0 | 0 |
| Siri | 0 | 0 | 0 |
| Stickies | 0 | 0 | 0 |
| Terminal | 0 | 0 | 0 |
| TextEdit | 0 | 0 | 0 |
| Time Machine | 0 | 0 | 0 |
| Dictionary | 0 | 0 | 3 |
| Digital Color Meter | 0 | 0 | 18 |
| ColorSync Utility | 0 | 0 | 54 |
| Magnifier | 2 | 0 | 17 |
| AirPort Utility | 2 | 0 | 44 |
| Chess | 2 | 0 | 84 |
| Migration Assistant | 3 | 0 | 23 |
| Console | 3 | 0 | 32 |
| Audio MIDI Setup | 3 | 0 | 35 |
| Photo Booth | 3 | 0 | 88 |
| Boot Camp Assistant | 4 | 0 | 5 |
| Image Playground | 4 | 0 | 204 |
| iPhone Mirroring | 4 | 0 | 229 |
| Passwords | 4 | 0 | 231 |
| AppZapper 3000 | 2 | 2 | 512 |
| Font Book | 4 | 0 | 1442 |
| Activity Monitor | 6 | 0 | 25 |
| QuickTime Player | 7 | 0 | 193 |
| Disk Utility | 8 | 0 | 132 |
| Messages | 9 | 0 | 190 |
| System Information | 9 | 0 | 195 |
| Print Center | 9 | 0 | 680 |
| Screen Sharing | 11 | 0 | 577 |
| Games | 11 | 0 | 681 |
| Calculator | 11 | 0 | 1486 |
| Tips | 12 | 0 | 1213 |
| System Settings | 14 | 0 | 797 |
| Preview | 15 | 0 | 1079 |
| Shortcuts | 18 | 0 | 1497 |
| Contacts | 20 | 0 | 591 |
| VoiceOver Utility | 21 | 0 | 901 |
| Phone | 23 | 0 | 168 |
| Clock | 23 | 0 | 357 |
| Reminders | 24 | 0 | 5956 |
| TV | 26 | 0 | 781 |
| Home | 28 | 0 | 463 |
| App Store | 28 | 0 | 5502 |
| Calendar | 29 | 0 | 453 |
| Stocks | 29 | 0 | 841 |
| VoiceMemos | 32 | 4 | 1742 |
| Weather | 38 | 0 | 7763 |
| FindMy | 38 | 1 | 2253 |
| Podcasts | 40 | 0 | 3062 |
| Notes | 42 | 0 | 2365 |
| FaceTime | 43 | 0 | 702 |
| Mail | 44 | 0 | 2102 |
| Freeform | 45 | 1 | 3421 |
| Music | 45 | 2 | 1647 |
| Books | 49 | 1 | 498 |
| Photos | 53 | 0 | 2283 |
| Journal | 54 | 4 | 5366 |
| News | 61 | 0 | 474 |
| Maps | 76 | 1 | 4591 |

## Runtime observations in an isolated prefix

- Prefix: `/tmp/vd-runtime-20260923`, initialized from the current installed Darling runtime. Darling commands needed an unsandboxed invocation; the prefix was shut down after tests.
- AppZapper 3000 exits 134 in dyld: `/System/Library/Frameworks/Combine.framework/Versions/A/Combine` is the first missing library reported.
- Dictionary exits 134 in dyld: `_NSImageHintSymbolScale` is the first missing AppKit symbol reported. The direct scan also finds `_OBJC_CLASS_$_NSScrollEdgeEffectStyle` and `_OBJC_CLASS_$_NSSearchToolbarItem` missing.
- TextEdit connected to the Wayland backend and remained running until the timed launch probe ended. Its editing workflow was not exercised.

## AppZapper direct dependency detail

- Absent: `Combine.framework`, `SwiftUI.framework`.
- Present with no arm64/arm64e slice: `libswiftQuartzCore.dylib`, `libswiftSceneKit.dylib`.
- Embedded `Sparkle.framework` resolved from AppZapper’s own bundle; it is not an absent system dependency.
- 512 direct symbols remain unresolved in the static scan, including 466 nonweak SwiftUI imports. The scan cannot measure the transitive dependencies of absent Combine and SwiftUI libraries.
- CryptoKit, Symbols, and `libswift_errno.dylib` are currently present in the installed tree; earlier notes that list them as absent are stale for this machine.

### Disposable integration step: local Combine build

The arm64 `Combine.framework` binary from the local `darling-pr-combine-swift` branch (commit `23f1fff`) was staged into `/tmp/vd-runtime-20260923`, without changing the installed runtime. In that prefix AppZapper's 12 direct Combine imports resolved: the static missing-symbol count fell from 512 to 500. A fresh launch reached the next dyld failure, the absent `SwiftUI.framework`. This verifies binding and load order for Combine; it does not establish that AppZapper's Combine behavior works.

## Next checks

1. Launch the other 12 apps with zero direct bind gaps and exercise their core workflows in a combined integration prefix.
2. Inspect and implement the three Dictionary AppKit APIs in Cocotron, then rebuild AppKit and retest Dictionary in that prefix.
3. Build a genuine arm64 Combine implementation, continue the OpenSwiftUI/AttributeGraph dependency chain, and rescan AppZapper after each integration step.
4. Extend the scanner to walk indirect loads and report runtime results per app; the table above is a direct-bind estimate only.
