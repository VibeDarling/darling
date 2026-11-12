#!/usr/bin/env bash
# build.sh OUT: builds StoreKit's Swift API as OUT/StoreKit.framework/StoreKit, an arm64 iOS library
# installed as StoreKit.framework/Versions/A/StoreKitSwift and re-exported by Darling's StoreKit
# (configure with -DDARLING_STOREKIT_SWIFT_DYLIB=OUT/StoreKit.framework/StoreKit).
# Same toolchain and SDK as SwiftUI's ABI build (../../SwiftUI/abi/build-ios-swift-framework.sh).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
INSTALL_NAME=/System/Library/Frameworks/StoreKit.framework/Versions/A/StoreKitSwift \
	bash "$here/../../SwiftUI/abi/build-ios-swift-framework.sh" StoreKit "${1:?output directory}" \
	"$here/StoreKit.swift" "$here/Support.swift" -- -framework UIKit
