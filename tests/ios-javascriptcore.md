# JavaScriptCore

`ios-javascriptcore.m` exercises `JavaScriptCore.framework`, which Darling
builds from `src/external/JavaScriptCore` (WebKit 608, the Safari 13 / iOS 13
era) when the `jsc` component is enabled (`-DCOMPONENTS=stock,jsc`, or `all`);
without it only a load-only placeholder is installed.

- C API: `JSEvaluateScript` and `JSCheckScriptSyntax`.
- Objective-C API: `JSContext` evaluation, Foundation objects into JS and JS
  arrays/objects back to Foundation, blocks called from JS with
  `+[JSContext currentArguments]`, calling a JS function from Objective-C,
  `JSExport` properties and methods and `JSExportAs`, and the exception
  handler.
- The language as embedders use it: JSON, RegExp, Date, a Promise job run
  after the script, and a timed fib(25).

Build it like any Darling test program, linking `-framework JavaScriptCore
-framework Foundation -framework CoreFoundation`. To test it as an iOS binary
on arm64, link it for macOS and set the `LC_BUILD_VERSION` platform to 2
(iOS). It prints one PASS/FAIL line per check and exits nonzero on any
failure. The C API check prints a console SyntaxError on purpose.

On a Raspberry Pi 4 it passes as an iOS binary with the JIT on; fib(25) takes
about 38 ms, and 144 ms with `JSC_useJIT=false` (LLInt only). It also passes
as a macOS binary on x86_64. Getting there needed fixes outside
JavaScriptCore:

- darling-libplatform: the arm64 `sys_icache_invalidate` came from XNU, which
  only invalidates the icache because Apple's cores are coherent. On the
  Cortex-A72 freshly JITed code was fetched stale and the process died with
  SIGILL before running any script. It now cleans the dcache first.
- darling-foundation: `GSI_MAP_NODE_IS_EMPTY` read map keys with the value's
  pointer functions, so JSC's wrapper cache (opaque keys, weak values) called
  `objc_loadWeak` on a `JSValueRef` and crashed on the first Foundation object
  passed into JS.
- darling-corefoundation: on x86_64, NSInvocation lost float and double
  results (JSExport methods go through it, so `p.length()` came back as
  garbage), treated 9-16 byte structs as stret, and the forwarding
  trampoline read xmm0 from its own saved frame pointer.

The public headers also needed `JSC_API_AVAILABLE` and friends defined for
clients (`API/WebKitAvailability.h`); before that no app could include
`<JavaScriptCore/JavaScriptCore.h>`.
