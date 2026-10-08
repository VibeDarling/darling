# UIKit compositional layout values

This first component implements documented layout dimension, size, spacing and
edge-spacing factories and getters, including NSCopying. These objects describe
layout inputs. No collection view renderer or application/window lifecycle is
implemented by this component.

Specification: Apple public documentation (clean-room rung 3):

- https://developer.apple.com/documentation/uikit/nscollectionlayoutdimension?language=objc
- https://developer.apple.com/documentation/uikit/nscollectionlayoutsize?language=objc
- https://developer.apple.com/documentation/uikit/nscollectionlayoutspacing?language=objc
- https://developer.apple.com/documentation/uikit/nscollectionlayoutedgespacing?language=objc

Darling rejects nonfinite layout values, negative dimensions, missing size
dimensions, incorrectly typed edges, and bare init/new. This validation is a
conservative boundary policy (rung 6); Apple's exact invalid-input behavior has
not been observed. Finite negative spacing remains representable. Newer uniform
sibling dimensions and layout items/groups/sections are not implemented here.

`tests/layout-values.m` uses runtime class lookup so the same executable can run
against the baseline without UIKit: it fails at the missing classes. Pass the
absolute guest path of the built UIKit dylib to exercise factories and copying.
The test uses synthetic values only and does not load Messages or user data.

The framework is built by the gui component group in src/frameworks/CMakeLists.txt.
No private UIKit contracts or guessed constant values are supplied.

The Objective-C getters on `NSCollectionLayoutSpacing` are `isFixedSpacing` and
`isFlexibleSpacing`, the names Apple documents for Objective-C (`isFixed` and
`isFlexible` are the Swift spellings and must not be added as selectors).

Focused build (use independently cloned dependencies at the superproject pins):

```sh
python3 \
  src/frameworks/UIKit/tests/build-layout-values.py \
  --source-root . --runtime-root "$DARLING_RUNTIME_ROOT" \
  --build-dir "$UIKIT_BUILD_DIR" --linker "$DARLING_DARWIN_LINKER"
```

The runtime root is the read-only `libexec/darling` image directory. This command
compiles one test and one framework serially, saves exact commands, and neither
installs artifacts nor configures the shared build. Run the resulting harness
through Darling in a fresh sanitized prefix, first with no argument (expected
failure), then with the UIKit path (expected success). `--arch` (default `arm64`) must match the
runtime image. With the path given, the test also asserts each class lives in the image at
that path (via dladdr), so it works for `<build>/UIKit` and the CMake framework alike.

To check the CMake-built product exports the classes (use `llvm-nm`; GNU nm cannot read Mach-O here) (not covered by the focused
build above), after a normal build:

```sh
llvm-nm -gU <build>/src/frameworks/UIKit/UIKit | rg 'OBJC_CLASS_\$_NSCollectionLayout(Dimension|Size|Spacing|EdgeSpacing)$'
```

`NSStringFromCGSize` delegates geometry formatting to Foundation, reusing the BSD
Chameleon wrapper (84605ede274bd82b330d72dd6ac41e64eb925fd7, UIGeometry.m). The complete
notice and license are retained. Specification is rung 3, Apple's public
[NSStringFromCGSize](https://developer.apple.com/documentation/uikit/nsstringfromcgsize)
and [CGSizeFromString](https://developer.apple.com/documentation/uikit/cgsizefromstring)
documentation: width and height in an unlocalized comma-separated brace pair.
Pass `--test-source src/frameworks/UIKit/tests/geometry.m` to build the focused
`geometry` regression; it fails against the layout-only framework before this change.
Existing Foundation geometry boxing categories are reused without duplication.

The public graphics-context push/pop/current functions bridge AppKit's thread-local
NSGraphicsContext. Their saved stack retains contexts and the previous nil state
per thread. Rung 3 specifications: Apple's [push](https://developer.apple.com/documentation/uikit/uigraphicspushcontext(_:)),
[pop](https://developer.apple.com/documentation/uikit/uigraphicspopcontext()), and
[current](https://developer.apple.com/documentation/uikit/uigraphicsgetcurrentcontext())
documentation. The BSD Chameleon bridge declarations retain their notices; its
global stack is replaced with a thread-local stack. Null pushes and unmatched pops
raise NSInvalidArgumentException as conservative local rung 6 policy, without an
observed Apple error contract. Use `--test-source src/frameworks/UIKit/tests/graphics-context.m`
for nesting, AppKit/nil restoration, retained lifetime and simultaneous-thread proof.
This implements context selection, without claiming rendering or image APIs.
