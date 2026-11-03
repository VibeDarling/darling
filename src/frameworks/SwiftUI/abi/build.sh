#!/usr/bin/env bash
# Builds the ABI-compatible SwiftUI (arm64, iOS) from Sources/: the binary interface apps built
# with Apple's SDK link against, as opposed to ../Sources, which apps must be compiled against.
#
# Inputs (environment, with the defaults used on the build machine):
#   SWIFT_TOOLCHAIN  Swift 6.3.3 usr/ directory
#   IOS_SDK          an iOS 16.x SDK (its SwiftUI interface is the ABI reference)
#   SWIFT_CORE_MODULES, OBSERVATION_MODULES  directories holding the iOS Swift.swiftmodule and
#                    Observation.swiftmodule this module compiles against
#   OBSERVATION_DYLIB  a libswiftObservation.dylib to link (the SDK predates Observation)
#   LD64_LLD         an ld64.lld that can link for iOS (the toolchain's cannot)
#   SWIFT_SHIMS, SWIFT_APINOTES  the shims and API notes matching those modules
#   OUT              output directory (SwiftUI.framework/SwiftUI is written there)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
IAR="${IAR:-$HOME/git/ios-android-runtime}"
SWIFT_TOOLCHAIN="${SWIFT_TOOLCHAIN:-$IAR/tools/swift/swift-6.3.3-RELEASE-ubuntu24.04/usr}"
IOS_SDK="${IOS_SDK:-/opt/theos/sdks/iPhoneOS16.5.sdk}"
SWIFT_CORE_MODULES="${SWIFT_CORE_MODULES:-$IAR/tools/swift/build-ios/Core}"
OBSERVATION_MODULES="${OBSERVATION_MODULES:-$IAR/tools/swift-observation/build}"
OBSERVATION_DYLIB="${OBSERVATION_DYLIB:-$IAR/tools/swift/install/usr/lib/swift/libswiftObservation.dylib}"
SWIFT_SHIMS="${SWIFT_SHIMS:-$IAR/tools/swift/install/usr/lib/swift/shims}"
SWIFT_APINOTES="${SWIFT_APINOTES:-$IAR/tools/swift/source/apinotes}"
OUT="${OUT:?set OUT to an output directory}"
# The Ubuntu toolchain needs libncurses.so.6, which some hosts only have in this directory.
[ -d "$IAR/tools/swift/host-libs" ] && export LD_LIBRARY_PATH="$IAR/tools/swift/host-libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

mkdir -p "$OUT/resource" "$OUT/SwiftUI.framework"
ln -sfn "$SWIFT_TOOLCHAIN/lib/swift/clang" "$OUT/resource/clang"
ln -sfn "$SWIFT_SHIMS" "$OUT/resource/shims"
ln -sfn "$SWIFT_APINOTES" "$OUT/resource/apinotes"
rm -rf "$OUT/module-cache"

"$SWIFT_TOOLCHAIN/bin/swiftc" -frontend -c "$here"/Sources/*.swift -whole-module-optimization \
	-target arm64-apple-ios16.0 -sdk "$IOS_SDK" -resource-dir "$OUT/resource" \
	-module-cache-path "$OUT/module-cache" -I "$SWIFT_CORE_MODULES" -I "$OBSERVATION_MODULES" -I "$here/CoreDataBridge" \
	-swift-version 5 -O -module-name SwiftUI -enable-library-evolution -parse-as-library \
	-disable-availability-checking \
	-emit-module-path "$OUT/SwiftUI.swiftmodule" \
	-runtime-compatibility-version none -disable-autolinking-runtime-compatibility \
	-disable-implicit-concurrency-module-import -disable-implicit-string-processing-module-import \
	-o "$OUT/SwiftUI.o"

"$SWIFT_TOOLCHAIN/bin/clang" -c -O2 -fobjc-exceptions -fblocks -target arm64-apple-ios16.0 -isysroot "$IOS_SDK" -I "$here/../../../include" \
    "$here/CoreDataBridge/CoreDataBridge.m" -o "$OUT/CoreDataBridge.o"

# The runtime of #available, which Apple's clang would link from libclang_rt.ios.a.
"$SWIFT_TOOLCHAIN/bin/clang" -c -O2 -target arm64-apple-ios16.0 -isysroot "$IOS_SDK" \
	"$here/../backend/os_version_check.c" -o "$OUT/os_version_check.o"

# Swift symbols of Foundation and Combine bind by name at load time: Darling's Foundation
# re-exports libswiftFoundation, and UIKit's Objective-C classes come from Darling's UIKit.
"${LD64_LLD:-ld64.lld}" -dylib -arch arm64 -platform_version ios 16.0 16.4 -syslibroot "$IOS_SDK" \
	-ignore_auto_link -undefined dynamic_lookup \
	-install_name /System/Library/Frameworks/SwiftUI.framework/SwiftUI \
	-o "$OUT/SwiftUI.framework/SwiftUI" "$OUT/SwiftUI.o" "$OUT/os_version_check.o" "$OUT/CoreDataBridge.o" \
	-L "$IOS_SDK/usr/lib/swift" -lswiftCore -weak_library "$OBSERVATION_DYLIB" -lswiftCoreFoundation -lswift_Concurrency \
	-framework Foundation -framework CoreFoundation -framework UIKit -framework CoreGraphics -framework Combine -framework CoreData -lobjc
echo "Built $OUT/SwiftUI.framework/SwiftUI"

# Exercise the SDK interface, independently of the source module emitted above.
SWIFT_TOOLCHAIN="$SWIFT_TOOLCHAIN" IOS_SDK="$IOS_SDK" \
    SWIFT_CORE_MODULES="$SWIFT_CORE_MODULES" SWIFT_SHIMS="$SWIFT_SHIMS" \
    SWIFT_APINOTES="$SWIFT_APINOTES" \
    "$here/../../../HelloSwiftUI/build-sdk.sh" "$OUT/hello-sdk"
python3 "$here/../../../HelloSwiftUI/check-abi.py" \
    "$OUT/hello-sdk/Payload/HelloWorld.app/HelloWorld" "$OUT/SwiftUI.framework/SwiftUI"
