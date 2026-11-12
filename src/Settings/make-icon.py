#!/usr/bin/env python3
# Draws Settings' icon: a gray gear on a lighter gray rounded square.
# Plain Python (zlib for PNG), no imaging library. The PNGs it writes are
# checked in next to it; run it again after changing the design:
#
#   python3 src/Settings/make-icon.py src/Settings
#
# It writes AppIcon60x60.png, @2x and @3x (60, 120 and 180 pixels), the
# names Info.plist's CFBundleIcons lists and SpringBoard looks for.

import struct
import sys
import zlib

SUPERSAMPLE = 4


def rounded_square(x, y, size, radius):
    """Whether point (x, y) of a size x size square lies inside it once
    its corners are rounded with the given radius."""
    cx = min(max(x, radius), size - radius)
    cy = min(max(y, radius), size - radius)
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2


import math


def shade(u, v):
    """The color at (u, v) in [0, 1) of the icon: RGBA, 0..255."""
    if not rounded_square(u, v, 1.0, 0.225):
        return (0, 0, 0, 0)
    # Background: light gray, darker at the bottom.
    top, bottom = (196, 198, 204), (142, 145, 152)
    bg = tuple(int(top[i] + (bottom[i] - top[i]) * v) for i in range(3))
    dx, dy = u - 0.5, v - 0.5
    r = (dx * dx + dy * dy) ** 0.5
    angle = math.atan2(dy, dx)
    # Twelve teeth: the gear's rim reaches further out over each tooth.
    tooth = math.cos(angle * 12) > 0.1
    outer = 0.39 if tooth else 0.31
    gear = (88, 90, 97)
    if r < 0.12:
        return bg + (255,)
    if r < 0.17:
        return gear + (255,)
    if r < 0.22:
        return tuple(min(255, c + 24) for c in bg) + (255,)
    if r < outer:
        return gear + (255,)
    return bg + (255,)


def render(size):
    rows = []
    n = SUPERSAMPLE
    for y in range(size):
        row = bytearray([0])  # filter: none
        for x in range(size):
            acc = [0, 0, 0, 0]
            for sy in range(n):
                for sx in range(n):
                    u = (x + (sx + 0.5) / n) / size
                    v = (y + (sy + 0.5) / n) / size
                    r, g, b, a = shade(u, v)
                    # Premultiply while averaging, so edges blend right.
                    acc[0] += r * a
                    acc[1] += g * a
                    acc[2] += b * a
                    acc[3] += a
            alpha = acc[3] / (n * n)
            if acc[3] == 0:
                row += bytes((0, 0, 0, 0))
            else:
                row += bytes((acc[0] // acc[3], acc[1] // acc[3], acc[2] // acc[3], int(round(alpha))))
        rows.append(bytes(row))
    return b"".join(rows)


def png(size, pixels):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)  # 8-bit RGBA
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(pixels, 9)) + chunk(b"IEND", b""))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for suffix, size in (("", 60), ("@2x", 120), ("@3x", 180)):
        path = "%s/AppIcon60x60%s.png" % (out, suffix)
        with open(path, "wb") as f:
            f.write(png(size, render(size)))
        print(path)


if __name__ == "__main__":
    main()
