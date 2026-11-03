#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
: "${OUT:?}" "${DARLING_SOURCE:?}" "${SWIFT_TOOLCHAIN:?}" "${SWIFT_CORE_MODULES:?}" "${SWIFT_SHIMS:?}" "${SWIFT_APINOTES:?}" "${IOS_SDK:?}"
mkdir -p "$OUT/resource"
ln -sfn "$SWIFT_TOOLCHAIN/lib/swift/clang" "$OUT/resource/clang"
ln -sfn "$SWIFT_SHIMS" "$OUT/resource/shims"
ln -sfn "$SWIFT_APINOTES" "$OUT/resource/apinotes"
"$SWIFT_TOOLCHAIN/bin/swiftc" -frontend -c "$here/Probe.swift" -parse-as-library \
    -target arm64-apple-ios16.0 -sdk "$IOS_SDK" -resource-dir "$OUT/resource" \
    -module-cache-path "$OUT/module-cache" -I "$SWIFT_CORE_MODULES" \
    -swift-version 5 -Onone -module-name EnvironmentValuesProbe \
    -runtime-compatibility-version none -disable-autolinking-runtime-compatibility \
    -disable-implicit-concurrency-module-import -disable-implicit-string-processing-module-import -o "$OUT/Probe.o"
clang -c -target arm64-apple-ios16.0 -isysroot "$IOS_SDK" -fobjc-exceptions "$here/main.m" -o "$OUT/main.o"
clang -c -target arm64-apple-ios16.0 -isysroot "$IOS_SDK" "$DARLING_SOURCE/src/frameworks/SwiftUI/backend/os_version_check.c" -o "$OUT/availability.o"
ld64.lld -arch arm64 -platform_version ios 16.0 16.5 -syslibroot "$IOS_SDK" -ignore_auto_link \
    -no_fixup_chains -rpath /usr/lib/swift -o "$OUT/ENVIRONMENT_VALUES_PROBE" \
    "$OUT/Probe.o" "$OUT/main.o" "$OUT/availability.o" -L "$IOS_SDK/usr/lib/swift" \
    -lswiftCore -lswiftObjectiveC -lswiftDarwin -lswiftCoreFoundation -lswiftDispatch \
    -lswiftos -lswiftUniformTypeIdentifiers -lswiftUIKit -lswiftCoreImage -lswiftMetal -lswiftQuartzCore -lswiftFileProvider -lswiftDataDetection -lswiftOSLog -framework Foundation -framework CoreData -framework SwiftUI -framework Combine -framework UIKit -lobjc -lSystem
