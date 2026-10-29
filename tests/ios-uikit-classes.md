# UIKit classes for file managers

`ios-uikit-classes.m` checks the UIKit classes that FileBrowser and Filza
link against:

- **Gesture recognizers**, driven by real pointer events sent to the view:
  - a tap recognizes and cancels the view's touches, or lets them through
    with `cancelsTouchesInView` off;
  - a drag is not a tap;
  - a pan begins, changes and ends, with its translation;
  - a single tap waits for a double tap to fail (`requireGestureRecognizerToFail:`);
  - long press, and a left swipe that is not a right one;
  - a button's own tap beats a tap recognizer on a view above it, as since iOS 6.
- **UITableViewController.**
  - It owns its table, from `initWithStyle:` called from an `-init` override.
  - It clears the selection when it appears again, and editing reaches the table.
  - `UITableViewHeaderFooterView` registers and dequeues.
- **UICollectionView and UICollectionViewFlowLayout.**
  - Items wrap into rows below the header and section inset.
  - Full rows spread out and the last row stays left.
  - Only cells in sight have views, and scrolling reuses them.
  - `indexPathForItemAtPoint:`.
- **UIToolbar.** A flexible space pushes the last item to the edge.
- **Value controls.** `UISlider`, `UIProgressView` and `UIPageControl`
  clamp their values. `UIPickerView` reports its components and selection.
- **UITextView.** Text and the AppKit text storage behind it.
- **Drawing.**
  - `UIBezierPath`: rounded rects, and hit testing outside the corners.
  - An image context at scale 2: the image's size, scale and pixels.
- **Containers.**
  - A phone `UISplitViewController` pushes the detail onto its primary.
  - `UIPageViewController` shows its page.
  - `UIStoryboardSegue` performs its handler.
- **UIPasteboard items.** `itemSetWithPasteboardTypes:`, the strings and
  URL across items, and `changeCount`.
- **UIAppearance.** A proxy's setters reach a label when it goes on screen.
  A proxy for labels inside toolbars wins over the plain one.
- **Auto Layout.**
  - Constraints to `layoutMarginsGuide` and `safeAreaLayoutGuide` are solved.
  - The guide's own frame is set.
  - A label has an intrinsic size.
- **Strings and fonts.**
  - `boundingRectWithSize:options:attributes:context:` and
    `sizeWithAttributes:` with UIFonts in the attributes.
  - `preferredFontForTextStyle:`, and the iOS 13 system colors.
- **The fallback.** A method UIKit lacks answers nil instead of raising,
  and `respondsToSelector:` still says no.

It then shows a toolbar, a slider, a progress bar, a page control, a picker,
a collection grid and a text view. Once the grid's cells have been drawn
(up to 30 seconds), it checks they are on screen. It leaves the views up
for three more seconds, for a screenshot. It prints one PASS/FAIL line per
check (60 in all; the first is that the device reports iOS 14) and exits nonzero on any failure.

Software rendering in an emulated arm64 VM is slow, so the checks that
depend on timers or on drawing wait for what they expect, not for a
fixed time.

It builds like `ios-uibutton.m`. For arm64:

```sh
clang -target arm64-apple-macos11.0 -fobjc-arc -isysroot $SDK \
  -F $SDK/System/iOSSupport/System/Library/Frameworks -F $SDK/System/Library/Frameworks \
  -iframework $SDK/System/Library/Frameworks/CoreServices.framework/Frameworks \
  -iframework $SDK/System/Library/Frameworks/ApplicationServices.framework/Frameworks \
  -c tests/ios-uikit-classes.m
clang -target arm64-apple-macos11.0 -fuse-ld=lld -nostdlib -Wl,-syslibroot,$R \
  -F $R/System/iOSSupport/System/Library/Frameworks -F $R/System/Library/Frameworks \
  -L $R/usr/lib ios-uikit-classes.o -framework UIKit -framework Foundation \
  -framework CoreFoundation -framework CoreGraphics -lobjc -lSystem -o uikit-classes
# then set LC_BUILD_VERSION's platform to 2 (iOS)
```

Getting these to work needed fixes that are not obvious:

- **Constraints to layout guides raised "Layout item is outside the view
  tree".** Cocotron's solver only collected views. It now gives each view's
  layout guides a rectangle and sets their frames. It also skips a
  constraint whose items are not all in the tree being solved, since iOS
  lays out only once the views are in place.
- **Views laid out from a main-queue block were drawn seconds late.**
  AppKit queues a redraw with a run loop timer. Queued from inside a
  callout, that timer does not wake the run loop, so the redraw waited for
  the next event. UIKit now draws what changed just before the main run
  loop sleeps, from an observer, as Core Animation does on iOS.
- **Solving constraints from `layoutIfNeeded` slowed everything.** The
  pass walks the whole window. UIKit now runs it only once some view has
  had a constraint installed, so apps without any, such as Cydia, never
  pay for it.
- **`UIImage`'s `CGImage` came back at the point size.** An image from a
  scale-2 context gave a CGImage half as wide as its pixels. `UIImage` now
  keeps the CGImage it was made from, or uses its bitmap's own.
