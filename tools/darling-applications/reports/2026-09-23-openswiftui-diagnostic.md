# OpenSwiftUI diagnostic build, 2026-09-23

The `OpenSwiftUI` SwiftPM target has five first-party targets in its dependency
chain: `OpenSwiftUI_SPI`, `OpenSwiftUIMacros`, `OpenSwiftUICore`, `COpenSwiftUI`,
and `OpenSwiftUI`. SwiftPM's `[n/m]` counter counts incremental build actions,
not modules or completion percentage.

## Current result

The arm64 Darwin diagnostic build passes its C/Objective-C `OpenSwiftUI_SPI`
sources and enters `OpenSwiftUICore` Swift compilation. It fails there. With
the current Swift overlay modules and CoreText descriptor declarations, the
latest run reported 625 distinct file/line/message diagnostics across 64
OpenSwiftUICore source files. The earlier run reported 652 across 64 files;
the inputs differ, so the difference cannot be attributed solely to one fix.
Many diagnostics are follow-on errors, not independent fixes. The latest log
is `/tmp/vd-openswiftui-after-ctfont-features.log` on the build machine.

Representative primary gaps include Foundation `Date.ComponentsFormatStyle`
and `Duration.UnitsFormatStyle`, Swift Foundation API import mismatches such as
`NSString(cString:encoding:)`, graphics types such as `IOSurface`, CoreText
symbols such as `CTFontStylisticClass`, and layer APIs such
as `cornerCurve`.

Two temporary declarations in `/tmp/vd-swiftui-modules` are diagnostic only:
`CAFilter +filterWithType:` and `NSAttributedString
initWithFormat:options:locale:arguments:`. Neither has a runtime implementation.
`CALayer` now retains mask, filter, and shadow state, but `CARenderer` does not
yet apply them when drawing. A successful diagnostic compile would therefore
still need runtime and rendering verification.

CoreText now exposes `CTFontDescriptorCreateCopyWithSymbolicTraits`,
`CTFontDescriptorGetSymbolicTraits`, and the trait dictionary keys. Its masked
trait update passed a focused guest test, and a Swift probe imported the new
declarations. The local Cocotron commit is `ec9e3023`, pinned by the Darling
integration commit `edb9a523f`. Those missing-name diagnostics are absent in
the latest OpenSwiftUI run. Descriptor feature and variation copies also pass
the focused guest test and import from Swift; `b4e43132` is pinned by
`f0975104c`. The diagnostic count fell from 629 to 625 after those two APIs.
Its largest remaining compile cluster is
Foundation date and duration format styles. The diagnostic build script now
selects the current integration overlays by default; the older minimal overlay
gave thousands of unrelated missing geometry and Foundation names when the
SwiftPM cache invalidated.

No usable `SwiftUI.framework` has been produced, and AppZapper has not launched.

## AppZapper rescan in the disposable prefix

The AppZapper 3000 bundle from the local ZIP was scanned against
`/home/cristi/src/.tmp-vd-runtime-20260923` after staging the existing
dual-architecture `libswiftQuartzCore` and `libswiftSceneKit` builds from
`darling-swift-swiftui-integration`. The direct scan now reports one absent
library (`SwiftUI.framework`) and zero wrong-architecture libraries. With
the new CoreGraphics system colors, AppKit `NSApplicationMain`, Foundation
URL resource and path APIs, and `StringProtocol.data(using:)` staged, it
reports 473 unresolved symbols: SwiftUI (466), Foundation (4), AppKit (1),
UniformTypeIdentifiers (1), and ServiceManagement
(1). Three additional absent libraries are weak loads. The current result is
saved in `/tmp/vd-appzapper-scan/results-string-protocol` on the build machine.
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
`9f2a318`. Foundation URL path standardization and symlink resolution passed
a focused guest test (`e3b8cd7`), as did `StringProtocol.data(using:)` for
`String` and `Substring` with UTF-8 and Latin-1 (`749139a`).

The four remaining non-SwiftUI Foundation imports are three `Decimal` APIs
(integer literal, division, and `isZero`) and generic `Numeric.formatted()`.
Darling's current `NSDecimalDivide` falls back to binary floating point for
most divisors, so exposing Swift's `Decimal` division without improving that
backend would risk incorrect monetary results. The UniformTypeIdentifiers
Swift overlay is also currently built from placeholder values; adding only
`UTType.folder` there would not make the type system functional.

The build is reproducible with `tools/darling-applications/build-openswiftui-diagnostic.sh`
after generating the local framework modules described in that script. The
diagnostic uses local overlays and switches off some private framework links;
it is not an AppZapper launch test.
