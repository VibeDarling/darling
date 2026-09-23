#!/usr/bin/env python3
# Rank imported macOS apps against the current installed Darling tree.
# For each app's arm64e (else arm64) slice: map every imported library to its Darling install path,
# follow LC_REEXPORT_DYLIB, and count missing libraries and missing (non-weak) symbols, then classify
# each gap by owner: core (worker), gui (GUI agent), swift (Swift agent), closed (closed/private Apple code).
# Usage: scan-imported-apps.py [app-name-filter]
# Set VIBEDARLING_APP_ROOT, VIBEDARLING_EXTRA_APP, and VIBEDARLING_SCAN_OUTPUT as needed.
import datetime, glob, json, os, plistlib, re, subprocess, sys
from collections import defaultdict
from functools import lru_cache

APPS = os.environ.get("VIBEDARLING_APP_ROOT", os.path.expanduser("~/.local/share/darling/macos-apps/Applications"))
PREFIX = os.environ.get("VIBEDARLING_INSTALLED_ROOT", "/usr/local/libexec/darling")
OVERLAY = os.environ.get("VIBEDARLING_PREFIX", os.path.expanduser("~/.darling"))
B = os.environ.get("VIBEDARLING_SCAN_OUTPUT", "/tmp/vibedarling-appscan")
os.makedirs(B, exist_ok=True)
DETAILS, JSON_OUT, MD_OUT = f"{B}/details.log", f"{B}/apps.json", f"{B}/ranking.md"

# Frameworks whose Darling implementation the GUI agent owns (Cocotron AppKit, graphics, window server SPI).
GUI_FRAMEWORKS = {"AppKit", "CoreGraphics", "QuartzCore", "CoreText", "ImageIO", "Metal", "MetalKit", "OpenGL",
                  "CoreImage", "Onyx2D", "SkyLight"}
LOAD_CMDS = ("LC_LOAD_DYLIB", "LC_LOAD_WEAK_DYLIB", "LC_REEXPORT_DYLIB", "LC_LOAD_UPWARD_DYLIB")

def run(*args):
    return subprocess.run(args, capture_output=True, text=True).stdout

@lru_cache(maxsize=None)
def darling_path(install_name, app=None):
    if install_name.startswith("@rpath/") and app:
        relative = install_name[len("@rpath/"):]
        local = os.path.join(app, "Contents/Frameworks", relative)
        if os.path.exists(local):
            return local
    for root in (OVERLAY, PREFIX):
        p = root + install_name
        if os.path.exists(p):
            return p
    return None

@lru_cache(maxsize=None)
def archs(path):
    return run("llvm-lipo", "-archs", path).split()

def compatible_arch(path):
    available = archs(path)
    return next((a for a in ("arm64", "arm64e") if a in available), None)

@lru_cache(maxsize=None)
def direct_exports(path):
    a = compatible_arch(path)
    return frozenset(run("llvm-nm", "-gU", "-j", f"--arch={a}", path).split()) if a else frozenset()

def dylib_commands(path, arch):
    """[(cmd, install name)] for one slice; llvm-otool -arch doesn't filter -l on universal files."""
    out = run("llvm-otool", "-l", path)
    parts = re.split(r"^\S.*\(architecture (\S+)\):$", out, flags=re.M)
    if len(parts) > 1:
        out = next((parts[i + 1] for i in range(1, len(parts), 2) if parts[i] == arch), "")
    return re.findall(r"cmd (LC_\w+)\n\s+cmdsize \d+\n\s+name (\S+)", out)

@lru_cache(maxsize=None)
def exports(install_name, depth=0):
    path = darling_path(install_name)
    if not path:
        return None
    a = compatible_arch(path)
    if not a:
        return frozenset()
    syms = set(direct_exports(path))
    if depth < 4:
        for cmd, name in dylib_commands(path, a):
            if cmd == "LC_REEXPORT_DYLIB":
                syms |= exports(name, depth + 1) or set()
    return frozenset(syms)

def short_name(install_name):
    m = re.search(r"/([^/]+)\.framework/", install_name)
    return m.group(1) if m else os.path.basename(install_name).split(".")[0]

def app_executable(app):
    try:
        with open(os.path.join(app, "Contents/Info.plist"), "rb") as f:
            p = os.path.join(app, "Contents/MacOS", plistlib.load(f).get("CFBundleExecutable"))
        if os.path.isfile(p):
            return p
    except Exception:
        pass
    cands = glob.glob(os.path.join(app, "Contents/MacOS/*"))
    return cands[0] if cands else None

def lib_owner(install_name):
    s = short_name(install_name)
    if "/lib/swift/" in install_name or s.startswith("libswift"):
        return "swift"
    if s in GUI_FRAMEWORKS:
        return "gui"
    return None

def missing_lib_owner(install_name):
    return lib_owner(install_name) or "closed"

def symbol_owner(sym, install_name):
    if sym.startswith(("_$s", "_$S")):
        return "swift"
    return lib_owner(install_name) or "core"

def scan(app):
    exe = app_executable(app)
    if not exe:
        return None
    arch = "arm64e" if "arm64e" in archs(exe) else "arm64"
    cmds = [(c, n) for c, n in dylib_commands(exe, arch) if c in LOAD_CMDS]
    libs = list(dict.fromkeys(n for _, n in cmds))
    weak_libs = {n for c, n in cmds if c == "LC_LOAD_WEAK_DYLIB"}
    by_short = {short_name(l): l for l in libs}
    r = {"app": os.path.basename(app)[:-4], "arch": arch, "libs": len(libs),
         "path": app,
         "missing_libs": [l for l in libs if not darling_path(l, app) and l not in weak_libs],
         "wrong_arch_libs": [l for l in libs if (p := darling_path(l, app)) and not compatible_arch(p) and l not in weak_libs],
         "missing_weak_libs": [l for l in libs if not darling_path(l, app) and l in weak_libs],
         "missing": defaultdict(list), "weak_missing": 0}
    for line in run("llvm-nm", "-m", "-u", f"--arch={arch}", exe).splitlines():
        m = re.search(r"\(undefined\) (weak )?external (\S+) \(from ([^)]+)\)", line)
        if not m:
            continue
        weak, sym, lib = m.groups()
        inst = by_short.get(lib, lib)
        resolved = darling_path(inst, app)
        exp = exports(inst) if inst in libs and resolved == darling_path(inst) else None
        if inst in libs and resolved and resolved != darling_path(inst):
            exp = direct_exports(resolved)
        if exp is not None and sym in exp:
            continue
        if weak or inst in weak_libs:
            r["weak_missing"] += 1
            continue
        r["missing"][inst].append(sym)
    return r

def classify(r):
    c = {"core": 0, "gui": 0, "swift": 0, "closed": 0}
    closed_fw, core_syms = [], []
    for lib in r["missing_libs"]:
        o = missing_lib_owner(lib)
        if o == "closed":
            closed_fw.append(short_name(lib))
        else:
            c[o] += 1
    for lib, syms in r["missing"].items():
        if lib in r["missing_libs"]:
            if missing_lib_owner(lib) == "closed":
                c["closed"] += len(syms)
            continue
        for s in syms:
            o = symbol_owner(s, lib)
            c[o] += 1
            if o == "core":
                core_syms.append((short_name(lib), s))
    return c, sorted(set(closed_fw)), core_syms

def verdict(r, c, closed_fw):
    if not r["missing_libs"] and not r["wrong_arch_libs"] and not r["missing"]:
        return "direct bindings found"
    owners = [o for o in ("core", "gui", "swift") if c[o]] + (["closed"] if closed_fw else [])
    if r["wrong_arch_libs"]:
        owners.append("wrong arch")
    return " + ".join(owners)

def main():
    global DETAILS, JSON_OUT
    flt = sys.argv[1] if len(sys.argv) > 1 else ""
    if flt:
        DETAILS, JSON_OUT = DETAILS.replace(".log", "-filtered.log"), JSON_OUT.replace(".json", "-filtered.json")
    apps = sorted(glob.glob(f"{APPS}/*.app") + glob.glob(f"{APPS}/Utilities/*.app"))
    extra = os.environ.get("VIBEDARLING_EXTRA_APP")
    if extra:
        apps.append(extra)
    results = []
    with open(DETAILS, "w") as det:
        for app in apps:
            if flt and flt.lower() not in os.path.basename(app).lower():
                continue
            r = scan(app)
            if not r:
                continue
            results.append(r)
            nsyms = sum(len(v) for v in r["missing"].values())
            det.write(f"== {r['app']} ({r['arch']}, {r['libs']} libs, {len(r['missing_libs'])} missing libs, {len(r['wrong_arch_libs'])} wrong-arch libs, "
                      f"{len(r['missing_weak_libs'])} missing weak libs, {nsyms} missing symbols, {r['weak_missing']} weak missing)\n")
            for l in r["missing_libs"]:
                det.write(f"  MISSING LIB {l}\n")
            for l in r["wrong_arch_libs"]:
                det.write(f"  WRONG ARCH LIB {l}\n")
            for l in r["missing_weak_libs"]:
                det.write(f"  MISSING WEAK LIB {l}\n")
            for lib, syms in sorted(r["missing"].items(), key=lambda kv: -len(kv[1])):
                det.write(f"  {short_name(lib)}: {len(syms)}\n")
                for s in sorted(syms):
                    det.write(f"    {s}\n")
    rows = []
    closed_apps, core_gaps = defaultdict(list), defaultdict(set)
    for r in results:
        c, closed_fw, core_syms = classify(r)
        r["class"], r["closed_frameworks"] = c, closed_fw
        nsyms = sum(len(v) for v in r["missing"].values())
        rows.append((len(r["missing_libs"]) + len(r["wrong_arch_libs"]), nsyms, r, c, closed_fw))
        for fw in closed_fw:
            closed_apps[fw].append(r["app"])
        for lib, s in core_syms:
            core_gaps[(lib, s)].add(r["app"])
    rows.sort(key=lambda x: (x[0], x[1], x[2]["app"]))
    with open(JSON_OUT, "w") as f:
        json.dump(results, f, indent=1)
    print("app | missing/arch libs | missing symbols | direct-bind estimate")
    for nl, ns, r, c, closed_fw in rows:
        print(f"{r['app']} | {nl} | {ns} | {verdict(r, c, closed_fw)}")
    if flt:
        return
    with open(MD_OUT, "w") as md:
        md.write(f"# Imported app scan against installed Darling ({datetime.datetime.now():%Y-%m-%d %H:%M})\n\n")
        md.write(f"Static *direct* bind estimate of each app's arm64e (else arm64) slice against {PREFIX} plus\n"
                 f"{OVERLAY}. Embedded @rpath frameworks are resolved inside app bundles. Wrong-architecture dylibs are counted as missing.\n"
                 "Transitive loads, dyld interposition, and launch behavior require separate checks. Weak links/imports are excluded.\n"
                 "Owners: core = worker (libSystem, CF, Foundation, CoreServices, ...), gui = GUI agent\n"
                 f"({', '.join(sorted(GUI_FRAMEWORKS))}), swift = Swift agent (libswift*, `$s` symbols),\n"
                 "closed = Apple framework or dylib with no Darling implementation (symbols counted in the closed column).\n"
                 "Binding fully does not mean the app runs: arm64e apps also need DARLING_DISABLE_PTRAUTH=1, and runtime gaps remain.\n\n")
        md.write("| app | missing libs | wrong arch | missing symbols | core | gui | swift | closed syms | closed frameworks | estimate |\n")
        md.write("|---|---:|---:|---:|---:|---:|---:|---:|---|---|\n")
        for nl, ns, r, c, closed_fw in rows:
            fw = ", ".join(closed_fw[:6]) + (f" (+{len(closed_fw) - 6})" if len(closed_fw) > 6 else "")
            md.write(f"| {r['app']} | {len(r['missing_libs'])} | {len(r['wrong_arch_libs'])} | {ns} | {c['core']} | {c['gui']} | {c['swift']} | {c['closed']} | {fw} | {verdict(r, c, closed_fw)} |\n")
        md.write("\n## Closed frameworks by number of apps that need them\n\n| framework | apps | apps |\n|---|---:|---|\n")
        for fw, apps_ in sorted(closed_apps.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:40]:
            md.write(f"| {fw} | {len(apps_)} | {', '.join(sorted(apps_))} |\n")
        md.write("\n## Apps with small direct bind gaps (at most 2 absent frameworks, at most 15 other missing symbols)\n\n")
        md.write("| app | closed frameworks (symbols needed) | other gaps (core/gui/swift) |\n|---|---|---|\n")
        for nl, ns, r, c, closed_fw in rows:
            other = c["core"] + c["gui"] + c["swift"]
            if 0 < len(closed_fw) <= 2 and other <= 15:
                need = ", ".join(f"{short_name(l)} ({len(r['missing'].get(l, []))})" for l in r["missing_libs"] if missing_lib_owner(l) == "closed")
                md.write(f"| {r['app']} | {need} | {c['core']}/{c['gui']}/{c['swift']} |\n")
        md.write("\n## Core-library symbol gaps (worker)\n\n| library | symbol | apps |\n|---|---|---|\n")
        for (lib, s), apps_ in sorted(core_gaps.items(), key=lambda kv: (-len(kv[1]), kv[0])):
            md.write(f"| {lib} | `{s}` | {', '.join(sorted(apps_))} |\n")

main()
