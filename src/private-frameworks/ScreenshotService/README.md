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

In an isolated prefix, Screenshot.app exited 0 on its first invocation with
the service, but displayed no window. A second invocation failed with
`Connection invalid`: `bootstrap_look_up` returned `BOOTSTRAP_NO_MEMORY`
(1105) even though launchd still listed the service process. The service did
not receive the second connection. This repeat-connection failure must be
resolved before the service can be considered reliable.
