# Screenshot XPC bootstrap

macOS 26 Screenshot.app sends an asynchronous request to
`com.apple.systemuiserver.screencapture` with this dictionary:

```
message: uint64 1
nowait: true
args: ["-uUpi"]
```

It accepts an empty dictionary as a reply. This service implements that XPC
handshake only. It does not display the capture controls or create an image.
Darling currently lacks a screen capture backend for this service; its
`CGDisplayCreateImage` and `CGWindowListCreateImage` entry points are stubs.

In an isolated prefix, Screenshot.app exited 0 with this service, but displayed
no window. Repeated invocations require Darling launchd commit `8644815fb`
(`fix/bootstrap-repeated-lookup`). Without that fix, `bootstrap_look_up`
returns `BOOTSTRAP_NO_MEMORY` (1105) for the second client because launchd
cannot create its anonymous job from the guest PID. With the launchd fix,
two consecutive Screenshot invocations returned an empty reply and exited 0.
