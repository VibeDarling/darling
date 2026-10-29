# pocket-host

A phone host for AppKit's Pocket backend, on Linux. It does what the Android
app's display does: it gives apps a screen, shows their windows, and sends
them touches, keys and input method text. Here the screen is a framebuffer
in memory and input comes from commands on stdin, so tests can drive an app
and look at what it drew.

```sh
gcc -O2 -o pocket-host pocket-host.c pocket-server.c -lz -lpthread
./pocket-host /tmp/pocket.sock 750x1334@2 88,0,68,0
darling shell env DARLING_POCKET_DISPLAY=/tmp/pocket.sock /Applications/X.app/X
```

The arguments are the socket, the screen in pixels with its scale, and the
pixels a notch and a home indicator cover (top, left, bottom, right). The
commands are listed at the top of `pocket-host.c`: `tap`, `down`, `move`,
`up`, `drag`, `text`, `key`, `screen`, `pixel`, `shot` and `quit`.

The protocol is
`src/external/cocotron/AppKit/Pocket.backend/PocketProtocol.h`. Each window
is a shared memory buffer the app passes over the socket. The host copies a
frame out of it when the app presents one, then releases it. The Android app
copies into its `SurfaceView`'s buffer instead.

`pocket-server.c` is the host's side of the protocol: windows, frames,
compositing and input. `pocket-host.c` is its command line, and the Android
app's display (darling-pocket's `native/pocket-display.c`) is built from the
same file.
