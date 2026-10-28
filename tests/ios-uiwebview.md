# UIWebView

`ios-uiwebview.m` exercises the UIKit that Cydia-style apps are built from,
and `UIWebView` over [darling-webhost](../docs/darling-webhost.md):

- A tab bar controller over a navigation controller over a table of 500 rows.
  The table must keep only the visible cells, and must reuse them when
  scrolled to row 200. A view controller is then pushed onto the stack.
- A `UIWebView` subclass that exposes an Objective-C object as
  `window.bridge` in `-webView:didClearWindowObject:forFrame:`, as Cydia
  exposes `window.cydia`. The page calls a method (`add(2, 3)`), gets an
  `NSArray` back, passes a string in and reads a property. Then Objective-C
  reads the result with `stringByEvaluatingJavaScriptFromString:` and calls a
  page function with `-[WebScriptObject callWebScriptMethod:withArguments:]`.

It prints one PASS/FAIL line per check and exits nonzero on any failure. It
stays up three seconds after the checks, for a screenshot.

On x86_64 it runs as a Mac Catalyst binary:

```sh
clang -target x86_64-apple-macos11.0 -fobjc-arc -isysroot $SDK \
  -F $SDK/System/iOSSupport/System/Library/Frameworks -F $SDK/System/Library/Frameworks \
  -I src/private-frameworks/WebKitLegacy/include -c tests/ios-uiwebview.m
clang -target x86_64-apple-macos11.0 -fuse-ld=lld -nostdlib -Wl,-syslibroot,$R \
  -F $R/System/iOSSupport/System/Library/Frameworks -F $R/System/iOSSupport/System/Library/PrivateFrameworks \
  -F $R/System/Library/Frameworks -L $R/usr/lib ios-uiwebview.o -framework UIKit -framework WebCore \
  -framework Foundation -framework CoreFoundation -framework CoreGraphics -lobjc -lSystem -o uiweb
# then set LC_BUILD_VERSION's platform to 6 (Mac Catalyst)
```

Start `darling-webhost` on the display the app will use, for example an
`Xvfb :121 -listen tcp`. Run the app with `DISPLAY=localhost:121`, since
inside Darling the X server is reached over TCP. All 12 checks pass. The page
draws between the navigation bar and the tab bar.

Getting there needed two things that are not obvious:

- **No JavaScriptCore in the host's UI process.** A `JSCContext` created there
  stops WebKitGTK from loading anything. The host parses JSON with json-glib;
  the web process extension uses JavaScriptCore.
- **Override-redirect containers.** Cocotron selects SubstructureRedirect on
  its windows, which makes it the window manager for their children. Map and
  configure requests for a child window are then handed to Cocotron, which
  drops them. The host's container window is override-redirect, so its
  requests go straight to the X server.
