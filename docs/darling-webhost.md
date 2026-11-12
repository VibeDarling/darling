# darling-webhost

Darling's iOS `UIWebView` does not contain a web engine. Pages are rendered by
`darling-webhost`, a Linux program that runs beside Darling on the same X
display (`tools/darling-webhost`, built with WebKitGTK 4.1). On Android, the
same role would be played by the system WebView, inside the launcher.

The pieces:

- **iOS WebKit** (`src/private-frameworks/WebKitLegacy`): `WebCore.framework`
  and `WebKit.framework` under
  `/System/iOSSupport/System/Library/PrivateFrameworks`. These are the private
  frameworks iOS apps link. `WebView`, `WebFrame`, `WebDataSource` and
  `WebPreferences` keep each page's state and call the app's delegates.
  `WebScriptObject` and `WebUndefined` stand for JavaScript values.
- **UIKit's `UIWebView`**: it owns a `WebView`. It tells the `WebView` where
  the page goes, as an X11 window plus a rect, and whether it can be seen. It
  also turns WebKit's delegate calls into `UIWebViewDelegate` ones.
- **`darling-webhost`**: one WebKitGTK view per `WebView`. Each view is a
  `GtkPlug` inside an override-redirect X window that is reparented into the
  app's window, over the `UIWebView`.
- **`darling-webhost-extension.so`**: the web process extension. It connects
  back to the app, so pages and the app's Objective-C objects can call each
  other.

## Running

```sh
make -C tools/darling-webhost
DISPLAY=:0 tools/darling-webhost/darling-webhost &   # the display Darling uses
```

Apps find the host at `127.0.0.1:7690`, or at `DARLING_WEBHOST` (`host:port`)
in their environment. The host listens on `DARLING_WEBHOST_PORT`. It looks for
its extension next to its binary, or in `DARLING_WEBHOST_EXTENSIONS`.
`DARLING_WEBHOST_DEBUG=1` logs every message. Without a host, `UIWebView`
stays blank, and the app works otherwise.

## Protocol

Both connections carry newline-terminated JSON objects over TCP.

### Control connection (app ↔ host)

The app connects once and sends `{"op":"hello","bridge":PORT,"pid":N}`.
`PORT` is where the app's bridge listens (see below).

| App → host | |
|---|---|
| `create {view, ua}` | Makes a view. The host answers with event `created {view, page}`, where `page` is the WebKit page id that the bridge uses. |
| `embed {view, parent, x, y, w, h, visible}` | `parent` is the app's X11 window. The rect is in its coordinates, from the top left. |
| `load {view, url}`, `loadHTML {view, html, base}`, `loadData {view, data (base64), mime, encoding, base}` | Starts a load. |
| `reload {view, origin}`, `stop`, `back`, `forward`, `destroy`, `settings {view, ua}` | |
| `policy {req, use}` | Answers a `policy` event. |
| `scheme {req, status, mime, data}` or `scheme {req, error}` | Answers a `scheme` event. |
| `scheme-register {scheme}` | A URL scheme the app serves itself. Schemes of URLs the app loads are registered automatically. |

| Host → app | |
|---|---|
| `policy {view, req, url, method, type, main, target?}` | A navigation for the app to allow or refuse. `type` is one of `link`, `form`, `back`, `reload`, `resubmit` or `other`. A `target` means a new window. Since the host never opens one, the URL loads in the same view. |
| `started {view, url}`, `committed {view, url, mime}`, `finished {view}`, `failed {view, url, error, code, provisional}`, `title {view, title}` | Load progress. Every view event also carries `back` and `forward`, which say whether the view can go back or forward. |
| `scheme {req, url}` | A request for a scheme the app serves. The app loads it with `NSURLConnection`, so its `NSURLProtocol`s apply. |
| `alert {view, message}`, `close {view}` | Confirm and prompt dialogs are answered "yes" and with their default text. |

### Bridge (web process ↔ app)

The app listens on a loopback port. Each web process's extension connects to
it. Either side may send a request, `{"id":n,"op":...}`, at any time. The
answer is `{"re":n,"ok":value}` or `{"re":n,"err":"message"}`. While waiting
for an answer, each side serves the other's requests. So calls nest both ways,
as they do between WebKit and an app on iOS. The app serves the bridge on its
main thread.

Values are JSON, with these exceptions:

- `{"$u":1}` is `undefined`.
- `{"$n":"nan"|"inf"|"-inf"}` covers the numbers JSON lacks.
- `{"$js":n}` is a JavaScript object, kept by the extension. The app sees it
  as a `WebScriptObject`.
- `{"$oc":n}` is one of the app's Objective-C objects. Pages see it through a
  `Proxy`, and it is kept for the life of the app.
- `{"$a":[...]}` is an `NSArray`, which becomes a JavaScript array.
- `{"$m":1}` answers `get` when the name is a method.

| Extension → app | |
|---|---|
| `clear {page, main, window}` | A frame has a new window object. The app calls `webView:didClearWindowObject:forFrame:`. |
| `get {obj, key}`, `set {obj, key, value}`, `call {obj, key, args}` | A page uses an Objective-C object. Names follow WebKit's rules: `+webScriptNameForSelector:`, `+isSelectorExcludedFromWebScript:`, `-attributeKeys` or the instance variables, and `-invokeUndefinedMethodFromWebScript:withArguments:`. |

| App → extension | |
|---|---|
| `eval {page or obj, script}` | Evaluates `script` in the page, or in the global context of `obj`. |
| `window {page}` | The page's window object. |
| `get`, `set`, `remove {obj, key}`, `call {obj, name, args}`, `apply {obj, args}`, `index`, `setindex {obj, i, value}`, `string {obj}` | `WebScriptObject`'s methods. |

## What does not work

- `-[WebFrame globalContext]` and `-[WebScriptObject JSObject]` return NULL.
  The page's JavaScriptCore runs in another process.
- DOM objects (`DOMDocument` and the rest) are not provided.
- Requests the page makes do not go through the app's
  `webView:resource:willSendRequest:...`, so the app cannot add headers.
- Native page windows always draw above the app. `UIWebView` therefore hides
  the page while an alert or action sheet is up, and while the view is
  covered by a presented view controller.
