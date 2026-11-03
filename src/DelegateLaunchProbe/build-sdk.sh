#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
: "${OUT:?set OUT}"
: "${DARLING_SOURCE:?set DARLING_SOURCE}"
: "${SWIFT_TOOLCHAIN:?set SWIFT_TOOLCHAIN}"
: "${SWIFT_CORE_MODULES:?set SWIFT_CORE_MODULES}"
: "${SWIFT_SHIMS:?set SWIFT_SHIMS}"
: "${SWIFT_APINOTES:?set SWIFT_APINOTES}"
: "${IOS_SDK:?set IOS_SDK}"
mkdir -p "$OUT/resource" "$OUT/Payload/DelegateProbe.app"
ln -sfn "$SWIFT_TOOLCHAIN/lib/swift/clang" "$OUT/resource/clang"
ln -sfn "$SWIFT_SHIMS" "$OUT/resource/shims"
ln -sfn "$SWIFT_APINOTES" "$OUT/resource/apinotes"
# The output directory is new for each fixture identity; do not import any replacement SwiftUI module.
"$SWIFT_TOOLCHAIN/bin/swiftc" -frontend -c "$here/Probe.swift" -parse-as-library \
    -target arm64-apple-ios16.0 -sdk "$IOS_SDK" -resource-dir "$OUT/resource" \
    -module-cache-path "$OUT/module-cache" -I "$SWIFT_CORE_MODULES" \
    -import-objc-header "$here/FixtureBridge.h" -swift-version 5 -Onone -module-name DelegateProbe \
    -runtime-compatibility-version none -disable-autolinking-runtime-compatibility \
    -disable-implicit-concurrency-module-import -disable-implicit-string-processing-module-import \
    -o "$OUT/FetchApp.o"
clang -c -target arm64-apple-ios16.0 -isysroot "$IOS_SDK" -fobjc-exceptions -fblocks \
    -Wall -Wextra -Werror -I"$DARLING_SOURCE/src/include" "$here/FixtureBridge.m" -o "$OUT/FixtureBridge.o"
clang -c -target arm64-apple-ios16.0 -isysroot "$IOS_SDK" \
    "$DARLING_SOURCE/src/frameworks/SwiftUI/backend/os_version_check.c" -o "$OUT/availability.o"
ld64.lld -arch arm64 -platform_version ios 16.0 16.5 -syslibroot "$IOS_SDK" -ignore_auto_link \
    -no_fixup_chains -rpath /usr/lib/swift -o "$OUT/Payload/DelegateProbe.app/DelegateProbe" \
    "$OUT/FetchApp.o" "$OUT/FixtureBridge.o" "$OUT/availability.o" \
    -L "$IOS_SDK/usr/lib/swift" -lswiftCore -lswiftObjectiveC -lswiftDarwin -lswiftCoreFoundation \
    -lswiftDispatch -lswiftos -lswiftUniformTypeIdentifiers -lswiftUIKit -lswiftCoreImage \
    -lswiftMetal -lswiftQuartzCore -lswiftFileProvider -lswiftDataDetection -lswiftOSLog -framework SwiftUI -framework Foundation -framework CoreData -framework Combine -framework UIKit -lobjc -lSystem
python3 - "$OUT" <<'PY'
from pathlib import Path
import plistlib,sys,zipfile
out=Path(sys.argv[1]);app=out/'Payload/DelegateProbe.app'
info={'CFBundleName':'DelegateProbe','CFBundleDisplayName':'Delegate Probe','CFBundleExecutable':'DelegateProbe',
      'CFBundleIdentifier':'org.darlinghq.delegate-probe','CFBundleVersion':'1','CFBundleShortVersionString':'1.0',
      'CFBundlePackageType':'APPL','MinimumOSVersion':'16.0','UIDeviceFamily':[1],
      'UILaunchScreen':{},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait']}
(app/'Info.plist').write_bytes(plistlib.dumps(info))
with zipfile.ZipFile(out/'DelegateProbe.ipa','w',zipfile.ZIP_DEFLATED) as archive:
    for name in ('Info.plist','DelegateProbe'):archive.write(app/name,'Payload/DelegateProbe.app/'+name)
print('BUILT_PUBLIC_SDK_DELEGATE_PROBE')
PY
