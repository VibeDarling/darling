#!/usr/bin/env python3
"""Generate terminating arm64 call loggers for evidence-identified functions.

Input records contain symbol, kind and evidence. Only kind=function produces
an entry point. Other exports remain unresolved. Generated files are scratch
artifacts, never repository inputs. No argument count or signature is inferred.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess


def name_information(symbol):
    if not re.fullmatch(r"_[A-Za-z0-9_$]+", symbol):
        raise ValueError("Unsupported symbol spelling")
    info = {"symbol": symbol, "signature_established": False}
    if symbol.startswith("_OBJC_CLASS_$_"):
        info.update(category="objc-class-data", name=symbol[len("_OBJC_CLASS_$_"):])
    elif symbol.startswith("_OBJC_METACLASS_$_"):
        info.update(category="objc-metaclass-data", name=symbol[len("_OBJC_METACLASS_$_"):])
    elif symbol.startswith(("_$s", "_$S", "__T")):
        info["category"] = "swift-mangled"
        demangler = shutil.which("swift-demangle")
        if demangler:
            info["demangled"] = subprocess.run(
                [demangler, "--compact", symbol[1:]], check=True,
                capture_output=True, text=True).stdout.strip()
        else:
            info["demangler"] = "unavailable"
    elif symbol.startswith("__Z"):
        info["category"] = "cxx-mangled"
    else:
        info["category"] = "unclassified"
    info["name_hints"] = [word for word in
                          ("Notification", "Identifier", "Key", "Bundle", "Get",
                           "Copy", "Create", "Set", "Is", "Main") if word in symbol]
    info["hints_establish_abi"] = False
    return info


LOGGER = r'''/* Diagnostic interpretations, not recovered argument types. */
extern int snprintf(char *, unsigned long, const char *, ...);
extern long write(int, const void *, unsigned long);
extern void _exit(int) __attribute__((noreturn));
typedef unsigned long long U64;
_Static_assert(sizeof(U64) == 8 && sizeof(double) == 8 && sizeof(float) == 4,
               "Requires 64-bit integers and IEEE binary32/binary64");
static void emit(const char *line, int n, unsigned long capacity) {
    if (n <= 0) _exit(79);
    unsigned long left = (unsigned long)n < capacity ? (unsigned long)n : capacity - 1;
    while (left) {
        long result = write(2, line, left);
        if (result <= 0) _exit(79);
        line += result;
        left -= (unsigned long)result;
    }
}
static void slot(const char *bank, unsigned int index, U64 bits) {
    union { U64 u; long long i; double d; unsigned int w[2]; float f[2]; } value;
    value.u = bits;
    char line[768];
    int n = snprintf(line, sizeof(line),
        "%s%u raw=0x%016llx u64=%llu i64=%lld u32=%u i32=%d "
        "u16=%u i16=%d u8=%u i8=%d pointer-bits=0x%016llx "
        "object=unverified-address f32=%a f64=%a\n",
        bank, index, bits, bits, value.i, value.w[0], (int)value.w[0],
        (unsigned int)(unsigned short)bits, (int)(short)bits,
        (unsigned int)(unsigned char)bits, (int)(signed char)bits,
        bits, (double)value.f[0], value.d);
    emit(line, n, sizeof(line));
}
__attribute__((noreturn)) void darling_raw_call_log(const char *symbol, const U64 *frame) {
    char line[512];
    int n = snprintf(line, sizeof(line),
        "Darling diagnostic call: %s; register interpretations only; "
        "argument count/types unknown; no memory dereferenced\n", symbol);
    emit(line, n, sizeof(line));
    for (unsigned int i = 0; i < 9; ++i) slot("x", i, frame[i]);
    slot("x", 20, frame[10]);
    slot("x", 21, frame[11]);
    n = snprintf(line, sizeof(line), "caller-lr=0x%016llx caller-sp=0x%016llx\n",
                 frame[12], frame[13]);
    emit(line, n, sizeof(line));
    for (unsigned int i = 0; i < 8; ++i) {
        n = snprintf(line, sizeof(line), "q%u raw128=0x%016llx%016llx\n",
                     i, frame[17 + i * 2], frame[16 + i * 2]);
        emit(line, n, sizeof(line));
        slot("v-low", i, frame[16 + i * 2]);
        slot("v-high", i, frame[17 + i * 2]);
    }
    _exit(78);
}
'''


def assembly_for(symbols, macho=True):
    lines = [".text", ".p2align 2"]
    logger = "_darling_raw_call_log" if macho else "darling_raw_call_log"
    for index, symbol in enumerate(symbols):
        name_information(symbol)
        lines += [f'.globl "{symbol}"', f'"{symbol}":', "sub sp, sp, #256"]
        for register in range(0, 8, 2):
            lines.append(f"stp x{register}, x{register + 1}, [sp, #{register * 8}]")
        lines += ["str x8, [sp, #64]", "stp x20, x21, [sp, #80]",
                  "str x30, [sp, #96]", "add x9, sp, #256", "str x9, [sp, #104]"]
        for register in range(0, 8, 2):
            lines.append(f"stp q{register}, q{register + 1}, [sp, #{128 + register * 16}]")
        if macho:
            lines += [f"adrp x0, Lname{index}@PAGE", f"add x0, x0, Lname{index}@PAGEOFF"]
        else:
            lines += [f"adrp x0, Lname{index}", f"add x0, x0, :lo12:Lname{index}"]
        lines += ["mov x1, sp", f"bl {logger}", "brk #0"]
    lines += [".section __TEXT,__cstring,cstring_literals" if macho else ".section .rodata"]
    for index, symbol in enumerate(symbols):
        lines += [f"Lname{index}:", f".asciz {json.dumps(symbol)}"]
    if not macho:
        lines.append('.section .note.GNU-stack,"",%progbits')
    return "\n".join(lines) + "\n"


def generate(records, output, macho=True):
    if output.exists():
        raise ValueError("Output already exists")
    functions = []
    annotations = []
    for record in records:
        info = name_information(record["symbol"])
        if record.get("kind") == "function":
            if not record.get("evidence") or info["category"].startswith("objc-"):
                raise ValueError("Callable exports require evidence and cannot be class data")
            functions.append(record["symbol"])
        annotations.append(dict(info, requested_kind=record.get("kind", "unknown"),
                                evidence=record.get("evidence"), library=record.get("library")))
    if len(set(functions)) != len(functions):
        raise ValueError("Duplicate function")
    output.mkdir(parents=True)
    (output / ".gitignore").write_text("*\n")
    (output / "names.json").write_text(json.dumps(annotations, indent=2) + "\n")
    (output / "logger.c").write_text(LOGGER)
    (output / "entries.S").write_text(assembly_for(functions, macho))
    return functions


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exports", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--elf", action="store_true", help="Native arm64 regression fixtures")
    args = parser.parse_args()
    generated = generate(json.loads(args.exports.read_text()), args.output, not args.elf)
    print(f"Generated {len(generated)} terminating function entry points")
