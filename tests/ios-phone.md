# The phone a host gives UIKit

`ios-phone.m` runs as a phone host would start an app. The screen and its
edges come from the environment:

- `DARLING_UISCREEN=375x667@2`: the screen's size in points, and its scale.
- `DARLING_UISAFEAREA=44,0,34,0`: the points a notch and a home indicator
  cover at the top, left, bottom and right.

Without them, UIKit uses AppKit's screen at scale 1, with a 20-point status
bar and no other insets.

It checks:

- `UIScreen`'s bounds, scale and native bounds.
- The status bar is as tall as the notch.
- The safe area, which depends on where each view is in its window:
  - a full-screen view's is the notch and the home indicator;
  - a view clear of the edges has none;
  - a view over the home indicator has only the part it covers;
  - a view pinned to `safeAreaLayoutGuide` lies inside it.

Then it shows a `UITextField` and a `UISearchBar`, and prints
`ready field X Y search X Y` (screen coordinates). The test's runner then
taps the field and types `hello`, presses Return, then taps the search bar
and types `abc`. Each key goes through the X server to AppKit's text system,
as the host keyboard's keys do. It checks:

- the text reached the field;
- the field's delegate heard editing begin;
- the delegate was asked before each change
  (`textField:shouldChangeCharactersInRange:replacementString:`);
- each change sent `UIControlEventEditingChanged`;
- Return asked `textFieldShouldReturn:`;
- the search bar has the text, and its delegate got
  `searchBar:textDidChange:`.

Run in an arm64 VM with Xvfb and xdotool:

```sh
DISPLAY=localhost:78 darling shell env DARLING_UISCREEN=375x667@2 DARLING_UISAFEAREA=44,0,34,0 phone > phone.out &
# wait for "ready field X Y search X Y" in phone.out, then:
DISPLAY=:78 xdotool mousemove $FX $FY click 1; xdotool type --delay 200 hello; xdotool key Return
DISPLAY=:78 xdotool mousemove $SX $SY click 1; xdotool type --delay 200 abc
```

It prints one PASS/FAIL line per check (14) and exits nonzero on any
failure. It builds like `ios-uikit-classes.m`.

Fixes this needed that are not obvious:

- **A view resized with `setFrame:` was not laid out again.** Only
  `-setFrameSize:` did that. So a search bar's text field kept the zero size
  it had when it was made: it drew no placeholder and took no taps. This is
  why typing never reached Cydia's search bar.
- **The field editor asks its delegate before each change.** That delegate
  is the AppKit field inside the `UITextField`, which asked no one. UIKit's
  own field classes now pass the question to the text field's delegate.
