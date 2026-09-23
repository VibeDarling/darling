#!/usr/bin/env bash
set -euo pipefail

# Build the real SwiftPM target to expose its next dependency failure. The
# CALayer/CAFilter/attributed-string SDK overlays and OPENATTRIBUTEGRAPH_DARLING
# flag used here are diagnostic; a successful compile is not runtime coverage.
vd_src=${VIBEDARLING_SRC:-/home/cristi/src}
vd_tmp=${VIBEDARLING_TMP:-/tmp}
vd_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
vd_swift_linux="$vd_src/swift-darling/toolchain-linux/swift-6.3.3-RELEASE-ubuntu24.04-aarch64/usr"
vd_swift_source="$vd_src/swift-darling/overlay-src/swift-6.3.3-full"
vd_swift_darwin="$vd_src/swift-darling/osx-6.3.3/payload/usr/lib/swift"
vd_sdk="$vd_src/.tmp-vd-darwin-lock-sdk"
vd_modules="$vd_tmp/vd-swiftui-modules/System/Library/Frameworks"
vd_resource="$vd_tmp/vd-swiftpm-resource-script"
vd_build="${VIBEDARLING_SWIFTPM_BUILD_PATH:-$vd_tmp/vd-swiftui-swiftpm-build}"

for required in \
    "$vd_swift_linux/bin/swift" \
    "$vd_swift_source/include/swift/Runtime/Metadata.h" \
    "$vd_swift_darwin/macosx/Swift.swiftmodule" \
    "$vd_sdk/usr/include/TargetConditionals.h" \
    "$vd_modules/QuartzCore.framework/Headers/CALayer.h" \
    "$vd_src/OpenCombine/Package.swift"; do
    if [[ ! -e "$required" ]]; then
        printf 'Missing required local build input: %s\n' "$required" >&2
        exit 2
    fi
done

mkdir -p "$vd_resource" "$vd_build" "$vd_tmp/vd-swiftpm-cache" "$vd_tmp/vd-swiftpm-config"
for entry in "$vd_swift_darwin"/*; do
    ln -sfn "$entry" "$vd_resource/${entry##*/}"
done
ln -sfn "$vd_swift_linux/lib/swift/linux" "$vd_resource/linux"

export LD_LIBRARY_PATH="$vd_tmp/vd-swiftpm-libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_CACHE_HOME="$vd_tmp/vd-swiftpm-cache"
export XDG_CONFIG_HOME="$vd_tmp/vd-swiftpm-config"
export CLANG_MODULE_CACHE_PATH="$vd_tmp/vd-swiftpm-cache/clang"
export VIBEDARLING_SWIFTC="$vd_swift_linux/bin/swiftc"
export VIBEDARLING_DARWIN_SWIFT_MODULES="${VIBEDARLING_DARWIN_SWIFT_MODULES:-$vd_src/swift-darling/overlays/out/modules}"
export VIBEDARLING_FOUNDATION_SWIFT_MODULES="${VIBEDARLING_FOUNDATION_SWIFT_MODULES:-$vd_src/swift-darling/overlays/out-foundation-min/modules}"
export SWIFT_EXEC="$vd_script_dir/swiftc-platform-wrapper.sh"
export OPENSWIFTUI_USE_LOCAL_DEPS=1
export OPENSWIFTUI_OPENCOMBINE=1
export OPENATTRIBUTEGRAPH_SWIFT_CHECKOUT_PATH="$vd_swift_source"
export OPENSWIFTUI_BUILD_FOR_DARWIN_PLATFORM=1
export OPENSWIFTUI_SWIFT_LOG=1
export OPENSWIFTUI_LINK_COREUI=0
export OPENSWIFTUI_LINK_CORESVG=0
export OPENSWIFTUI_LINK_SFSYMBOLS=0
export OPENSWIFTUI_LINK_FEATUREFLAGS=0
export OPENSWIFTUI_LINK_BACKLIGHTSERVICES=0
export OPENSWIFTUI_LINK_GESTURES=0
export OPENSWIFTUI_LIBRARY_EVOLUTION=0
export OPENSWIFTUI_TYPED_MEMORY_OPERATIONS=0
export OPENATTRIBUTEGRAPH_TYPED_MEMORY_OPERATIONS=0

exec "$vd_swift_linux/bin/swift" build \
    --package-path "$vd_src/OpenSwiftUI" \
    --build-path "$vd_build" \
    --target OpenSwiftUI \
    --skip-update \
    --triple arm64-apple-macosx26.0 \
    --sdk "$vd_sdk" \
    -j 4 \
    -Xswiftc -DOPENATTRIBUTEGRAPH_DARLING \
    -Xswiftc -resource-dir -Xswiftc "$vd_resource" \
    -Xswiftc "-F$vd_modules" \
    -Xswiftc "-F$vd_src/darling-image-master/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks" \
    -Xswiftc -Xcc -Xswiftc "-isystem$vd_tmp/vd-libcxx-headers" \
    -Xcc "-F$vd_modules" \
    -Xcc "-F$vd_src/darling-image-master/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks" \
    -Xcxx "-isystem$vd_src/darling-image-master/src/external/libcxx/include" \
    -Xcxx "-isystem$vd_src/swift-darling/build-runtimes-arm64e/include"
