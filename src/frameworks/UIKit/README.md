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

## UIColor CGColor bridge

`UIColor` keeps its RGBA storage and gains `initWithRed:`, `initWithWhite:`,
`initWithCGColor:`, `+colorWithCGColor:`, `-CGColor`, `getRed:green:blue:alpha:`,
`getWhite:alpha:` and `NSCopying` (adapted from the Chameleon UIColor, BSD
notice retained; clean-room rung 3, Apple public documentation of `UIColor`).

Policy choices (rung 6, Apple behavior not observed): `-CGColor` is created on
first use as a generic RGB or gray color and is owned by the `UIColor`;
`getWhite:alpha:` succeeds only for colors made with a white value, while
`getRed:green:blue:alpha:` always succeeds (gray reads back as equal components);
`colorWithCGColor:` raises `NSInvalidArgumentException` for NULL and for color
models other than RGB and monochrome, and does not preserve the source color space.
All constructors raise `NSInvalidArgumentException` for NaN and infinite components (and
release `self` first, so nothing leaks under ARC). Finite components outside 0...1 are stored
unclamped; Apple's documentation describes clamping to 0...1 for the RGB and white
initializers, so this is a known difference (rung 6, not observed). `-CGColor` is
created under `@synchronized(self)`, so concurrent first calls return the same object, and
the property is marked `NS_RETURNS_INNER_POINTER` because the `UIColor` owns the value.

`tests/color-values.m` takes the guest path of the built UIKit dylib as its only
argument. It has been syntax-checked only; it has not been run under Darling.
