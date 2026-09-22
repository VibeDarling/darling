#!/usr/bin/env python3
"""
Fix Mach-O binaries produced by the Zig compiler for aarch64-macos.

Zig's Mach-O linker (as of Zig 0.16) emits 0x0 for the lazy_binding_info
offsets inside the __TEXT,__stub_helper section, causing all lazy-bound symbols
to bind to the very first entry in the lazy bind table. This script:
  1. Locates the __TEXT,__stub_helper section precisely via LC_SEGMENT_64 headers.
  2. Parses the true symbol offsets from the lazy_bind opcode stream (LC_DYLD_INFO_ONLY).
  3. Patches each stub helper entry within __stub_helper in-place with bounds checking.
"""

import sys
import struct

def read_uleb128(data: bytes, pos: int) -> tuple[int, int]:
    result = 0
    shift = 0
    while pos < len(data):
        byte = data[pos]
        pos += 1
        result |= (byte & 0x7f) << shift
        shift += 7
        if not (byte & 0x80):
            break
    return result, pos

def read_sleb128(data: bytes, pos: int) -> tuple[int, int]:
    result = 0
    shift = 0
    while pos < len(data):
        byte = data[pos]
        pos += 1
        result |= (byte & 0x7f) << shift
        shift += 7
        if not (byte & 0x80):
            if byte & 0x40:
                result |= -(1 << shift)
            break
    return result, pos

def fix_macho(path: str) -> None:
    with open(path, "rb") as f:
        d = bytearray(f.read())

    if len(d) < 32 or d[:4] != b"\xcf\xfa\xed\xfe": # MH_MAGIC_64
        print(f"{path}: not a 64-bit Mach-O binary, skipping", file=sys.stderr)
        return

    magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved = struct.unpack("<IIIIIIII", d[:32])
    if cputype != 0x0100000c: # CPU_TYPE_ARM64
        print(f"{path}: not an arm64 Mach-O binary, skipping", file=sys.stderr)
        return

    off = 32
    lazy_off, lazy_size = 0, 0
    stub_helper_off, stub_helper_size = 0, 0

    for _ in range(ncmds):
        if off + 8 > len(d):
            break
        cmd, cmdsize = struct.unpack("<II", d[off:off+8])

        if cmd in (0x22, 0x80000022): # LC_DYLD_INFO or LC_DYLD_INFO_ONLY
            if off + 48 <= len(d):
                _, _, _, _, _, _, lazy_off, lazy_size, _, _ = struct.unpack("<IIIIIIIIII", d[off+8:off+48])

        elif cmd == 0x19: # LC_SEGMENT_64
            if off + 72 <= len(d):
                nsects = struct.unpack("<I", d[off+64:off+68])[0]
                sect_off = off + 72
                for _s in range(nsects):
                    if sect_off + 80 > len(d):
                        break
                    sname = d[sect_off:sect_off+16].split(b"\x00", 1)[0].decode("ascii", errors="ignore")
                    smegname = d[sect_off+16:sect_off+32].split(b"\x00", 1)[0].decode("ascii", errors="ignore")
                    offset = struct.unpack("<I", d[sect_off+48:sect_off+52])[0]
                    size = struct.unpack("<Q", d[sect_off+40:sect_off+48])[0]
                    if smegname == "__TEXT" and sname == "__stub_helper":
                        stub_helper_off = offset
                        stub_helper_size = size
                    sect_off += 80

        off += cmdsize

    if lazy_off == 0 or lazy_size == 0:
        print(f"{path}: no lazy binding info found, skipping", file=sys.stderr)
        return

    if stub_helper_off == 0 or stub_helper_size == 0:
        print(f"{path}: no __TEXT,__stub_helper section found, skipping", file=sys.stderr)
        return

    # Parse symbol offsets from lazy_bind opcode stream
    offsets = [0]
    pos = 0
    stream = bytes(d[lazy_off:lazy_off+lazy_size])
    while pos < len(stream):
        b = stream[pos]
        opcode = b & 0xf0
        pos += 1

        if opcode in (0x00, 0x10, 0x30, 0x50):
            # DONE, SET_DYLIB_ORDINAL_IMM, SET_DYLIB_SPECIAL_IMM, SET_TYPE_IMM (no payload)
            pass
        elif opcode == 0x20: # SET_DYLIB_ORDINAL_ULEB
            _, pos = read_uleb128(stream, pos)
        elif opcode == 0x40: # SET_SYMBOL_TRAILING_FLAGS_IMM
            while pos < len(stream) and stream[pos] != 0:
                pos += 1
            pos += 1 # skip null terminator
        elif opcode == 0x60: # SET_ADDEND_SLEB
            _, pos = read_sleb128(stream, pos)
        elif opcode in (0x70, 0x80): # SET_SEGMENT_AND_OFFSET_ULEB, ADD_ADDR_ULEB
            _, pos = read_uleb128(stream, pos)
        elif opcode == 0x90: # DO_BIND
            # In lazy binding stream, a DO_BIND is typically followed by DONE (0x00)
            if pos < len(stream) and stream[pos] == 0x00:
                pos += 1
            # Next symbol binding opcode sequence begins after trailing padding
            while pos < len(stream) and stream[pos] == 0x00:
                pos += 1
            if pos < len(stream):
                offsets.append(pos)

    # Search for stub helpers ONLY within the __TEXT,__stub_helper section
    section_end = min(len(d), stub_helper_off + stub_helper_size)
    h_pos = stub_helper_off
    idx = 0
    fixed_count = 0

    while h_pos + 12 <= section_end:
        # Match ARM64 pattern: ldr w16, #offset (50 00 00 18)
        if d[h_pos:h_pos+4] == b"\x50\x00\x00\x18":
            # Match following unconditional branch: b <helper_entry> (14 .. .. ..)
            if (d[h_pos+7] & 0xfc) == 0x14:
                target_off_pos = h_pos + 8
                if target_off_pos + 4 <= section_end and idx < len(offsets):
                    real_val = offsets[idx]
                    struct.pack_into("<I", d, target_off_pos, real_val)
                    fixed_count += 1
                    idx += 1
                h_pos += 12
                continue
        h_pos += 4

    with open(path, "wb") as f:
        f.write(d)
    print(f"{path}: fixed {fixed_count} stub helper entries (out of {len(offsets)} symbols in __stub_helper)")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <macho-binary>...", file=sys.stderr)
        sys.exit(1)
    for p in sys.argv[1:]:
        fix_macho(p)
