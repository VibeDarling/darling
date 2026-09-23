#!/usr/bin/env python3
"""Prepare per-app and per-library issue bodies from a live appscan JSON file.

This command only writes local drafts. Review them before publishing issues.
"""

import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re


def slug(value):
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")[:65]


def key(kind, value):
    return f"{kind}:{hashlib.sha256(value.encode()).hexdigest()[:12]}"


def short_library(path):
    if ".framework/" in path:
        return path.split(".framework/", 1)[0].split("/")[-1]
    return path.rsplit("/", 1)[-1]


def library_title(path):
    prefix = "iOSSupport " if "/iOSSupport/" in path else ""
    prefix += "private " if "/PrivateFrameworks/" in path else ""
    return f"Library gap: {prefix}{short_library(path)} [{key('lib', path).split(':')[1][:8]}]"


def candidate(path):
    name = short_library(path)
    known = {
        "SwiftUI": "OpenSwiftUI: https://github.com/cristim/OpenSwiftUI ; inspect its OpenAttributeGraph dependency at https://github.com/cristim/OpenAttributeGraph. Verify the exact Darwin module and ABI gaps.",
        "AttributeGraph": "OpenAttributeGraph fork: https://github.com/cristim/OpenAttributeGraph ; verify its current Darwin build and needed exports.",
        "UIKit": "Microsoft WinObjC provides UIKit source (https://github.com/microsoft/WinObjC), but targets Windows; a Darling port and ABI audit are required.",
        "QuickLookUI": "Darling has QuickLookUI source under src/frameworks/Quartz/QuickLookUI; check its current packaging and exports before seeking another project.",
        "Accessibility": "Darling has libAccessibility source. GNOME AT-SPI2 (https://github.com/GNOME/at-spi2-core) may supply a backend, but a macOS API and ABI bridge is required.",
        "CoreSpotlight": "SQLite FTS5 (https://www.sqlite.org/fts5.html) can supply indexing primitives; a CoreSpotlight API and ABI adapter would still be needed.",
    }
    return known.get(name, "No open-source ABI candidate has been verified for this exact install path. Search current source and licenses before choosing a fork or a clean-room implementation.")


def app_body(app, guide_url, scan_date):
    missing = app["missing_libs"]
    wrong = app["wrong_arch_libs"]
    symbols = app["missing"]
    count = sum(map(len, symbols.values()))
    lines = [
        f"<!-- vd-compat-app:{key('app', app['app'])} -->",
        f"## {app['app']} compatibility",
        "",
        f"Scan: {scan_date}; executable: `{app['path']}`; selected architecture: `{app['arch']}`.",
        f"Direct gaps: **{len(missing)} absent libraries**, **{len(wrong)} wrong-architecture libraries**, **{count} unresolved nonweak imports**.",
        "This is static binding evidence, not a claim that the app launches or its workflow works.",
        "",
        "### Absent direct libraries",
        "",
    ]
    lines.extend(f"- `{p}` — {len(symbols.get(p, []))} direct imports" for p in missing)
    if not missing:
        lines.append("- None in this scan.")
    lines += ["", "### Wrong-architecture direct libraries", ""]
    lines.extend(f"- `{p}` — {len(symbols.get(p, []))} direct imports" for p in wrong)
    if not wrong:
        lines.append("- None in this scan.")
    present = [(p, len(v)) for p, v in symbols.items() if p not in missing and p not in wrong]
    present.sort(key=lambda item: (-item[1], item[0]))
    lines += ["", "### Present libraries with missing exports", ""]
    lines.extend(f"- `{p}` — {n} imports" for p, n in present)
    if not present:
        lines.append("- None in this scan.")
    lines += [
        "", "### Contribute a fix", "",
        f"Follow the [compatibility contribution guide]({guide_url}). Reproduce against current binaries; the scan may be stale.",
        "Investigate both direct and reachable indirect dependencies, select real implementations or viable open-source forks, and compare exact Mach-O exports and Swift ABI names.",
        "Submit focused PRs in the owning repositories, stage them in the local Darling integration prefix, rescan, launch this app, and exercise its core workflow. Record commands, logs, remaining failures, and app version.",
        "AI tools can help map symbols and draft patches; verify every suggestion with current source, a build, a symbol diff, and runtime behavior.",
        "", "### Reproduce", "",
        "Run `tools/darling-applications/scan-imported-apps.py` with `VIBEDARLING_EXTRA_APP` pointing to a legally obtained copy of this app, `VIBEDARLING_INSTALLED_ROOT` pointing to the tested Darling root, and `VIBEDARLING_TRANSITIVE=1` for available indirect images.",
    ]
    return "\n".join(lines) + "\n"


def library_body(path, data, guide_url, scan_date):
    statuses = sorted(data["statuses"])
    symbols = sorted(data["symbols"])
    apps = sorted(data["apps"].items(), key=lambda item: (-item[1], item[0]))
    lines = [
        f"<!-- vd-compat-lib:{key('lib', path)} -->",
        f"## {short_library(path)} at `{path}`",
        "",
        f"Scan: {scan_date}. Status: **{', '.join(statuses)}**. {len(apps)} imported apps load this path; their executables import **{len(symbols)} distinct nonweak symbols** from it.",
        "An absent library's own dependencies cannot be known from this scan. Recheck the current binary and prefix before coding.",
        "", "### Apps needing it", "",
    ]
    lines.extend(f"- {app} — {count} direct imports" for app, count in apps)
    lines += ["", "### Imported symbol sample", ""]
    lines.extend(f"- `{sym}`" for sym in symbols[:25])
    if not symbols:
        lines.append("- The executable records a load but no nonweak symbol import; inspect re-exports, initializers, and indirect users.")
    elif len(symbols) > 25:
        lines.append(f"- …and {len(symbols) - 25} more; regenerate the full list with the app scanner.")
    lines += [
        "", "### Source and implementation route", "",
        candidate(path),
        "Check the current Darling source and installed binary first. If a usable open-source implementation exists, verify its license and API, create or update its `cristim` fork, pin its commit, and address the exact ABI and behavior gaps. If none exists, implement a functional Darling slice from public API contracts and track required services.",
        f"Use the [compatibility contribution guide]({guide_url}) for the build, AI-assisted investigation, tests, integration, and PR steps.",
        "", "### Acceptance", "",
        "Provide a compatible arm64 load path and the required exports, run focused behavior tests under Darling, rescan the affected apps, exercise a real app workflow, and record any remaining indirect dependencies or runtime failures. Empty binding stubs do not satisfy this issue.",
    ]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("scan", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--guide-url", required=True)
    parser.add_argument("--scan-date", default="2026-09-23")
    args = parser.parse_args()
    apps = json.loads(args.scan.read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    libraries = defaultdict(lambda: {"statuses": set(), "symbols": set(), "apps": {}})
    index = []
    for app in apps:
        name = app["app"]
        entry_key = key("app", name)
        file = Path("apps") / f"{slug(name)}-{entry_key.split(':')[1][:8]}.md"
        (args.output / file).parent.mkdir(parents=True, exist_ok=True)
        (args.output / file).write_text(app_body(app, args.guide_url, args.scan_date))
        index.append({"key": entry_key, "title": f"App compatibility: {name}", "body_file": str(file), "app": name})
        for path in set(app["missing_libs"] + app["wrong_arch_libs"] + list(app["missing"])):
            data = libraries[path]
            if path in app["missing_libs"]:
                data["statuses"].add("absent")
            if path in app["wrong_arch_libs"]:
                data["statuses"].add("wrong architecture")
            if path not in app["missing_libs"] and path not in app["wrong_arch_libs"]:
                data["statuses"].add("present, missing exports")
            data["symbols"].update(app["missing"].get(path, []))
            data["apps"][name] = len(app["missing"].get(path, []))
    for path, data in sorted(libraries.items()):
        entry_key = key("lib", path)
        file = Path("libraries") / f"{slug(short_library(path))}-{entry_key.split(':')[1][:8]}.md"
        (args.output / file).parent.mkdir(parents=True, exist_ok=True)
        (args.output / file).write_text(library_body(path, data, args.guide_url, args.scan_date))
        index.append({"key": entry_key, "title": library_title(path), "body_file": str(file), "library": path})
    (args.output / "index.json").write_text(json.dumps(index, indent=2) + "\n")
    print(f"Prepared {len(apps)} app and {len(libraries)} library issues in {args.output}")


if __name__ == "__main__":
    main()
