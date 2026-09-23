# Imported macOS apps: installed-runtime baseline (2026-09-23)

This is a fresh static scan of 65 imported System app bundles plus AppZapper 3000 from the local ZIP. It checks each main executable’s direct arm64/arm64e loads and imports against the installed Darling tree and `~/.darling` overlay. It resolves embedded `@rpath` frameworks inside the app. The table below does not include transitive loads, initialization, rendering, or usable workflows.

Reproduce with `tools/darling-applications/scan-imported-apps.py` after extracting `~/Downloads/AppZapper-3000.zip` into a temporary directory and setting `VIBEDARLING_EXTRA_APP` to its `.app` path. Set `VIBEDARLING_SCAN_OUTPUT` for full JSON and per-symbol detail. Set `VIBEDARLING_TRANSITIVE=1` to walk available dependency images. The installed root is `/usr/local/libexec/darling`.

## App ranking by direct bind gaps

This orders apps by absent or wrong-architecture direct libraries, then missing direct symbols. Runtime observations take precedence over this static estimate.

Practical workflow priority after the Dictionary AppKit rollout is: (1) TextEdit and Stickies, which reached the Wayland backend and stayed up during launch probes; (2) the nine other untested zero-gap apps; (3) Dictionary, which now binds but crashes during interface decoding; (4) Terminal and Automator, which reached Wayland but exposed concrete AppKit/Automator runtime gaps; (5) Digital Color Meter and ColorSync Utility, which have more graphics gaps. This is a likelihood estimate, not evidence that the apps' core workflows work. AppZapper remains a separate priority despite its larger dependency chain.

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
- Stickies connected to Wayland and remained running until the timed probe ended. Logs show fallback SF Symbol images, XPC errors, and unimplemented text attachment sizing/drawing; note editing and persistence were not exercised.
- Automator connected to Wayland, but startup logged missing `AMLibraryView` nibs and unimplemented Automator methods. Workflow creation and execution were not exercised.
- Terminal connected to Wayland, then exited 134 while decoding a nib: `NSPopover` lacks a working `initWithCoder:` and Foundation reported a forward-signature mismatch. Its shell workflow is not usable in this probe.

### Dictionary AppKit rollout after the baseline scan

The table above captures the pre-fix baseline. [Cocotron PR #138](https://github.com/VibeDarling/darling-cocotron/pull/138) adds Dictionary's three direct AppKit imports. The exact AppKit binary from the combined prefix was relinked with the PR's objects; all 3,473 previous exports were retained and 13 exports added. The new binary was staged into `/tmp/vd-runtime-20260923`, with the former binary saved as `/tmp/vd-dictionary-obj/AppKit-before-dictionary`. A fresh Dictionary scan against that prefix reports 0 missing libraries, 0 wrong-architecture libraries, and 0 missing direct symbols. A focused AppKit smoke executable exits 0 against the full relinked framework.

Dictionary now passes dyld and begins decoding its interface, then exits 139 before displaying a usable window. The host core record identifies the guest command line but does not symbolize the app-side failure. Dictionary is still not working; the next task is to locate and fix this runtime failure, then exercise search and definition display.

### TextEdit window check after the baseline probe

TextEdit opened a mapped XWayland window titled `Untitled 1 - TextEdit` in the combined prefix. A capture of that window showed the document, menu, and ruler UI. Automated focus and targeted typing did not produce visible text, so editing, saving, and reopening remain unverified. The guest was shut down after the probe. [App issue #162](https://github.com/VibeDarling/darling/issues/162) has the reproduction and next workflow check.

## AppZapper direct dependency detail

- Absent: `Combine.framework`, `SwiftUI.framework`.
- Present with no arm64/arm64e slice: `libswiftQuartzCore.dylib`, `libswiftSceneKit.dylib`.
- Embedded `Sparkle.framework` resolved from AppZapper’s own bundle; it is not an absent system dependency.
- 512 direct symbols remain unresolved in the static scan, including 466 nonweak SwiftUI imports. The scan cannot measure the transitive dependencies of absent Combine and SwiftUI libraries.
- CryptoKit, Symbols, and `libswift_errno.dylib` are currently present in the installed tree; earlier notes that list them as absent are stale for this machine.

### Disposable integration step: local Combine build

The arm64 `Combine.framework` binary from the local `darling-pr-combine-swift` branch (commit `23f1fff`) was staged into `/tmp/vd-runtime-20260923`, without changing the installed runtime. In that prefix AppZapper's 12 direct Combine imports resolved: the static missing-symbol count fell from 512 to 500. A fresh launch reached the next dyld failure, the absent `SwiftUI.framework`. This verifies binding and load order for Combine; it does not establish that AppZapper's Combine behavior works.

With Combine staged, the transitive scanner walked 132 available Mach-O images reachable from AppZapper and found no additional absent or wrong-architecture indirect loads among them. Dependencies of absent SwiftUI remain unknown until a real SwiftUI binary exists. The direct wrong-architecture Swift libraries remain blockers.

The current Cocotron source declares and implements five CALayer properties that OpenSwiftUI uses (`contentsScale`, `contentsCenter`, `contentsFormat`, `allowsEdgeAntialiasing`, and `isOpaque`), but the saved Darling SDK snapshot contains older QuartzCore headers. A Darwin Swift typecheck probe fails on all five with the snapshot and passes with a QuartzCore module generated from current Cocotron headers. [OpenSwiftUI fork PR #3](https://github.com/cristim/OpenSwiftUI/pull/3) lets the module generator use that current source. This clears a measured import gap; the full SwiftUI.framework build and AppZapper runtime remain open.

### SwiftUI dependency build after the baseline scan

- Current OpenAttributeGraph source produced arm64 macOS `OpenAttributeGraph` and `OpenAttributeGraphShims` Swift modules (26 and 9 Swift files). This is a module build, not a runtime validation.
- [Darling PR #812](https://github.com/VibeDarling/darling/pull/812) exports `Darwin.os.lock` to Swift. `import Observation` typechecks with the regenerated SDK.
- [Cocotron PR #139](https://github.com/VibeDarling/darling-cocotron/pull/139) adds `CTRunDelegate` lifetime and callback handling. Its guest runtime test passes with the relinked CoreText in the combined prefix. CoreText text layout metrics remain stubbed elsewhere.
- [Foundation PR #50](https://github.com/VibeDarling/darling-foundation/pull/50) defines `NS_SWIFT_SENDABLE`. Current Foundation source already declares `NSAttributedStringKey`; the older SDK snapshot omitted it. OpenSwiftUI PR #3 now permits current Foundation headers in the module overlay. The older snapshot also omitted a visionOS availability macro that current Darling source already has.
- The MIT-licensed OpenCoreGraphics source is forked at [cristim/OpenCoreGraphics](https://github.com/cristim/OpenCoreGraphics). Its `OpenCoreGraphicsShims` and `OpenQuartzCoreShims` modules compile for arm64 macOS against this SDK and framework overlay.
- The combined OpenSwiftUI typecheck now reaches a missing `CADisplayLink` declaration in Cocotron QuartzCore. An explicit `OPENSWIFTUI_NO_CADISPLAYLINK` probe flag can expose further compile gaps, but it does not replace the missing implementation.
- With that flag passed to Clang, typechecking next reached `OpenRenderBoxShims`. MIT-licensed [OpenRenderBox](https://github.com/cristim/OpenRenderBox) is now forked under `cristim`. [OpenRenderBox PR #30](https://github.com/OpenSwiftUIProject/OpenRenderBox/pull/30) uses the available `std::experimental::optional` with the older Darling libc++ headers. Both `OpenRenderBox` and `OpenRenderBoxShims` arm64 macOS Swift modules now compile, and its `ColorSpace.cpp` compiles to an arm64 object. A complete RenderBox runtime library has not been built or exercised.
- [Cocotron PR #140](https://github.com/VibeDarling/darling-cocotron/pull/140) adds named CoreGraphics color spaces and name ownership support needed by OpenRenderBox. Onyx2D and CoreGraphics were relinked in the combined prefix, retaining all prior exports and adding seven. The focused guest test exits 0. Onyx2D still represents these spaces with its RGB model; P3/PQ color conversion needs further work. OpenSwiftUI PR #3 now keeps OpenGL extension headers textual for C++ module imports.
- Current `swift-log` source, forked at [cristim/swift-log](https://github.com/cristim/swift-log), compiles an arm64 macOS `Logging` Swift module against Darling's Swift overlay. No fork code change was needed for that module build. The diagnostic typecheck selects `OPENSWIFTUI_SWIFT_LOG`; the module has not yet been linked into a SwiftUI runtime.
- OpenSwiftUI PR #3 now gates signpost imports and signpost-only code on the actual `os.signpost` Swift module, because Darling has an `os` C module without `os.signpost`. With that and `swift-log`, the diagnostic typecheck reached the missing `CTAdaptiveImageProviding` protocol. [Cocotron PR #141](https://github.com/VibeDarling/darling-cocotron/pull/141) declares that CoreText protocol; a combined local header overlay with PR #139 passes the previous Clang import failure.
- The temporary 881-source SwiftUI typecheck driver then reports many Swift source errors because it merges SwiftPM targets into one module and omits their dependency boundaries. A full package or target-by-target build is required before treating those errors as implementation gaps. The `OPENSWIFTUI_NO_CADISPLAYLINK` flag remains diagnostic only; QuartzCore still needs the real `CADisplayLink` API and behavior.
- The target-aware SwiftPM build now evaluates the actual package graph with local `OpenCoreGraphics`, `OpenAttributeGraph`, `OpenRenderBox`, `OpenObservation`, and `DarwinPrivateFrameworks` checkouts; the last two were forked to `cristim`. The cross toolchain initially rejected Apple's typed-allocation Clang flags. OpenSwiftUI PR #3 and [OpenAttributeGraph PR #242](https://github.com/OpenSwiftUIProject/OpenAttributeGraph/pull/242) now allow these flags to be disabled explicitly for cross builds, retaining the native default.
- The next build failure was a Clang 21 collision with Darling's SDK `stdatomic.h` include guard. [darling-xnu PR #21](https://github.com/VibeDarling/darling-xnu/pull/21) gives the SDK header a distinct guard; a focused arm64 macOS Clang atomic syntax probe passes with it. With that local SDK staging, `OpenSwiftUI_SPI` compiles past its TLS source and reaches a missing Foundation `NSAttributedString initWithFormat:options:locale:arguments:` declaration/implementation. [Darling issue #813](https://github.com/VibeDarling/darling/issues/813) has a contribution recipe. Attributed-string formatting must preserve formatting semantics; a plain-string substitute would not resolve the runtime requirement.
- [Cocotron PR #142](https://github.com/VibeDarling/darling-cocotron/pull/142) adds `CADisplayLink` with run-loop scheduling, callbacks, pause, rate selection, and invalidation. The arm64 QuartzCore dylib was relinked and staged into the combined prefix, retaining all 623 old exports and adding seven. A focused Darling guest test covering callback timing, pause/resume, removal, invalidation, and target release exits 0. Scheduling currently uses `NSTimer` at a nominal 60 Hz because Darling's CoreVideo display-link start/callback functions are stubs; it is not VBlank synchronized.
- A diagnostic declaration for the missing Foundation attributed-string initializer was added only to the temporary module overlay, so the target-aware build could reveal the next dependency. With the current QuartzCore header overlay, `OpenSwiftUI_SPI` advances to `CAFilter +filterWithType:`. Cocotron's CAFilter implementation is currently a forwarding stub and has no filter rendering path. [Darling issue #814](https://github.com/VibeDarling/darling/issues/814) records the observed call sites and a contributor workflow. The temporary declaration supplies neither the Foundation implementation nor a SwiftUI runtime.
- After a separate temporary CAFilter declaration, the target-aware build reached two missing Foundation selectors in `TimeIntervalProvider.m`. [Foundation PR #51](https://github.com/VibeDarling/darling-foundation/pull/51) implements `NSCalendar component:fromDate:` and `NSDateFormatter setLocalizedDateFormatFromTemplate:` using the existing components and locale-aware template paths. The relinked arm64 Foundation retains all 2,590 previous symbol names, is staged in the combined prefix, and passes a Darling guest test that extracts calendar components and renders `Jul 19, 2024`. The build now stops in `Localization.m` on missing `NSLocale.languageIdentifier` and unavailable `CFStringTokenizer` declarations through the CoreFoundation umbrella import. The CAFilter overlay remains diagnostic only.
- [Foundation PR #52](https://github.com/VibeDarling/darling-foundation/pull/52) adds `NSLocale.languageIdentifier` and strips locale keyword overrides before canonicalizing the language part. A focused guest test in the combined prefix verifies the documented `en_US@rg=gbzzzz` → `en-US` behavior, Chinese script canonicalization, and autoupdating locale behavior. The relinked Foundation includes both PR #51 and #52, retaining all 2,590 old exported symbol names. The required CoreFoundation source was forked under `cristim`; [darling-swift-corelibs-foundation PR #1](https://github.com/VibeDarling/darling-swift-corelibs-foundation/pull/1) exposes its existing `CFStringTokenizer` declarations through the umbrella header when available. OpenSwiftUI PR #3 also imports that header explicitly. A temporary CoreFoundation SDK module overlay incorporating PR #1 lets `Localization.m` compile. The next target-aware build failure is missing `NSDateFormatter.formattingContext` and `NSFormattingContextStandalone` in `DateProvider.m`; the SwiftUI runtime is still unbuilt.
- Foundation PR #51 now also implements `NSDateFormatter.formattingContext` by mapping the Foundation context values to ICU capitalization contexts through CoreFoundation's existing date-formatter property. The combined arm64 Foundation (PRs #51 and #52) retains all 2,590 previous exported symbol names. Its guest test verifies default/getter/copy behavior and actual French output: beginning-of-sentence `Juillet` versus middle-of-sentence `juillet`. The target-aware `OpenSwiftUI_SPI` build now passes `DateProvider.m` and stops on Cocotron's missing `CALayer insertSublayer:atIndex:` and AppKit `NSColor colorWithCGColor:` APIs. [QuartzCore issue #816](https://github.com/VibeDarling/darling/issues/816) and [AppKit issue #815](https://github.com/VibeDarling/darling/issues/815) give behavior and contribution recipes. The diagnostic Foundation attributed-string and CAFilter declarations remain unresolved implementations.
- [Cocotron PR #143](https://github.com/VibeDarling/darling-cocotron/pull/143) adds `NSColor colorWithCGColor:` using Cocotron's retained CGColor-backed color class. The relinked AppKit in the combined prefix keeps the earlier Dictionary fixes and all 3,972 old exported symbol names; a guest test confirms extended-sRGB and grayscale space models, components, alpha, and ownership after releasing the original CGColor. [Cocotron PR #144](https://github.com/VibeDarling/darling-cocotron/pull/144) adds indexed `CALayer` insertion and routes `addSublayer:` through it. The relinked QuartzCore keeps PR #142 and all 630 previous exported symbol names; a guest test covers same-parent moves, reparenting, removal, invalid input, and SwiftUI's end-index case. The target-aware build now passes both previous call sites and stops on `NSColor colorWithColorSpace:components:count:` and a dynamic UIKit-style `initWithRed:green:blue:alpha:` call in `OpenSwiftUICoreColor.m`. Those calls need investigation before deciding whether the missing API belongs in AppKit or an OpenSwiftUI portability shim.
- Cocotron PR #143 now also implements `NSColor colorWithColorSpace:components:count:` and its guest test covers extended-sRGB components, alpha, and invalid input. OpenSwiftUI fork PR #3 uses a typed, dynamically resolved UIKit image bridge on macOS rather than declaring UIImage selectors on NSObject. [Cocotron PR #145](https://github.com/VibeDarling/darling-cocotron/pull/145) implements `NSImage.alignmentRect`; its focused test passes in the combined Darling guest with the earlier Dictionary and color AppKit changes. With these staged headers, the target-aware `OpenSwiftUI_SPI` build compiles `OpenSwiftUICorePlatformImage.m` and reaches an undeclared `CGPathCreateWithRoundedRect` in `CGPath+OpenSwiftUI.m`. This is a compile milestone only. The diagnostic Foundation attributed-string and CAFilter declarations still need real behavior, and neither SwiftUI.framework nor AppZapper runs yet.
- [Cocotron PR #146](https://github.com/VibeDarling/darling-cocotron/pull/146) replaces the empty `CGPathAddRoundedRect` stub and adds `CGPathCreateWithRoundedRect`. A guest test verifies elliptical corner geometry, radius clamping, affine transforms, path closure, and append behavior. The relinked combined CoreGraphics retains all 649 previous exported names and adds the constructor. The target-aware `OpenSwiftUI_SPI` build now compiles `CGPath+OpenSwiftUI.m` and stops on missing `CALayer` mask, affine-transform, filter, and shadow selectors in `OpenSwiftUICoreViewFunctions.m`. [Darling issue #817](https://github.com/VibeDarling/darling/issues/817) identifies the rendering and ownership work and gives a contributor workflow. No SwiftUI runtime or AppZapper launch is claimed.
- [Cocotron PR #147](https://github.com/VibeDarling/darling-cocotron/pull/147) exposes `CALayer` affine transforms and makes `CARenderer` apply the stored 3D transform around the layer anchor. The combined arm64 QuartzCore retains every one of the 374 prior global defined names; its guest test passes affine/3D conversion cases. Rendered pixels have not yet been checked. The target-aware `OpenSwiftUI_SPI` build now passes `setAffineTransform:` but still needs real mask, filter, and shadow APIs. With temporary header declarations for those remaining APIs, `OpenSwiftUI_SPI` compiles as a target; this does not supply implementation or link a SwiftUI runtime. Building the deeper `OpenSwiftUI` target then reaches OpenAttributeGraph's hard-coded, empty `Checkouts/swift` source path. [OpenAttributeGraph PR #242](https://github.com/OpenSwiftUIProject/OpenAttributeGraph/pull/242) now makes it selectable through `OPENATTRIBUTEGRAPH_SWIFT_CHECKOUT_PATH`; pointing it at the local Swift 6.3.3 source clears the missing `swift/Runtime/Metadata.h` error. The full target next encounters host Swift standard-library selection and C++ `<optional>` header failures in this cross-build setup. The CoreFoundation overlay also needs `TARGET_OS_WASI=0` defined for this SDK; that macro was supplied only as a diagnostic build flag.
- [Darling PR #818](https://github.com/VibeDarling/darling/pull/818) defines `TARGET_OS_WASI=0` in the Darwin SDK header, clearing the previous CoreFoundation conditional error without a build flag. A local SwiftPM compiler wrapper now adds Darwin Swift overlay modules only to Darwin target invocations; a combined Swift resource directory exposes both macOS and Linux standard libraries. Separating the temporary libc++ shim from the C++ source include path and adding Swift's generated runtime header directory let OpenAttributeGraph C++ compile. [OpenAttributeGraph PR #243](https://github.com/OpenSwiftUIProject/OpenAttributeGraph/pull/243) replaces one `std::countr_zero` call with the equivalent trailing-zero builtin for Darling's older libc++. OpenAttributeGraph and its shims now produce arm64 macOS Swift modules. The existing `OPENATTRIBUTEGRAPH_DARLING` diagnostic define still omits `archiveJSON`, because Darling's Foundation overlay lacks the required JSON/NSDictionary bridge.
- The OpenSwiftUI fork PR #3 now allows a local `OpenCombine` checkout and declares only the required C function in `DisplayLink.c`, avoiding a QuartzCore Objective-C umbrella import from C. The target-aware `OpenSwiftUI` build produces arm64 macOS `OpenCombine` and `Logging` Swift modules, then stops in `OpenCombineFoundation`. Its missing `NotificationCenter`, `OperationQueue`, URL types, and CFRunLoop bridge errors are recorded in [Darling issue #819](https://github.com/VibeDarling/darling/issues/819). The module build does not make an Apple ABI-compatible Combine.framework for AppZapper. The diagnostic build still uses temporary CALayer declarations and other noted overlays; SwiftUI.framework and AppZapper remain unbuilt and unlaunched.
- The combined local guest prefix was moved to `/home/cristi/src/.tmp-vd-runtime-20260923` because `/tmp` filled during SwiftPM compilation. `/tmp/vd-runtime-20260923` remains a symlink for existing build inputs, but `darling shell` must use `DPREFIX=/home/cristi/src/.tmp-vd-runtime-20260923`; a rounded-path guest test passes at that real path. The SwiftPM build directory likewise moved to `/home/cristi/src/.tmp-vd-swiftui-swiftpm-build`, with its old `/tmp` path retained as a symlink.
- `tools/darling-applications/build-openswiftui-diagnostic.sh` records the target-aware SwiftPM command and invokes `swiftc-platform-wrapper.sh` to supply Darling Swift modules only to Darwin targets. It requires the prepared SDK and framework-header overlays, local OSS dependency checkouts, and the `../OpenCombine` checkout (a symlink to the `cristim` fork here). At this stage its build still reached missing `OperationQueue`/notification/URL APIs. The script retains the diagnostic `OPENATTRIBUTEGRAPH_DARLING` define and does not validate a linked SwiftUI runtime.
- Foundation PRs [#53](https://github.com/VibeDarling/darling-foundation/pull/53), [#54](https://github.com/VibeDarling/darling-foundation/pull/54), [#55](https://github.com/VibeDarling/darling-foundation/pull/55), and [#56](https://github.com/VibeDarling/darling-foundation/pull/56) supply the measured Swift class names, borrowed run-loop ownership, notification bridge, operation API, and `NSURLRequest` Swift bridge. These are committed in the local Foundation integration branch. Draft [darling-swift PR #52](https://github.com/VibeDarling/darling-swift/pull/52) adapts the open source `URLRequest` and `URLError` value types. The **full current arm64 Foundation Swift overlay** builds and links, retaining all 2,656 prior arm64 exports while providing 5,088 exports. Its guest test passes method/header copy-on-write, Objective-C round-trip, and URL error code/domain in both isolated and combined prefixes. A focused `URLSession.dataTask(with: URLRequest)` arm64 probe typechecks, but an actual guest URLSession request remains untested. [Darling issue #831](https://github.com/VibeDarling/darling/issues/831) tracks source evidence that CFNetwork's request copy drops other fields.
- Draft [darling-swift PR #53](https://github.com/VibeDarling/darling-swift/pull/53) adds Swift CoreGraphics geometry, transform, color, image, path, and context members. The full arm64 CoreGraphics overlay builds and links, retaining all three prior arm64 exports and providing 124 exports. Its focused geometry test exits zero in the combined guest prefix. The integration branch combines both new Swift overlays as dual-architecture dylibs and source. The target-aware OpenSwiftUI build now completes `OpenCombineFoundation` and reaches `OpenSwiftUICore`; it exposes further Foundation, CoreText, IOSurface, attributed-string, and OpenSwiftUI portability gaps. This is a compilation milestone. Neither an Apple ABI-compatible `SwiftUI.framework` nor AppZapper's runtime is available yet.

## Next checks

1. Exercise TextEdit and Stickies core workflows, then launch the nine still-untested zero-gap apps in a combined integration prefix.
2. Diagnose Dictionary's interface-decoding crash with the new AppKit, fix it, then test search and definition display.
3. Test a real guest URLSession request, address the measured `OpenSwiftUICore` import and API gaps, then continue toward genuine arm64 Combine and SwiftUI runtimes. Rescan AppZapper after each integration step.
4. Run the indirect-load scanner and runtime probes for every app; the table above is a direct-bind estimate only.
