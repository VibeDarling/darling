# Cydia Substrate

`ios-substrate.m` checks Darling's Cydia Substrate (`src/CydiaSubstrate`):

- **MSHookFunction** on arm64 functions that start with each kind of
  instruction that addresses relative to pc: `b`, `bl`, `b.cond`, `cbz`,
  `tbz`, `adr`, `adrp`, and `ldr` literals into w, x and d registers. Each is
  hooked twice: once by a replacement within reach of `b`, which patches one
  instruction, and once through a stub far away, which patches four. The
  hooked function must return the replacement's result and the trampoline
  the original's. It also hooks a hooked function, and `getppid` in
  libSystem.
- **MSHookMessageEx** on a method of the class itself, an inherited one (the
  superclass keeps its own), a class method, and a missing one.
- **MSGetImageByName** by path, by an iOS framework path
  (`/System/Library/Frameworks/UIKit.framework/UIKit`, which lives under
  `/System/iOSSupport` here), and for an image that isn't loaded.
  **MSFindSymbol** of a local symbol, in any image, and of a missing one.
- **MSHookMemory** on read-only data.
- **SubstrateLoader**, through the tweaks built from `ios-substrate-tweak.m`.
  UIKit loads it before the app's own initializers run. A tweak whose filter
  names the executable hooks a method and a function of the app. A `Mode
  Any` tweak loads on its `Classes` match, and a tweak for `com.apple.UIKit`
  and one with a `CoreFoundationVersion` range load too. A tweak whose
  `Bundles` don't match isn't loaded, and neither is a dylib without a plist.
  With `_MSSafeMode=1` nothing loads.

It prints one PASS/FAIL line per check (45 in all) and exits nonzero on any
failure. Run it once normally and once with `_MSSafeMode=1`.

## Building

Build it as an arm64 iOS binary named `substrate-test`: link it for macOS
with `-framework UIKit -framework Foundation -framework CydiaSubstrate`, set
the `LC_BUILD_VERSION` platform to 2, and change the UIKit load command to
`/System/Library/Frameworks/UIKit.framework/UIKit`. Build each tweak from
`ios-substrate-tweak.m` as a dylib with one of these defines, and put it in
`/Library/MobileSubstrate/DynamicLibraries` with a plist of the same name:

| Define          | Dylib                  | Filter                                                    |
|-----------------|------------------------|-----------------------------------------------------------|
| `TWEAK_MAIN`    | `SubstrateTest`        | `Executables` = (`substrate-test`)                        |
| `TWEAK_ANY`     | `SubstrateTestAny`     | `Mode` = `Any`, `Executables` = (`no-such-program`), `Classes` = (`STTweakTarget`) |
| `TWEAK_WRONG`   | `SubstrateTestWrong`   | `Bundles` = (`com.example.nothing`), `Executables` = (`substrate-test`) |
| `TWEAK_UIKIT`   | `SubstrateTestUIKit`   | `Bundles` = (`com.apple.UIKit`)                           |
| `TWEAK_VERSION` | `SubstrateTestVersion` | `CoreFoundationVersion` = (100.0), `Executables` = (`substrate-test`) |
| `TWEAK_NOPLIST` | `SubstrateTestNoPlist` | no plist                                                  |

Remove the tweaks afterwards: the UIKit one loads into every app.

`MSHookFunction` patches arm64 code only, since tweaks are built for arm64;
on x86_64 it logs and returns `NULL` as the original. The rest works there
too.
