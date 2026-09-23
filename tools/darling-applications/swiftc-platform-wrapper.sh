#!/usr/bin/env bash
set -euo pipefail

target=host
previous=
for argument in "$@"; do
    if [[ "$previous" == -target ]]; then
        target=$argument
        break
    fi
    previous=$argument
done

if [[ -n "${VIBEDARLING_SWIFTC_TRACE:-}" ]]; then
    printf '%s\n' "$target" >> "$VIBEDARLING_SWIFTC_TRACE"
fi

if [[ "$target" == *apple-macos* ]]; then
    darwin_flags=("-I$VIBEDARLING_DARWIN_SWIFT_MODULES" "-I$VIBEDARLING_FOUNDATION_SWIFT_MODULES")
    if [[ -n "${VIBEDARLING_DARWIN_MODULEMAPS:-}" ]]; then
        IFS=: read -r -a module_maps <<< "$VIBEDARLING_DARWIN_MODULEMAPS"
        for module_map in "${module_maps[@]}"; do
            darwin_flags+=(-Xcc "-fmodule-map-file=$module_map")
        done
    fi
    exec "$VIBEDARLING_SWIFTC" "${darwin_flags[@]}" "$@"
fi
exec "$VIBEDARLING_SWIFTC" "$@"
