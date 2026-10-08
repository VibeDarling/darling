# Bitmap image context baseline and candidate proof

The bounded component preserves the three public function signatures and implements
explicit-positive-scale offscreen bitmap creation, UIImage snapshots and cleanup.
It reuses the tested UIGraphics push/pop bridge and CGImage-backed UIImage.
It does not supply UIScreen, views/windows, drawing helpers or application lifecycle.

Provenance rung 3:

- [Begin with options](https://developer.apple.com/documentation/uikit/uigraphicsbeginimagecontextwithoptions(_:_:_:)): host-byte-order ARGB32; opaque NoneSkipFirst, otherwise PremultipliedFirst; upper-left UIKit coordinates and supplied scale.
- [Get image](https://developer.apple.com/documentation/uikit/uigraphicsgetimagefromcurrentimagecontext()): current bitmap snapshot, nil for nil/foreign contexts.
- [End](https://developer.apple.com/documentation/uikit/uigraphicsendimagecontext()): removes the current bitmap context, no action for a foreign current context.

Licensed Chameleon UIGraphics.h/.m at84605ede274bd82b330d72dd6ac41e64eb925fd7
supplies bitmap creation, CTM and snapshot structure; complete BSD notices retained.
Its global image stack and main-screen scale fallback are excluded. Existing tracked
CoreGraphics CGBitmapContext/CGContext headers and source supply allocation and CGImage
snapshots, while thread-local retained frames own context and scale lifetimes.

Scale zero is documented to use the main screen scale. No verified UIScreen primitive
exists in this handoff. It raises an explicit local NSInternalInconsistencyException;
no scale1 fallback is supplied. Extend only after the separate screen owner provides
clean main-screen scale proof. Positive finite sizes/scales, integral representable
pixel dimensions and allocation overflow checks use conservative local rung6 rejection;
Apple fractional rounding/error behavior is not observed or claimed.

Authored baseline test bitmap-context.m dynamically looks up the three functions
against the unchanged d216 UIKit artifact. It must fail missing exports. The same
executable against a candidate verifies scale2 pixels, exact CTM, opaque/translucent
formats, partial alpha, nested contexts, foreign context getnil/endno-op, retained
snapshot bytes after cleanup, nil restoration and explicit scale0 rejection.

Compile serially only in an owner-granted short shared-lock slot:

```
python3 tests/build-layout-values.py --source-root <independent-source> --runtime-root <immutable-runtime-libexec/darling> --build-dir <own-output> --linker <native-Darwin-linker> --test-source tests/bitmap-context.m
```

Exit1 without compiler output may mean lock contention; do not label it source failure.
Run via immutable non-setuid launcher in an own sanitized prefix, baseline then
candidate. Commit only after actual compile/guest proof; rebuild clean source before
artifact handoff. No shared runtime installs or user data are involved.

The existing d216 PNG wrapper supports straightRGBA8/32Big only. These documented
hostARGB snapshots are currently rejected with nil. The test checks that limitation
rather than substituting an undocumented bitmap format. Successful canonical authored
PNG pixel proof remains in image-values.m and its recipe; direct bitmap-snapshot PNG
normalization/encoding is a separate missing capability. No new encoding transform or
backend edit is implied by this component.
