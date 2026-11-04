#!/usr/bin/env bash
# Build iOS-only Swift modules from authored source against the public iOS SDK's
# interfaces, so their mangled names are the ones apps bind.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
: "${OUT:?}" "${SWIFT_TOOLCHAIN:?}" "${SWIFT_CORE_MODULES:?}" "${SWIFT_SHIMS:?}" "${SWIFT_APINOTES:?}" "${IOS_SDK:?}"
mkdir -p "$OUT/resource" "$OUT/modules"
ln -sfn "$SWIFT_TOOLCHAIN/lib/swift/clang" "$OUT/resource/clang"
ln -sfn "$SWIFT_SHIMS" "$OUT/resource/shims"
ln -sfn "$SWIFT_APINOTES" "$OUT/resource/apinotes"

# module, install name, sources...
build() {
    local module=$1 install_name=$2
    shift 2
    "$SWIFT_TOOLCHAIN/bin/swiftc" -frontend -c "$@" -whole-module-optimization \
        -target arm64-apple-ios16.0 -sdk "$IOS_SDK" -resource-dir "$OUT/resource" \
        -module-cache-path "$OUT/module-cache" -I "$OUT/modules" -I "$SWIFT_CORE_MODULES" \
        -module-name "$module" -swift-version 5 -enable-library-evolution -parse-as-library -O \
        -runtime-compatibility-version none -disable-autolinking-runtime-compatibility \
        -disable-implicit-string-processing-module-import \
        -emit-module-path "$OUT/modules/$module.swiftmodule" -o "$OUT/$module.o"
    "${LD64_LLD:-ld64.lld}" -dylib -arch arm64 -platform_version ios 16.0 16.5 -syslibroot "$IOS_SDK" \
        -install_name "$install_name" -o "$OUT/$module" "$OUT/$module.o" \
        -L "$IOS_SDK/usr/lib/swift" \
        -lswiftCore -lswift_Concurrency -lswiftObjectiveC -lswiftDarwin -lswiftDispatch -lswiftFoundation \
        -framework Foundation -lobjc -lSystem ${LINK_EXTRA:-}
}

build PhotosUI /usr/lib/swift/libswiftPhotosUI.dylib "$here/PhotosUI.swift"
mv "$OUT/PhotosUI" "$OUT/libswiftPhotosUI.dylib"
LINK_EXTRA="-framework UniformTypeIdentifiers -lswiftUniformTypeIdentifiers" \
    build CoreTransferable /System/Library/Frameworks/CoreTransferable.framework/Versions/A/CoreTransferable \
    "$here/CoreTransferable.swift"
LINK_EXTRA="-framework UniformTypeIdentifiers -lswiftUniformTypeIdentifiers -framework SwiftUI -framework CoreTransferable -lswiftPhotosUI" \
    build _PhotosUI_SwiftUI /System/Library/Frameworks/_PhotosUI_SwiftUI.framework/Versions/A/_PhotosUI_SwiftUI \
    "$here/PhotosUISwiftUI.swift"

# Darling's dyld refuses an iOS image in a macOS process, and the SDK's
# stubs only link for iOS, so mark the results macOS (see foundation/swift).
python3 - "$OUT/libswiftPhotosUI.dylib" "$OUT/CoreTransferable" "$OUT/_PhotosUI_SwiftUI" <<'PY'
import struct, sys
for path in sys.argv[1:]:
    with open(path, "r+b") as f:
        data = bytearray(f.read())
        offset = 32
        for _ in range(struct.unpack_from("<I", data, 16)[0]):
            cmd, size = struct.unpack_from("<II", data, offset)
            if cmd == 0x32:  # LC_BUILD_VERSION: platform, minos, sdk
                struct.pack_into("<III", data, offset + 8, 1, 11 << 16, 11 << 16)
            offset += size
        f.seek(0)
        f.write(data)
PY
