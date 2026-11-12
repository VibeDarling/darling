#!/bin/sh
# make-ios-sdk.sh OUT [ROOT]: assemble an iPhoneOS-style SDK at OUT/iPhoneOS.sdk from Darling's own headers,
# for compiling iOS apps from source against Darling instead of Apple's SDK.
#
# Darling's SDK is a macOS one with the iOS frameworks under System/iOSSupport, like Mac Catalyst.
# This links its usr/ and every framework into one System/Library/Frameworks, the iOSSupport ones
# (UIKit, OpenGLES) taking precedence, and gives each framework that has an umbrella header but no
# module map a generated one, so Swift can import it. The macOS SDK is not modified: Darling's macOS
# Swift overlays rely on some frameworks having no Clang module.
#
# With ROOT, Darling's installed tree (.../libexec/darling), the SDK can also link: every library
# there gets an iOS text stub at its install path (make-ios-tbds.py).
#
# Swift also needs the Swift overlays (Foundation, Dispatch, ...) built for an iOS target; this
# script only provides the headers.
set -eu

out=${1:?usage: make-ios-sdk.sh OUT [ROOT]}
darling_root=${2:-}
root=$(cd "$(dirname "$0")/.." && pwd)
mac="$root/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
sdk="$out/iPhoneOS.sdk"  # Xcode's name: CMake and clang tell an iOS SDK by it
frameworks="$sdk/System/Library/Frameworks"

rm -rf "$sdk"
mkdir -p "$frameworks"
# usr/ and usr/include are directories of links into the macOS SDK, so the C++ headers can be added:
# Apple's SDKs carry libc++'s at usr/include/c++/v1, where clang looks under a Darwin sysroot. These
# are the libc++ Darling builds its libc++.1.dylib from.
mkdir -p "$sdk/usr/include/c++"
for entry in "$mac"/usr/*; do
	[ "$(basename "$entry")" = include ] || ln -s "$entry" "$sdk/usr/"
done
for entry in "$mac"/usr/include/*; do
	ln -s "$entry" "$sdk/usr/include/"
done
ln -s "$root/src/external/libcxx/include" "$sdk/usr/include/c++/v1"
ln -s "$mac/Library" "$sdk/Library"

# Darling's Kernel and System frameworks have all of usr/include as their Headers. CMake searches
# frameworks first and took zlib.h from there, putting the C headers out of order: these two get
# no Headers here.
usr_include=$(cd "$mac/usr/include" && pwd -P)
for framework in "$mac"/System/Library/Frameworks/*.framework; do
	if [ "$(cd "$framework/Headers" 2>/dev/null && pwd -P)" = "$usr_include" ]; then
		mkdir "$frameworks/$(basename "$framework")"
		for entry in "$framework"/*; do
			[ "$(basename "$entry")" = Headers ] || [ "$(basename "$entry")" = Versions ] || ln -s "$entry" "$frameworks/$(basename "$framework")/"
		done
	else
		ln -s "$framework" "$frameworks/"
	fi
done

generated=0
for framework in "$mac"/System/Library/Frameworks/*.framework "$mac"/System/iOSSupport/System/Library/Frameworks/*.framework; do
	name=$(basename "$framework" .framework)
	ios=false
	case "$framework" in */iOSSupport/*) ios=true ;; esac
	[ -L "$frameworks/$name.framework" ] || [ "$ios" = true ] || continue  # one of the two above
	if [ -f "$framework/Modules/module.modulemap" ] && [ "$ios" = false ]; then
		continue
	fi
	if [ "$ios" = false ] && [ ! -f "$framework/Headers/$name.h" ]; then
		continue
	fi
	# A real directory, so a Modules/ can sit next to the framework's linked contents (Headers, and
	# Frameworks for umbrella frameworks such as CoreServices, whose sub-frameworks Clang finds there).
	rm -f "$frameworks/$name.framework"
	mkdir -p "$frameworks/$name.framework/Modules"
	for entry in "$framework"/*; do
		[ "$(basename "$entry")" = Modules ] || ln -s "$entry" "$frameworks/$name.framework/"
	done
	if [ -f "$framework/Modules/module.modulemap" ]; then
		ln -s "$framework/Modules/module.modulemap" "$frameworks/$name.framework/Modules/module.modulemap"
	elif [ -f "$framework/Headers/$name.h" ]; then
		printf 'framework module %s {\n  umbrella header "%s.h"\n  export *\n  module * { export * }\n}\n' \
			"$name" "$name" > "$frameworks/$name.framework/Modules/module.modulemap"
		generated=$((generated + 1))
	fi
done

python3 - "$mac/SDKSettings.json" "$sdk/SDKSettings.json" <<'PY'
import json, sys
settings = json.load(open(sys.argv[1]))
settings.update(CanonicalName='iphoneos16.0', Version='16.0', DisplayName='iOS 16.0 (Darling)',
                MinimalDisplayName='16.0', MaximumDeploymentTarget='16.0.99')
settings.setdefault('DefaultProperties', {})['PLATFORM_NAME'] = 'iphoneos'
json.dump(settings, open(sys.argv[2], 'w'), indent=1)
PY

echo "$sdk: $generated generated module maps"

# Apple's clang links libclang_rt.ios.a from its toolchain into every iOS binary: the runtime half
# of @available among others. Darling's is the os_version_check.c its Swift binaries link, which
# answers with the versions Darling presents. It goes beside the SDK, where Xcode's toolchain is;
# the clang in ios-sdk-bin links it.
rt="$out/toolchain/lib/darwin"
mkdir -p "$rt"
clang --target=arm64-apple-ios9.0 -O2 -c "$root/src/frameworks/SwiftUI/backend/os_version_check.c" -o "$rt/os_version_check.o"
rm -f "$rt/libclang_rt.ios.a"
llvm-ar rcs "$rt/libclang_rt.ios.a" "$rt/os_version_check.o"
rm "$rt/os_version_check.o"
if [ -n "$darling_root" ]; then
	python3 "$root/tools/make-ios-tbds.py" "$darling_root" "$sdk"
fi
