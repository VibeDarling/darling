# UIButton

`ios-uibutton.m` checks `UIButton` and what it draws with:

- **Tint.** A view without its own `tintColor` has its superview's, and the
  root has the system blue. `tintColorDidChange` reaches the views that
  inherit a change, and not those with their own tint. A dimmed
  `tintAdjustmentMode` is inherited.
- **Template images.** `imageWithRenderingMode:` and `imageWithTintColor:`.
  System buttons draw their title, and images in automatic mode, in the tint.
- **Layout.** The image and the title sit side by side, aligned as one group
  inside `contentEdgeInsets` (`contentHorizontalAlignment` and
  `contentVerticalAlignment`). `titleEdgeInsets` and `imageEdgeInsets` move
  only their own part. Subclasses can override `titleRectForContentRect:`
  and the other layout hooks.
- **Titles.** Attributed titles, title shadow colors and
  `reversesTitleShadowWhenHighlighted`, all per state.
- **States.** The `showsTouchWhenHighlighted` glow comes and goes. The info
  and add buttons draw template glyphs. Also checks
  `systemButtonWithImage:target:action:`.

It prints one PASS/FAIL line per check (25 in all) and exits nonzero on any
failure. It then shows a column of buttons for five seconds, for a
screenshot. The column covers system, tinted, highlighted, disabled, glyph,
darkened, glowing, attributed, shadowed and left-aligned buttons.

On x86_64 it runs as a Mac Catalyst binary:

```sh
clang -target x86_64-apple-macos11.0 -fobjc-arc -isysroot $SDK \
  -F $SDK/System/iOSSupport/System/Library/Frameworks -F $SDK/System/Library/Frameworks \
  -iframework $SDK/System/Library/Frameworks/CoreServices.framework/Frameworks \
  -iframework $SDK/System/Library/Frameworks/ApplicationServices.framework/Frameworks \
  -c tests/ios-uibutton.m
clang -target x86_64-apple-macos11.0 -fuse-ld=lld -nostdlib -Wl,-syslibroot,$R \
  -F $R/System/iOSSupport/System/Library/Frameworks -F $R/System/Library/Frameworks \
  -L $R/usr/lib ios-uibutton.o -framework UIKit -framework Foundation \
  -framework CoreFoundation -framework CoreGraphics -lobjc -lSystem -o uibutton
# then set LC_BUILD_VERSION's platform to 6 (Mac Catalyst)
```

Getting the buttons on screen needed three fixes that are not obvious:

- **Views laid out late were never drawn.** AppKit's `setFrame:` does not
  redraw anything, and a button lays out its title and image from
  `layoutSubviews`, after its window first displayed. `UIView` now redraws
  the old and new frame, as UIKit does.
- **A title exactly as wide as its label wrapped out of sight.** AppKit pads
  the text container, so `UILabel` draws a single line at a point. It aligns
  the line itself, since a centred paragraph drawn at a point is centred in
  AppKit's very wide container.
- **Holes in backgrounds.** Onyx2D clips to the bounding box of a clip path,
  so a view clipped to several dirty rects paints all of the area between
  them. Its opaque subviews, clipped to their own fewer rects, then left
  that area blank. Cocotron's `NSView` no longer clips to the separate rects.
