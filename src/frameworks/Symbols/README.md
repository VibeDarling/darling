# Swift source candidate

`src/Symbols.swift` supplies the historically demanded automatic, bounce,
replace and variable-color values, marker conformances and composed configuration.
It is independent source for compiling clients, not a replacement for the
framework selected by CMake. CMake still builds `Symbols.S`.

Configuration stores explicit modifier choices. An absent choice requests no
override; it does not claim an undocumented default direction or scope.
This is Darling's representation, not Apple's private data layout. No renderer
currently consumes it. Additional effect variants and repeat/speed options remain
separate API work.

Specification: Apple's public SymbolEffect, BounceSymbolEffect,
VariableColorSymbolEffect and ReplaceSymbolEffect documentation (clean-room rung 3).
The variable-color cumulative and iterative modifiers cancel each other; modifiers
on independent dimensions preserve each other. Hashable and Sendable and marker
conformances follow those public type declarations.

For a native source regression, compile with a Swift compiler and a fresh output
directory `$OUT`:

```sh
swiftc -emit-library -emit-module -enable-testing -module-name Symbols \
  -emit-module-path "$OUT/Symbols.swiftmodule" src/Symbols.swift \
  -o "$OUT/libSymbols.so"
swiftc -I "$OUT" -L "$OUT" -lSymbols ../../../tests/symbols-configurations.swift \
  -o "$OUT/test"
LD_LIBRARY_PATH="$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$OUT/test"
```

Darwin compilation needs a provenance-known Swift resource directory and Darling
SDK. Use `-enable-library-evolution` for that module. Run source-built clients
before considering runtime selection. Integration into the normal build,
precompiled-application compatibility and actual SwiftUI rendering are unverified;
no assembly/runtime replacement is authorized by this source candidate alone.

## Explicit Darwin framework recipe

`build-source.py` builds the candidate without installing it. Supply every
platform/compiler input explicitly; the output must be a new durable directory.
For example, with paths from your private build:

```sh
python3 build-source.py --swiftc "$SWIFTC" --clang "$CLANG" \
  --target arm64-apple-macosx14.0 --minimum-os 14.0 \
  --module-triple arm64-apple-macos --sdk "$SDK" \
  --resources "$RESOURCES" --guest-root "$GUEST_ROOT" --output "$OUTPUT"
```

The output is a canonical `Symbols.framework` with a versioned binary,
architecture-specific Swift module/interface and normal framework symlinks.
The install name is
`/System/Library/Frameworks/Symbols.framework/Versions/A/Symbols`.
Compiler/link commands and logs remain in the output directory.
`--enable-testing` is only for the internal configuration regression.
Compile and link clients against this module and framework together.
Commit the recipe/source before staging an artifact into an owned runtime.
Export-name coverage is an interface check; it does not establish witness-table
compatibility with precompiled Apple clients or functioning symbol rendering.
