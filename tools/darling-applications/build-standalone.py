#!/usr/bin/env python3
"""Build the native Applications viewer against a verified Darling image.

This intentionally does not configure Darling or rebuild dependencies.  It
reuses only the recorded compile/link variables from the integration17 image,
rewriting every old-tree path to that image and emitting a private bundle.
"""
import hashlib, json, os, re, shlex, shutil, subprocess, sys
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "src/darling-applications/main.m"
PLIST = SOURCE.with_name("Info.plist")
IMAGE = Path("/home/cristi/src/darling-integration17")
BUILD = IMAGE / "build"
VARS = Path("/home/cristi/src/darling-gui/privbuild/wayland/apps")
OUTPUT = Path(os.environ.get("DARLING_VIEWER_OUTPUT", "/home/cristi/.local/share/darling/macos-apps/builds/darling-applications-integration17"))
EXPECTED_SOURCE = "fb9b7fb33f0359a2120ed990f501a50d222751e13c80f0f9c66c1c9453232092"

def load(path):
    result = {}
    for line in path.read_text().splitlines():
        match = re.match(r"^  ([A-Z_]+) = (.*)$", line)
        if match: result[match.group(1)] = match.group(2)
    return result

def rewrite(value):
    return value.replace("/home/cristi/src/darling", str(IMAGE)).replace(str(IMAGE) + "/build", str(BUILD))

def main():
    actual = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if actual != EXPECTED_SOURCE: raise SystemExit(f"source hash changed: {actual}")
    cv, lv = load(VARS / "compile.vars"), load(VARS / "link.vars")
    OUTPUT.mkdir(parents=True, exist_ok=True); obj = OUTPUT / "Darling Applications.o"; exe = OUTPUT / "Darling Applications.app/Contents/MacOS/Darling Applications"
    exe.parent.mkdir(parents=True, exist_ok=True)
    defines = [x for x in shlex.split(cv["DEFINES"]) if x != "-DNSBUILDINGFOUNDATION=1"]
    flags = shlex.split(rewrite(cv["FLAGS"]).replace("-mmacosx-version-min=10.10", "-mmacosx-version-min=11.0"))
    includes = shlex.split(rewrite(cv["INCLUDES"])) + [f"-I{IMAGE}/src/external/cocotron/AppKit/include", f"-I{IMAGE}/src/external/cocotron/QuartzCore/include", f"-I{BUILD}/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers"]
    compile_cmd = ["/usr/bin/clang", *defines, *includes, *flags, "-fobjc-exceptions", "-fblocks", "-mmacosx-version-min=11.0", "-o", str(obj), "-c", str(SOURCE)]
    link_flags = shlex.split(rewrite(lv["FLAGS"] + " " + lv["LINK_FLAGS"]))
    # The defaults recipe records optional Swift overlays; omit only mappings
    # whose concrete integration17 provider is absent, preserving all others.
    link_flags = [flag for flag in link_flags if not (flag.startswith("-Wl,-dylib_file,") and ":" in flag and not Path(flag.rsplit(":", 1)[1]).exists())]
    # integration17's AppKit has an optional Swift re-export, but this image
    # intentionally does not ship Swift. Provide a private empty compatibility
    # dylib so ld64 can resolve the recorded install name without host mixing.
    swift_stubs = {
        "libswiftAppKit.dylib": "/usr/lib/swift/libswiftAppKit.dylib",
        "libswiftFoundation.dylib": "/usr/lib/swift/libswiftFoundation.dylib",
        "libswiftCoreGraphics.dylib": "/usr/lib/swift/libswiftCoreGraphics.dylib",
    }
    for stub_name, install_name in swift_stubs.items():
        swift_stub = OUTPUT / stub_name
        if swift_stub.exists():
            continue
        stub_c = OUTPUT / "swift-stub.c"; stub_o = OUTPUT / "swift-stub.o"
        stub_c.write_text("void darling_swift_appkit_compat(void) {}\n")
        # Keep the compatibility stub independent of the AppKit compile
        # prefix/include flags: it intentionally includes no Darling headers.
        stub_compile = ["/usr/bin/clang", "-target", "aarch64-apple-darwin20",
                        "-arch", "arm64", "-mmacosx-version-min=11.0",
                        "-nostdinc", "-c", str(stub_c), "-o", str(stub_o)]
        subprocess.run(stub_compile, check=True, cwd=BUILD)
        subprocess.run(["/usr/bin/clang", "-target", "aarch64-apple-darwin20", "-dynamiclib", "-nostdlib", "-fuse-ld=" + str(BUILD/"src/external/cctools-port/cctools/ld64/src/aarch64-apple-darwin20-ld"), f"-Wl,-install_name,{install_name}", "-Wl,-sdk_version,11.0", "-o", str(swift_stub), str(stub_o)], check=True, cwd=BUILD)
    for stub_name, install_name in swift_stubs.items():
        link_flags.append(f"-Wl,-dylib_file,{install_name}:{OUTPUT / stub_name}")
    libraries = shlex.split(rewrite(lv["LINK_LIBRARIES"])) + [str(BUILD/"src/external/corefoundation/CoreFoundation"), str(BUILD/"src/external/cocotron/AppKit/AppKit"), str(BUILD/"src/external/objc4/runtime/libobjc.A.dylib")]
    link_cmd = ["/usr/bin/clang", *link_flags, str(obj), "-o", str(exe), *libraries]
    (OUTPUT / "commands.json").write_text(json.dumps({"source_sha256": actual, "compile_vars_sha256": hashlib.sha256((VARS/"compile.vars").read_bytes()).hexdigest(), "link_vars_sha256": hashlib.sha256((VARS/"link.vars").read_bytes()).hexdigest(), "image": str(IMAGE), "compile": compile_cmd, "link": link_cmd}, indent=2) + "\n")
    for name, command in (("compile", compile_cmd), ("link", link_cmd)):
        result = subprocess.run(command, cwd=BUILD, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (OUTPUT / f"{name}.log").write_text(result.stdout)
        if result.returncode: raise SystemExit(f"{name} failed ({result.returncode}); see {OUTPUT}/{name}.log")
    shutil.copy2(PLIST, exe.parents[1] / "Info.plist")
    manifest = {"source_sha256": actual, "binary_sha256": hashlib.sha256(exe.read_bytes()).hexdigest(), "plist_sha256": hashlib.sha256(PLIST.read_bytes()).hexdigest(), "bundle": str(exe.parent.parent)}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(OUTPUT)

if __name__ == "__main__": main()
