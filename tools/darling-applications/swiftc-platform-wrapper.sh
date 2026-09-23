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
    exec "$VIBEDARLING_SWIFTC" \
        "-I$VIBEDARLING_DARWIN_SWIFT_MODULES" \
        "-I$VIBEDARLING_FOUNDATION_SWIFT_MODULES" \
        "$@"
fi
exec "$VIBEDARLING_SWIFTC" "$@"
