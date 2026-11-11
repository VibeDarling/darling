#!/bin/sh
# make-ios-sdk.sh OUT: assemble an iPhoneOS-style SDK at OUT/DarlingiOS.sdk from Darling's own headers,
# for compiling iOS apps from source against Darling instead of Apple's SDK.
#
# Darling's SDK is a macOS one with the iOS frameworks under System/iOSSupport, like Mac Catalyst.
# This links its usr/ and every framework into one System/Library/Frameworks, the iOSSupport ones
# (UIKit, OpenGLES) taking precedence, and gives each framework that has an umbrella header but no
# module map a generated one, so Swift can import it. The macOS SDK is not modified: Darling's macOS
# Swift overlays rely on some frameworks having no Clang module.
#
# Swift also needs the Swift overlays (Foundation, Dispatch, ...) built for an iOS target; this
# script only provides the headers.
set -eu

out=${1:?usage: make-ios-sdk.sh OUT}
root=$(cd "$(dirname "$0")/.." && pwd)
mac="$root/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
sdk="$out/DarlingiOS.sdk"
frameworks="$sdk/System/Library/Frameworks"

rm -rf "$sdk"
mkdir -p "$frameworks"
ln -s "$mac/usr" "$sdk/usr"
ln -s "$mac/Library" "$sdk/Library"

for framework in "$mac"/System/Library/Frameworks/*.framework; do
	ln -s "$framework" "$frameworks/"
done

generated=0
for framework in "$mac"/System/Library/Frameworks/*.framework "$mac"/System/iOSSupport/System/Library/Frameworks/*.framework; do
	name=$(basename "$framework" .framework)
	ios=false
	case "$framework" in */iOSSupport/*) ios=true ;; esac
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
