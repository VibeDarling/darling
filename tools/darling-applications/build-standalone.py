#!/usr/bin/env python3
"""Build the native Applications viewer against a verified Darling image.

This intentionally does not configure Darling or rebuild dependencies.  It
reuses only the recorded compile/link variables from a configured image,
rewriting every old-tree path to that image and emitting a private bundle.

The script carries no developer-specific paths. Every location comes from the
environment:

  DARLING_VIEWER_IMAGE  required. The configured Darling image to build
                        against; its build directory is <image>/build.
  DARLING_VIEWER_VARS   required. Directory holding the recorded compile.vars
                        and link.vars.
  DARLING_VIEWER_OUTPUT optional. Where the bundle is emitted.
                        Defaults to <image>/build/darling-applications.
  DARLING_VIEWER_RECORDED_ROOT
                        optional. The source tree the recorded vars were
                        captured in, rewritten to the image on use. Defaults
                        to the checkout this script lives in.
  DARLING_VIEWER_EXPECT_SOURCE
                        optional. Pin main.m to this sha256 and fail if it
                        differs. Unset, a difference from the recorded hash
                        below is only a warning.
"""
import hashlib, json, os, re, shlex, shutil, subprocess, sys
from pathlib import Path

CHECKOUT = Path(__file__).resolve().parents[2]
SOURCE = CHECKOUT / "src/darling-applications/main.m"
PLIST = SOURCE.with_name("Info.plist")

def required_path(name):
    value = os.environ.get(name)
    if not value: raise SystemExit(f"{name} must be set; it has no portable default.")
    return Path(value)

IMAGE = required_path("DARLING_VIEWER_IMAGE")
BUILD = IMAGE / "build"
VARS = required_path("DARLING_VIEWER_VARS")
OUTPUT = Path(os.environ.get("DARLING_VIEWER_OUTPUT", BUILD / "darling-applications"))
RECORDED_ROOT = Path(os.environ.get("DARLING_VIEWER_RECORDED_ROOT", CHECKOUT))
# The main.m this recipe was last verified against. Drift is expected as main.m
# is edited normally, so it is reported and not enforced; set
# DARLING_VIEWER_EXPECT_SOURCE to require an exact source instead.
EXPECTED_SOURCE = "8b73d6ecc4da5d8e5a2530d099a8b9d19dcffd5f2653525364242c6cfed271a5"

def load(path):
    result = {}
    for line in path.read_text().splitlines():
        match = re.match(r"^  ([A-Z_]+) = (.*)$", line)
        if match: result[match.group(1)] = match.group(2)
    return result

def rewrite(value):
    # Anchored so a recorded root of .../darling does not also rewrite a
    # sibling .../darling-gui into <image>-gui.
    return re.sub(re.escape(str(RECORDED_ROOT)) + r"(?![A-Za-z0-9_.-])", str(IMAGE), value)

def main():
    actual = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    required = os.environ.get("DARLING_VIEWER_EXPECT_SOURCE")
    if required:
        if actual != required:
            raise SystemExit(f"main.m is {actual}, but DARLING_VIEWER_EXPECT_SOURCE requires {required}")
    elif actual != EXPECTED_SOURCE:
        print(f"warning: main.m has changed since this recipe was last verified "
              f"(recorded {EXPECTED_SOURCE}, building {actual})", file=sys.stderr)
    cv, lv = load(VARS / "compile.vars"), load(VARS / "link.vars")
    OUTPUT.mkdir(parents=True, exist_ok=True); obj = OUTPUT / "Darling Applications.o"; exe = OUTPUT / "Darling Applications.app/Contents/MacOS/Darling Applications"
    exe.parent.mkdir(parents=True, exist_ok=True)
    defines = [x for x in shlex.split(cv["DEFINES"]) if x != "-DNSBUILDINGFOUNDATION=1"]
    flags = shlex.split(rewrite(cv["FLAGS"]).replace("-mmacosx-version-min=10.10", "-mmacosx-version-min=11.0"))
    includes = shlex.split(rewrite(cv["INCLUDES"])) + [f"-I{IMAGE}/src/external/cocotron/AppKit/include", f"-I{IMAGE}/src/external/cocotron/QuartzCore/include", f"-I{BUILD}/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers"]
    compile_cmd = ["/usr/bin/clang", *defines, *includes, *flags, "-fobjc-exceptions", "-fblocks", "-mmacosx-version-min=11.0", "-o", str(obj), "-c", str(SOURCE)]
    link_flags = shlex.split(rewrite(lv["FLAGS"] + " " + lv["LINK_FLAGS"]))
    # The defaults recipe records optional Swift overlays; omit only mappings
    # whose concrete provider is absent from the image, preserving all others.
    link_flags = [flag for flag in link_flags if not (flag.startswith("-Wl,-dylib_file,") and ":" in flag and not Path(flag.rsplit(":", 1)[1]).exists())]
    # The image's AppKit has an optional Swift re-export, but the image
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
    bundle = exe.parent.parent
    shutil.copy2(PLIST, bundle / "Info.plist")
    resources = bundle / "Resources"
    resources.mkdir(parents=True, exist_ok=True)
    helper_hashes = {}
    for helper_name in ("homebrew-bootstrap", "brewfile-install"):
        helper = Path(__file__).with_name(helper_name)
        target = resources / helper_name
        shutil.copy2(helper, target)
        target.chmod(0o755)
        helper_hashes[helper_name] = hashlib.sha256(target.read_bytes()).hexdigest()
    manifest = {"source_sha256": actual, "binary_sha256": hashlib.sha256(exe.read_bytes()).hexdigest(), "plist_sha256": hashlib.sha256(PLIST.read_bytes()).hexdigest(), "helpers_sha256": helper_hashes, "bundle": str(bundle)}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(OUTPUT)

if __name__ == "__main__": main()
