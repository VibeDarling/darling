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
