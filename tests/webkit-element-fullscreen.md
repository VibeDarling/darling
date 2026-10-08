# WebKit element fullscreen preference regression

Compile `webkit-element-fullscreen.m` against the built Foundation and WebKit
frameworks, then run it with the build-tree launcher and a private staged runtime:

```
DPREFIX=<private-prefix> DARLING_INSTALL_PREFIX=<image>/usr/local \
  <build>/src/startup/darling shell \
  /Volumes/SystemRoot/<absolute-path-to-test>
```

A passing run prints `RESULT failures=0` and exits 0. The baseline fails on the
missing public selector. The test follows YouLearn 0.3.1's configuration preferences
call, checks the documented false default, public and existing fullscreen accessor
consistency, KVC, and independent configuration state. No web service is needed.

Specification: WebKit OSS `Source/WebKit/UIProcess/API/Cocoa/WKPreferences.mm`
(`isElementFullscreenEnabled` and `setElementFullscreenEnabled:`), and Apple's
`WKPreferences.elementFullscreenEnabled` documentation. This test covers preference
state and startup compatibility, not fullscreen presentation by the host backend.
