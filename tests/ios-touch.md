# Touch screens

`ios-touch.m` reports fingers to AppKit the way a windowing backend does,
with `NSTouchPost` (AppKit's `NSTouch.h`). They go through the event queue
and `NSWindow` to UIKit's views and gesture recognizers. It checks:

- **One finger** begins, moves and ends in the view under it, at the right
  place in the view's coordinates. A quick second tap counts two
  (`tapCount`).
- **Several fingers.**
  - A view with `multipleTouchEnabled` gets both fingers, and the event
    holds both. The finger that did not move is stationary.
  - A view without it gets only the first finger.
  - An `exclusiveTouch` view's finger shuts out another view's.
  - Cancelling (`NSTouchCancelAll`, as when a compositor takes the screen)
    cancels the view's touch.
- **Gesture recognizers.**
  - A two-finger tap recognizes, and a one-finger tap on the same view does
    not take it; one finger still taps the one-finger tap.
  - **Pinch:**
    - fingers moving to twice the distance scale by two;
    - begin, change and end;
    - cancel the view's touch;
    - after the app resets `scale` to 1, changes count from there.
  - **Rotation:** a quarter turn clockwise on screen is +π/2.
  - **Pan:** a two-finger pan ignores one finger and moves by the distance
    two fingers moved. A finger joining a pan does not make it jump.
- **Controls:** a finger taps a `UIButton`.
- **Plain AppKit views:** a view that takes no touches gets the first
  finger as the mouse, and a double tap is a double click. An AppKit view
  that asks for direct touches (`allowedTouchTypes`) gets `NSTouch`es.
- **The mouse** still works as one finger.

It prints one PASS/FAIL line per check and exits nonzero on any failure.

With `DARLING_TOUCH_SCREEN=1` it waits for real fingers instead. A full
screen view with a pinch and a two-finger tap prints what it gets, and the
test exits once it has seen both, or after two minutes. That is how the X11
path was tested in an arm64 VM:
- Xorg with the dummy video driver, taking its input from udev;
- a uinput touch screen (multitouch protocol B, `INPUT_PROP_DIRECT`), made
  with python-evdev;
- libinput, which reports it to the server as an XInput 2.2 direct touch
  device.

It builds like `ios-uikit-classes.m` (see `ios-uikit-classes.md`), with
`-framework AppKit` added for `NSTouchPost`.

## How fingers get there

- **X11:** the backend loads libXi when the display opens. It selects
  XInput 2.2 touch events on its windows and reports each
  `XI_TouchBegin`/`Update`/`End`.
  - A server without XInput 2.2 (such as Xvfb), or a host without libXi,
    just has no touches.
  - Selecting touch events stops the pointer events the server would
    otherwise emulate for that window. AppKit's router therefore moves the
    mouse itself.
- **Wayland:** the backend binds `wl_touch` when the seat has one.
  Compositors emulate no pointer from a touch screen, so before this a
  finger did nothing.
- **AppKit:** `NSTouchPost` hit-tests a finger when it begins, and only the
  view under it decides where it goes:
  - If that view's `allowedTouchTypes` include `NSTouchTypeMaskDirect`
    (every UIView), the finger goes there as `NSEventTypeDirectTouch`
    events (`touchesBeganWithEvent:` …).
  - Otherwise the first finger becomes the left mouse button. These are
    queued as mouse events, so a control's tracking loop, which asks only
    for mouse events, sees them.
  - An AppKit view inside a UIView, such as a text field, still gets the
    mouse.
- **UIKit:** each finger is a `UITouch`. One `UIEvent` holds all the
  fingers down. Recognizers see only the fingers that began on their view
  or the views it is in. A recognizer that recognizes cancels the view's
  touches for its fingers.

Fixes this needed that are not obvious:

- `NSEventMaskFromType` shifted a 32-bit `1` by the event type, and
  `NSAnyEventMask` was 32 bits wide. Touch events (type 37) matched no
  mask, so no run loop would have dequeued them.
- `UIPanGestureRecognizer` uses the fingers' centroid, which jumps when a
  finger joins or leaves. The pan moves its start point by the jump.
