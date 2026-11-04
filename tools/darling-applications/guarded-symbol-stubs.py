#!/usr/bin/env python3
"""Generate bind-only diagnostic sources from an imported-guest scan report.

These are not API implementations. Each image refuses execution in its
initializer; opaque export addresses have no callable or data ABI contract.
Never commit the generated sources, manifest, scan report, or build output.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess


DIAGNOSTIC_EXIT_STATUS = 78


def validate_install_name(name):
    path = PurePosixPath(name)
    if (not name.startswith(("/System/", "/usr/")) or ".." in path.parts
            or any(ord(character) < 32 for character in name)):
        raise ValueError(f"Unsafe install name: {name!r}")
    return path


def source_for(install_name, symbols):
    validate_install_name(install_name)
    if not symbols or len(symbols) != len(set(symbols)):
        raise ValueError("Expected nonempty, distinct missing symbols")
    classes = set()
    opaque = []
    for symbol in symbols:
        if not re.fullmatch(r"_[A-Za-z0-9_$]+", symbol):
            raise ValueError(f"Unsupported export spelling: {symbol!r}")
        match = re.fullmatch(r"_OBJC_(?:META)?CLASS_\$_([A-Za-z_][A-Za-z0-9_]*)", symbol)
        if match:
            classes.add(match[1])
        elif symbol.startswith("_OBJC_"):
            raise ValueError(f"Unsupported Objective-C export: {symbol}")
        else:
            opaque.append(symbol)
    identity = hashlib.sha256(install_name.encode()).hexdigest()[:16]
    root = "DarlingDiagnosticUnavailable_" + identity
    diagnostic = json.dumps("Darling diagnostic stub: " + install_name +
                            " is not implemented; refusing execution.\n")
    lines = [
        "/* Generated diagnostic placeholders; do not commit. */",
        "extern long write(int, const void *, unsigned long);",
        "extern void _exit(int) __attribute__((noreturn));",
        "__attribute__((noreturn)) static void unavailable(void) {",
        f"    static const char message[] = {diagnostic};",
        "    write(2, message, sizeof(message) - 1);",
        f"    _exit({DIAGNOSTIC_EXIT_STATUS});",
        "}",
        "__attribute__((constructor)) static void guard(void) { unavailable(); }",
    ]
    if classes:
        lines += [f"__attribute__((objc_root_class)) @interface {root} {{ void *isa; }}",
                  "+ (void)initialize;", "@end", f"@implementation {root}",
                  "+ (void)initialize { unavailable(); }", "@end"]
        for name in sorted(classes):
            lines += [f"@interface {name} : {root} @end", f"@implementation {name} @end"]
    for index, symbol in enumerate(opaque):
        lines.append(f'__attribute__((used, visibility("default"))) '
                     f'unsigned char opaque_{index} __asm__("{symbol}");')
    return "\n".join(lines) + "\n"


def generate(scan, output, runtime_root, arch):
    report = json.loads(scan.read_text())
    if len(report) != 1:
        raise ValueError("Supply a filtered report for exactly one imported guest app")
    if output.exists():
        raise ValueError("Output must be absent; do not overwrite an existing experiment")
    missing = report[0]["missing"]
    if not missing:
        raise ValueError("Report contains no missing exports")
    modules = []
    sources = {}
    for install_name, symbols in sorted(missing.items()):
        relative = validate_install_name(install_name).relative_to("/")
        name = hashlib.sha256(install_name.encode()).hexdigest()[:16] + ".m"
        sources[name] = source_for(install_name, symbols)
        module = {"install_name": install_name, "source": name, "symbols": symbols}
        original = runtime_root / relative
        if original.exists():
            ids = subprocess.run(["llvm-objdump", "--macho", f"--arch={arch}",
                                  "--dylib-id", str(original)], check=True,
                                 capture_output=True, text=True).stdout.splitlines()
            ids = [line.strip() for line in ids if line.strip() and not line.endswith(":")]
            if len(ids) != 1 or ids[0] == install_name:
                raise ValueError(f"Cannot safely overlay existing canonical image: {install_name}")
            canonical = validate_install_name(ids[0]).relative_to("/")
            if not (runtime_root / canonical).is_file():
                raise ValueError(f"Missing original canonical dependency: {ids[0]}")
            module["reexport"] = str(runtime_root / canonical)
        modules.append(module)
    output.mkdir(parents=True)
    (output / ".gitignore").write_text("*\n")
    for name, source in sources.items():
        (output / name).write_text(source)
    manifest = {"diagnostic_only": True, "exit_status": DIAGNOSTIC_EXIT_STATUS,
                "scan_sha256": hashlib.sha256(scan.read_bytes()).hexdigest(),
                "arch": arch, "runtime_root": str(runtime_root.resolve()), "modules": modules}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Generated {len(modules)} guarded images covering "
          f"{sum(len(m['symbols']) for m in modules)} requested exports")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scan", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runtime-root", type=Path, required=True)
    parser.add_argument("--arch", choices=("arm64", "arm64e", "x86_64"), default="arm64")
    args = parser.parse_args()
    generate(args.scan, args.output, args.runtime_root, args.arch)


if __name__ == "__main__":
    main()
