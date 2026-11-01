#!/usr/bin/env bash
# build-ios-swift-framework.sh NAME OUT SOURCE... [-- EXTRA LINK INPUTS]
# Builds an arm64 iOS Swift framework NAME (library evolution, like Apple's) from SOURCE files against
# the same SDK and Swift modules as build.sh, writing OUT/NAME.framework/NAME and OUT/NAME.swiftmodule.
# INSTALL_NAME and LINK_NAME override the framework's install name and autolink name, for overlays
# such as libswiftUIKit (INSTALL_NAME=/usr/lib/swift/libswiftUIKit.dylib LINK_NAME=swiftUIKit).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
NAME=$1; OUT=$2; shift 2
sources=(); link=()
while [ $# -gt 0 ]; do
	if [ "$1" = -- ]; then shift; link=("$@"); break; fi
	sources+=("$1"); shift
done
IAR="${IAR:-$HOME/git/ios-android-runtime}"
SWIFT_TOOLCHAIN="${SWIFT_TOOLCHAIN:-$IAR/tools/swift/swift-6.3.3-RELEASE-ubuntu24.04/usr}"
IOS_SDK="${IOS_SDK:-/opt/theos/sdks/iPhoneOS16.5.sdk}"
SWIFT_CORE_MODULES="${SWIFT_CORE_MODULES:-$IAR/tools/swift/build-ios/Core}"
SWIFT_SHIMS="${SWIFT_SHIMS:-$IAR/tools/swift/install/usr/lib/swift/shims}"
SWIFT_APINOTES="${SWIFT_APINOTES:-$IAR/tools/swift/source/apinotes}"
[ -d "$IAR/tools/swift/host-libs" ] && export LD_LIBRARY_PATH="$IAR/tools/swift/host-libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p "$OUT/resource" "$OUT/$NAME.framework"
ln -sfn "$SWIFT_TOOLCHAIN/lib/swift/clang" "$OUT/resource/clang"
ln -sfn "$SWIFT_SHIMS" "$OUT/resource/shims"
ln -sfn "$SWIFT_APINOTES" "$OUT/resource/apinotes"
rm -rf "$OUT/module-cache-$NAME"
"$SWIFT_TOOLCHAIN/bin/swiftc" -frontend -c "${sources[@]}" -whole-module-optimization \
	-target arm64-apple-ios16.0 -sdk "$IOS_SDK" -resource-dir "$OUT/resource" \
	-module-cache-path "$OUT/module-cache-$NAME" -I "$SWIFT_CORE_MODULES" -I "$OUT" \
	-swift-version 5 -O -module-name "$NAME" ${LINK_NAME:+-module-link-name "$LINK_NAME" -autolink-force-load} -enable-library-evolution -parse-as-library \
	-disable-availability-checking -emit-module-path "$OUT/$NAME.swiftmodule" \
	-runtime-compatibility-version none -disable-autolinking-runtime-compatibility \
	-disable-implicit-concurrency-module-import -disable-implicit-string-processing-module-import \
	-o "$OUT/$NAME.o"
"${LD64_LLD:-ld64.lld}" -dylib -arch arm64 -platform_version ios 16.0 16.4 -syslibroot "$IOS_SDK" \
	-ignore_auto_link -undefined dynamic_lookup \
	-install_name "${INSTALL_NAME:-/System/Library/Frameworks/$NAME.framework/$NAME}" \
	-o "$OUT/$NAME.framework/$NAME" "$OUT/$NAME.o" \
	-L "$IOS_SDK/usr/lib/swift" -lswiftCore -lswift_Concurrency -framework Foundation -lobjc ${link[@]+"${link[@]}"}
echo "Built $OUT/$NAME.framework/$NAME"
