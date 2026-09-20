#!/usr/bin/env python3
"""Verify a viewer bundle still matches the manifest its build recorded.

Takes a build-standalone.py output directory, checks the bundle named by its
manifest.json against the hashes in that manifest, and prints the bundle path.
Exits non-zero if anything disagrees.
"""
import hashlib, json, sys
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: qa-verify-bundle.py <build output directory>")
    manifest_path = Path(sys.argv[1]) / "manifest.json"
    if not manifest_path.is_file():
        raise SystemExit(f"no manifest at {manifest_path}; run build-standalone.py first")
    manifest = json.loads(manifest_path.read_text())

    bundle = Path(manifest["bundle"])
    executable = bundle / "Contents/MacOS/Darling Applications"
    if not executable.is_file():
        raise SystemExit(f"manifest names {bundle}, but its executable is missing")

    mismatches = []
    actual = digest(executable)
    if actual != manifest["binary_sha256"]:
        mismatches.append(f"  binary: manifest {manifest['binary_sha256']}, on disk {actual}")

    plist = bundle / "Contents/Info.plist"
    expected_plist = manifest.get("plist_sha256")
    if expected_plist:
        if not plist.is_file():
            mismatches.append("  Info.plist: recorded in the manifest but missing on disk")
        elif digest(plist) != expected_plist:
            mismatches.append(f"  Info.plist: manifest {expected_plist}, on disk {digest(plist)}")

    # Older builds predate helper packaging and record no helper hashes. Absent
    # helpers are reported rather than tolerated, because a bundle without them
    # cannot exercise the Homebrew parts of the checklist.
    helpers = manifest.get("helpers_sha256") or {}
    if not helpers:
        print("warning: this build records no packaged helpers; Homebrew actions "
              "will be unavailable in the viewer", file=sys.stderr)
    for name, expected in helpers.items():
        helper = bundle / "Contents/Resources" / name
        if not helper.is_file():
            mismatches.append(f"  {name}: recorded in the manifest but missing from the bundle")
        elif digest(helper) != expected:
            mismatches.append(f"  {name}: manifest {expected}, on disk {digest(helper)}")

    if mismatches:
        print(f"{bundle} does not match {manifest_path}:", file=sys.stderr)
        print("\n".join(mismatches), file=sys.stderr)
        raise SystemExit(1)

    print(bundle)


if __name__ == "__main__":
    main()
