#!/usr/bin/env bash
# Build a distinct Hello World IPA against the SDK, not Darling's custom SwiftUI module.
# Uses the same toolchain inputs as frameworks/SwiftUI/abi/build.sh.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:?usage: build-sdk.sh OUTPUT_DIRECTORY}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
IAR="${IAR:-$HOME/git/ios-android-runtime}"
SWIFT_TOOLCHAIN="${SWIFT_TOOLCHAIN:-$IAR/tools/swift/swift-6.3.3-RELEASE-ubuntu24.04/usr}"
IOS_SDK="${IOS_SDK:-/opt/theos/sdks/iPhoneOS16.5.sdk}"
SWIFT_CORE_MODULES="${SWIFT_CORE_MODULES:-$IAR/tools/swift/build-ios/Core}"
SWIFT_SHIMS="${SWIFT_SHIMS:-$IAR/tools/swift/install/usr/lib/swift/shims}"
SWIFT_APINOTES="${SWIFT_APINOTES:-$IAR/tools/swift/source/apinotes}"
if [ -d "$IAR/tools/swift/host-libs" ]; then
    export LD_LIBRARY_PATH="$IAR/tools/swift/host-libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
mkdir -p "$OUT/resource" "$OUT/Payload/HelloWorld.app"
ln -sfn "$SWIFT_TOOLCHAIN/lib/swift/clang" "$OUT/resource/clang"
ln -sfn "$SWIFT_SHIMS" "$OUT/resource/shims"
ln -sfn "$SWIFT_APINOTES" "$OUT/resource/apinotes"

# Only the Swift standard library is overridden. SwiftUI comes from the SDK.
"$SWIFT_TOOLCHAIN/bin/swiftc" -frontend -c "$here/HelloApp.swift" -parse-as-library \
    -target arm64-apple-ios14.0 -sdk "$IOS_SDK" -resource-dir "$OUT/resource" \
    -module-cache-path "$OUT/module-cache" -I "$SWIFT_CORE_MODULES" \
    -swift-version 5 -O -module-name HelloWorld \
    -runtime-compatibility-version none -disable-autolinking-runtime-compatibility \
    -disable-implicit-concurrency-module-import -disable-implicit-string-processing-module-import \
    -o "$OUT/HelloApp.o"
"$SWIFT_TOOLCHAIN/bin/clang" -c -O2 -target arm64-apple-ios14.0 -isysroot "$IOS_SDK" \
    "$here/../frameworks/SwiftUI/backend/os_version_check.c" -o "$OUT/os_version_check.o"
"${LD64_LLD:-ld64.lld}" -arch arm64 -platform_version ios 14.0 16.4 -syslibroot "$IOS_SDK" \
    -ignore_auto_link -undefined dynamic_lookup -rpath /usr/lib/swift \
    -o "$OUT/Payload/HelloWorld.app/HelloWorld" "$OUT/HelloApp.o" "$OUT/os_version_check.o" \
    -L "$IOS_SDK/usr/lib/swift" -lswiftCore -framework SwiftUI -framework Foundation -lobjc

python3 - "$here/Info.plist" "$OUT" <<'PY'
from pathlib import Path
import plistlib, sys, zipfile
template, output = map(Path, sys.argv[1:])
info = plistlib.loads(template.read_bytes())
info.update(CFBundleDisplayName='Hello World', CFBundleName='HelloWorld',
            CFBundleExecutable='HelloWorld', CFBundleIdentifier='org.darlinghq.hello-world-sdk')
app = output / 'Payload/HelloWorld.app'
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
with zipfile.ZipFile(output / 'HelloWorld.ipa', 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in ['Info.plist', 'HelloWorld']:
        archive.write(app / name, 'Payload/HelloWorld.app/' + name)
print('Built SDK client:', output / 'HelloWorld.ipa')
PY
