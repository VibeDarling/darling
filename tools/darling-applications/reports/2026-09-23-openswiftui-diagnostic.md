# OpenSwiftUI diagnostic build, 2026-09-23

The `OpenSwiftUI` SwiftPM target has five first-party targets in its dependency
chain: `OpenSwiftUI_SPI`, `OpenSwiftUIMacros`, `OpenSwiftUICore`, `COpenSwiftUI`,
and `OpenSwiftUI`. SwiftPM's `[n/m]` counter counts incremental build actions,
not modules or completion percentage.

## Current result

The arm64 Darwin diagnostic build passes its C/Objective-C `OpenSwiftUI_SPI`
sources and enters `OpenSwiftUICore` Swift compilation. It fails there. The
2026-09-23 run reported 652 distinct file/line/message diagnostics across 64
OpenSwiftUICore source files (16,704 repeated error lines from parallel Swift
frontend jobs). Many are follow-on diagnostics, so this is not a count of 652
independent fixes.

Representative primary gaps include Foundation `Date.ComponentsFormatStyle`
and `Duration.UnitsFormatStyle`, Swift Foundation API import mismatches such as
`NSString(cString:encoding:)`, graphics types such as `IOSurface`, CoreText
symbols such as `CTFontDescriptorCreateCopyWithSymbolicTraits`, and layer APIs
such as `cornerCurve`. The full diagnostic log is
`/tmp/vd-openswiftui-after-attributed-nullability.log` on the build machine.

Two temporary declarations in `/tmp/vd-swiftui-modules` are diagnostic only:
`CAFilter +filterWithType:` and `NSAttributedString
initWithFormat:options:locale:arguments:`. Neither has a runtime implementation.
`CALayer` now retains mask, filter, and shadow state, but `CARenderer` does not
yet apply them when drawing. A successful diagnostic compile would therefore
still need runtime and rendering verification.

No usable `SwiftUI.framework` has been produced, and AppZapper has not launched.

## AppZapper rescan in the disposable prefix

The AppZapper 3000 bundle from the local ZIP was scanned against
`/home/cristi/src/.tmp-vd-runtime-20260923` after staging the existing
dual-architecture `libswiftQuartzCore` and `libswiftSceneKit` builds from
`darling-swift-swiftui-integration`. The direct scan now reports one absent
library (`SwiftUI.framework`) and zero wrong-architecture libraries. With
the new CoreGraphics system colors, AppKit `NSApplicationMain`, and Foundation
URL resource getters staged, it reports 476 unresolved symbols: SwiftUI (466),
Foundation (7), AppKit (1), UniformTypeIdentifiers (1), and ServiceManagement
(1). Three additional absent libraries are weak loads. The current result is
saved in `/tmp/vd-appzapper-scan/results-url-values` on the build machine.
The original x86-only Swift libraries were backed up in that prefix with
`.before-arm64` suffixes.

A fresh launch in this prefix still exits 134 in dyld because
`/System/Library/Frameworks/SwiftUI.framework/Versions/A/SwiftUI` is absent.
This confirms the next load blocker after Combine and the two Swift support
libraries; the scanner cannot inspect transitive loads of missing SwiftUI.

## Local integration verified

The `darling-image-master` integration branch pins Cocotron, Foundation, and
CoreFoundation fixes. `ninja CoreText`, `ninja AppKit`, `ninja QuartzCore`, and
`ninja CoreGraphics` succeeded in the local arm64 build. Focused tests passed
inside a disposable Darling guest prefix for `CTGlyphInfo`, `NSImage`
alignment rectangles, `NSColor` creation from a CGColor and components,
`CALayer` affine transforms and appearance state, and rounded CoreGraphics
paths. These tests cover the named APIs, not full SwiftUI behavior.
The Swift Foundation URL resource test passes in the disposable guest for a
regular file, directory, and symbolic link, including size and unrequested
values. This required CoreFoundation to return `NSURLFileSizeKey` and the Swift
overlay to convert the returned `NSNumber` booleans. The local commits are
`42f9f46` (Swift overlay), `1843067` (CoreFoundation), and `264c51102`
(parent pin). The CoreGraphics and AppKit overlay commits are `30c3eff` and
`9f2a318`.

The build is reproducible with `tools/darling-applications/build-openswiftui-diagnostic.sh`
after generating the local framework modules described in that script. The
diagnostic uses local overlays and switches off some private framework links;
it is not an AppZapper launch test.
