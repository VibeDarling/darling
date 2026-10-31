#!/usr/bin/env python3
# Marks a 64-bit Mach-O as built for iOS: rewrites the platform and minimum
# OS of its LC_BUILD_VERSION in place. Darling's build links everything for
# macOS, and ld64 refuses a second -platform_version (it takes that for a
# "zippered" Mac Catalyst binary), so iOS apps are marked after linking.
#
#   set-ios-platform.py BINARY [MINIMUM_OS]   (default 14.0)

import struct
import sys

LC_BUILD_VERSION = 0x32
PLATFORM_IOS = 2


def main():
    path = sys.argv[1]
    major, minor = (int(part) for part in (sys.argv[2] if len(sys.argv) > 2 else "14.0").split(".")[:2])
    with open(path, "rb") as f:
        data = bytearray(f.read())
    if struct.unpack_from("<I", data, 0)[0] != 0xFEEDFACF:
        sys.exit("%s: not a 64-bit Mach-O" % path)
    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, offset)
        if cmd == LC_BUILD_VERSION:
            struct.pack_into("<II", data, offset + 8, PLATFORM_IOS, (major << 16) | (minor << 8))
            with open(path, "wb") as f:
                f.write(data)
            return
        offset += size
    sys.exit("%s: no LC_BUILD_VERSION" % path)


if __name__ == "__main__":
    main()
