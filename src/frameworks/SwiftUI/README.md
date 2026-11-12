# SwiftUI (Darling)

A small SwiftUI written for Darling: module `SwiftUI`, installed as
`/System/iOSSupport/System/Library/Frameworks/SwiftUI.framework` (arm64, iOS
apps). It is **source-compatible** with a subset of Apple's SwiftUI and draws
with Darling's UIKit. It contains no Apple code and is not ABI-compatible
with Apple's SwiftUI: apps are compiled from source against this module.
Apple's SwiftUI binary is not used.

## Layout

- `Sources/*.swift`: the API (`App`, `Scene`, `WindowGroup`, `View`,
  `@ViewBuilder`, `@State`, `@Binding`, views and modifiers) and the
  renderer (`Render.swift`).
- `backend/`: a C interface (`SwiftUIBackend.h`, Clang module
  `SwiftUIBackend`, imported `internal`ly) implemented in Objective-C on
  UIKit (`SwiftUIBackend.m`). The Swift side needs neither Foundation nor
  UIKit's Swift overlays, which have no arm64 builds in `src/external/swift`.
- `backend/os_version_check.c`: the runtime of `#available`, which Apple's
  clang links statically from `libclang_rt`; each Swift binary links a copy
  (see `cmake/swift_ios.cmake`).
- `src/HelloSwiftUI`: a "Hello, world" app built against it
  (`/Applications/HelloSwiftUI.app`).

## How it works

Each update resolves the view tree from the root: primitive views make
`Node`s, composite views get their `@State` linked to boxes kept by tree
position (`Renderer.bindDynamicProperties`, via `Mirror`) and resolve their
`body`. The new nodes take over the UIViews of the previous tree's nodes of
the same kind at the same place (labels, plain views, a tap control per
button), then are laid out SwiftUI-style (proposed sizes, stacks dividing
space by flexibility) in the host view's safe area, root centered. A
`@State` write schedules one update on the main queue.

## Supported

`App` with `@main`, `WindowGroup`; `Text` (string, interpolation,
`.font`, `.bold`, `.italic`, `.foregroundColor`, `+`), `VStack`/`HStack`
(alignment, spacing), `ZStack`, `Spacer`, `Divider`, `Button` (title or
label view), `Color` (system colors, `Color(red:green:blue:)`, `.opacity`),
`EmptyView`, `AnyView`, `Group`, `ForEach` (ranges, `id:` key paths,
`Identifiable`), `if`/`else`/`if let` in builders; modifiers `.padding`,
`.frame(width:height:)`, `.frame(minWidth:maxWidth:...)`, `.background`,
`.overlay`, `.opacity`, `.font`, `.foregroundColor`/`.foregroundStyle`,
`.tint`, `.multilineTextAlignment`, `.lineLimit`, `.onAppear`, custom
`ViewModifier`s; `@State`, `@Binding`, `Binding(get:set:)`, `.constant`.

Not implemented: `Image`, `TextField`, `Toggle`, `List`, `NavigationView`,
`ScrollView`, `ObservableObject`/`@ObservedObject`/`@StateObject`
(they need Combine), `@Environment`, animations, gestures, `Shape`s,
`.ignoresSafeArea`, dark mode.

## Building

CMake drives a host `swiftc` (cmake/swift_ios.cmake). Configure the arm64
build with:

```sh
cmake build-arm64 \
  -DDARLING_SWIFT_TOOLCHAIN=<swift-6.3.3-RELEASE-ubuntu24.04>/usr \
  -DDARLING_SWIFT_IOS_STDLIB=<dir with Swift.swiftmodule for arm64-apple-ios> \
  [-DDARLING_SWIFT_HOST_LIBS=<dir with libncurses.so.6, if the host lacks it>]
ninja -C build-arm64 HelloSwiftUI
DESTDIR=<dest> cmake -P build-arm64/src/frameworks/SwiftUI/cmake_install.cmake
DESTDIR=<dest> cmake -P build-arm64/src/HelloSwiftUI/cmake_install.cmake
DESTDIR=<dest> cmake -P build-arm64/src/external/swift/cmake_install.cmake
```

Without the two variables both targets are skipped. The runtime they need
is `libswiftCore.dylib` from `src/external/swift`, a Git LFS file there
(`git lfs pull` in that submodule; a 133-byte pointer file means it was not
fetched).

`DARLING_SWIFT_IOS_STDLIB`: the Swift 6.3.3 Linux toolchain has no Apple
standard library module, and the macOS one in `swift-6.3.3-RELEASE-osx.pkg`
is built for `arm64-apple-macos`, not for the iOS target used here.
The module used here was built from the swift-6.3.3-RELEASE sources'
`Runtimes/Core` for `arm64-apple-ios` (its `Swift.swiftmodule` directory,
with `arm64-apple-ios.swiftmodule`). Its `.swiftinterface` can be compiled
into a module with `swiftc -frontend -compile-module-from-interface`.

The installed framework includes `Modules/SwiftUI.swiftmodule`
(`arm64-apple-ios.swiftmodule` and `.swiftinterface`), so apps can be built
against an installed tree with the flags in `cmake/swift_ios.cmake` plus
`-I <framework>/Modules`, linked against the framework and
`/usr/lib/swift/libswiftCore.dylib`, and marked as iOS with
`src/Terminal/set-ios-platform.py`.

## CPU requirement (the runtime, not this module)

When clang is given no `-mcpu` for `arm64-apple-macosx`, it targets `apple-m1`, a CPU with the
Armv8.1-A LSE atomics and the RCpc loads. An Armv8.0-A core such as the Raspberry Pi 4's
Cortex-A72 implements neither, which `clang --print-enabled-extensions` shows for each CPU.
Unmodified Swift programs died with `SIGILL` on a Cortex-A72 under Darling.

`src/external/swift/runtime/build.sh` rebuilds the arm64 Swift runtime libraries from Swift's open
source with `-mcpu=apple-a7` (Armv8.0-A) and `-moutline-atomics`. Each atomic operation then
calls one of compiler-rt's helpers, which uses LSE only when the CPU has it. With those libraries
the same programs run.

This module is built for `arm64-apple-ios`, and for that triple clang's default CPU is already
`apple-a7` (`clang -target arm64-apple-ios16.0 -### -c x.c`). swiftc takes its target CPU from its
Clang importer, so this module needs no flag of its own. The runtime it links is what matters.
`src/external/swift/runtime/README.md` has the details, including the one runtime library the
script does not rebuild yet (`libswiftRuntime`).

## Debugging

`DARLING_SWIFTUI_DEBUG=1` logs every frame the renderer sets, in window
coordinates (points).
