# Nibs and storyboards

`ios-nib.m` loads compiled nibs and a compiled storyboard, as Xcode builds
them for iOS 6 and later (ibtool's NIBArchive format). Xcode is not needed:
`ios-nib-make.py` writes the test's interface files in that format, and the
same loader was checked against real apps' nibs (below).

```sh
python3 tests/ios-nib-make.py NibTest.app   # Info.plist, *.nib, Main.storyboardc, dot.png
# build ios-nib.m as ios-uikit-classes.m is built, into NibTest.app/NibTest,
# set its platform to iOS, then run NibTest.app/NibTest under Darling
```

It checks:

- **A view controller's view from its nib** (`initWithNibName:bundle:`), and
  from a nib named after its class when it has no nib name ("NibAuto" for
  NibAutoController).
- **The archived properties.** The view's frame comes from its bounds and
  center, and its subviews are added in order. Also checked:
  - a named system color;
  - a label's text, font, color, line count, alignment and tag;
  - a system button's type and title;
  - a text field's placeholder and border;
  - a switch that is on;
  - an image named in the nib (`UIImageNibPlaceholder`);
  - a toolbar and its bar button items.
- **Connections.** File's Owner gets its outlets. Actions reach their
  targets: a button's action through `UIEventMask`, and a bar button
  item's through its target and action.
- **An app's own class** (`UIClassSwapper`) is made with `initWithCoder:`
  and never `initWithFrame:`, as on iOS. Its `awakeFromNib` comes after
  every outlet is connected.
- **Constraints.** One is installed on its view, and laying out moves the
  label to it.
- **Cells.** `registerNib:forCellReuseIdentifier:` gives cells of the nib's
  class, with their outlets inside the nib's content view.
- **`-[NSBundle loadNibNamed:owner:options:]`** returns the top-level
  objects without the placeholders.
- **A storyboard:**
  - Info.plist's `UIMainStoryboardFile` makes the window and its root view
    controller before `didFinishLaunching`, then shows the window.
  - The entry point knows its storyboard, and its view comes from the
    scene's view nib.
  - A button connected to a segue runs `prepareForSegue:sender:` and then
    presents the destination. `performSegueWithIdentifier:sender:` does the
    same.
  - `instantiateViewControllerWithIdentifier:` returns a scene whose view
    is archived with its controller. An unknown identifier raises.

It prints one PASS/FAIL line per check (34) and exits nonzero on any
failure.

With `DARLING_NIB_FILES=a.nib:b.nib` it loads those nibs instead, with an
owner that takes any outlet. For each nib it prints the top-level objects,
how many views they hold, and how many outlets reached File's Owner. Every
compiled nib in FileBrowser and Filza loads this way, in an arm64 VM. The
apps' own classes are not linked into the test, so they come out as the
UIKit classes they derive from.

## How it works

`UINib.m` reads the archive lazily. An object is made when something
decodes it, so the accessibility and trait tables, which nothing asks for,
are never made.
- **Collections, strings, numbers, attributed strings and paragraph
  styles** are made by the decoder.
- **`UIProxyObject`s** are the owner, the first responder or the external
  objects the caller gives.
- **Every other object** is allocated, recorded (so objects that refer back
  to it get it), and sent `initWithCoder:`.

UIKit's classes read their own keys:
- **`-[UIView initWithCoder:]`** runs the nearest UIKit class's designated
  initializer, not an app's override. `UIKitOwnImplementation` finds it by
  the class's image.
- **`-uikitDecodeNib:`** is then chained up the class hierarchy, so each
  UIKit class reads the keys it archives.
- **View controllers** do the same with `initWithNibName:bundle:`.

Once everything is made, the connections are made, then each object
(placeholders aside) gets `awakeFromNib`.

A storyboard is a directory: `Info.plist`, which maps identifiers to nibs
and names the entry point, and one nib per scene.
- **The scene's nib** connects its view controller to File's Owner (a
  `UIStoryboardScene`) and to the storyboard (`UIStoryboardPlaceholder`).
- **The view controller's view** is a second nib. It refers to the scene's
  objects, such as segue templates, through
  `UIExternalObjectsTableForViewLoading`. A button's action is a template's
  `perform:`.
- **Relationship segues** (a navigation controller's root) run when the
  scene is made. **Embed segues** run when its view loads.

Not verified against Xcode's output: storyboards with navigation or tab bar
controllers, since no app at hand has one. The relationship and embed
templates follow the shape of the others.
