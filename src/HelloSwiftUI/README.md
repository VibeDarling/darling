# Hello World SDK client

`HelloApp.swift` is shared by two builds. The CMake `HelloSwiftUI` target uses
Darling's original source-compatible SwiftUI module. `build-sdk.sh` instead
compiles against the iOS SDK interface and emits a separate **Hello World** app,
`org.darlinghq.hello-world-sdk`. Its IPA tests the same SwiftUI binary interface
that ordinary SDK-built apps import; it does not bundle a SwiftUI implementation.

```sh
flock -w 1800 /tmp/agent-locks/darling-heavy-build.lock \
  src/HelloSwiftUI/build-sdk.sh /path/to/output
python3 src/HelloSwiftUI/check-abi.py \
  /path/to/output/Payload/HelloWorld.app/HelloWorld \
  /path/to/darling-built/SwiftUI.framework/SwiftUI
```

The toolchain variables match `src/frameworks/SwiftUI/abi/build.sh`. No Darling
SwiftUI module directory is passed to the demo compiler. The ABI framework builder
also emits this IPA and checks its SwiftUI imports before reporting success.
Install `HelloWorld.ipa` through Darling Pocket's IPA installer. The app displays
“Hello, world!”, a counter and a button that increments it.

Import coverage detects the old custom-module mismatch but does not prove runtime
behavior. Rendering and button/state behavior must also be exercised under Darling.
