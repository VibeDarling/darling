# An iOS app on a phone host's display

`ios-pocket-display.m` is an iOS app run on AppKit's Pocket backend, the
display an Android host gives Darling (phase 3 of `docs/ios-pocket.md`).
`tools/pocket-host` stands in for the Android app. It listens on a Unix
socket, gives the app a 720x1280 screen at 2x with 48 pixels covered at the
top and 32 at the bottom, and shows the app's windows in a framebuffer.
`ios-pocket-display.sh` drives it with touches and input method text, as a
phone would, and reads pixels back.

```sh
gcc -O2 -o pocket-host tools/pocket-host/pocket-host.c tools/pocket-host/pocket-server.c -lz -lpthread
# build ios-pocket-display.m as ios-uikit-classes.m is built, mark it iOS
DARLING=darling tests/ios-pocket-display.sh ./pocket-host /path/in/prefix/pocket-display out
```

No X server is involved: `DARLING_POCKET_DISPLAY` makes AppKit use the
Pocket backend.

The app checks:

- `UIScreen` is the host's screen: 360x640 points at 2x, 720x1280 pixels.
- The safe area and the status bar come from the host's insets (24 and 16
  points), with no `DARLING_UISCREEN` or `DARLING_UISAFEAREA`.
- A tap on a button sends its action once.
- A drag begins where the finger went down, in the view's coordinates, and
  moves with it.
- Two fingers down at once are two touches in one event, and every finger
  ends.
- Input method text (`hello`) and the Delete key reach a text field (`hell`),
  and Return asks `textFieldShouldReturn:`.

The script checks what the host saw:

- the app connected and gave it one full-screen buffer at the screen's
  pixels;
- the pixels at a green view, a blue view and the white background are those
  colours (so what the app drew is shown where it drew it, at 2x);
- the app asked for the soft keyboard when the text field began editing, and
  let it go when Return ended editing.

It prints one PASS/FAIL line per check (15) and exits nonzero on any
failure. It leaves the host's screen in `out/pocket-display.png`.

Passes in an arm64 VM (Arch Linux ARM), 15/15. FileBrowser
(`/Applications/FileBrowser.app`) also runs on pocket-host there.

Fixes this needed that are not obvious:

- **AppKit's key bindings expect a backspace (0x08) from Delete**, which is
  what the X11 backend sends; macOS sends 0x7f. So the host sends key codes,
  and the backend supplies the characters of Delete, Return, Tab, Escape, the
  arrows and the like.
- **A UIWindow is never AppKit's key window** (it is borderless), so key
  events and the keyboard request go to the frontmost visible window when
  there is no key window.
- **A prefix's `/tmp` is the host's `/tmp`**, so the app and the host name
  the socket by the same path there.
