# Combine Merge integration check (2026-09-23)

The disposable Darling prefix `/tmp/vd-runtime-20260923` now contains the arm64
`Combine.framework` binary built from `cristim/OpenCombine` commit `10df981` through
the current `darling-swift` fetch-and-patch build. The source fix is proposed as
[OpenCombine PR 258](https://github.com/OpenCombine/OpenCombine/pull/258); the
Darling build and binary are proposed as
[darling-swift PR 51](https://github.com/VibeDarling/darling-swift/pull/51).

The framework was built for `arm64-apple-macosx26.0` with Swift 6.3.3 and
`-enable-library-evolution`. `llvm-nm` confirms that all three Merge imports in
the installed FindMy executable and all three in VoiceMemos are exported. A
scan with the same prefix before and after replacing only Combine confirms
FindMy's direct Combine gaps fell from 6 to 3, and VoiceMemos' from 3 to 0.
The three remaining FindMy gaps are `Result.Publisher` imports.

The Darling runtime test `darling-swift/overlays/tests/combine.swift` passes
15/15 checks in this disposable prefix, including Merge interleaving,
completion after both upstreams finish, and MergeMany forwarding three
subjects. This verifies library behavior on the tested paths; neither app's
full workflow has been exercised.

## Full imported-app scan

Run from a Darling checkout with the app scanner, pointing to the disposable
prefix and the extracted AppZapper copy:

```sh
VIBEDARLING_EXTRA_APP='/tmp/vd-current-scan/apps/AppZapper 3000.app' \
VIBEDARLING_INSTALLED_ROOT=/tmp/vd-runtime-20260923 \
VIBEDARLING_PREFIX=/tmp/vd-no-overlay \
VIBEDARLING_SCAN_OUTPUT=/tmp/vd-current-integrated-all \
python3 tools/darling-applications/scan-imported-apps.py
```

The scan covers 65 imported system apps plus AppZapper. Across the 66 apps it
finds 523 distinct missing direct library install paths, 8 distinct direct
libraries with no compatible arm64 slice, and 45,489 distinct unresolved
direct symbols. Of those symbols, 3,435 are imports from present libraries;
the rest belong to missing or wrong-architecture libraries. AppZapper alone
still has one missing direct library (`SwiftUI.framework`), two wrong-arch
Swift dylibs (`libswiftQuartzCore` and `libswiftSceneKit`), and 500 unresolved
direct symbols. These are static direct-binding counts; they do not measure
imports from absent libraries' own dependencies or prove app behavior.
