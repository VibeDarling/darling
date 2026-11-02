#!/usr/bin/env python3
import subprocess
import sys
import os

def run_cmd(cmd, **kwargs):
    print(f"+ {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **kwargs)
    if res.returncode != 0:
        print(f"Error ({res.returncode}):\n{res.stderr}\n{res.stdout}")
        sys.exit(res.returncode)
    return res.stdout

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    test_src = os.path.join(root, "tests", "wkwebview-accessors.m")
    build_dir = os.path.join(root, "build", "tests")
    os.makedirs(build_dir, exist_ok=True)
    out_bin = os.path.join(build_dir, "test_wkwebview")

    # Map paths for Darling prefix
    darling_src = f"/Volumes/SystemRoot{test_src}" if not test_src.startswith("/Volumes/SystemRoot") else test_src
    darling_out = f"/Volumes/SystemRoot{out_bin}" if not out_bin.startswith("/Volumes/SystemRoot") else out_bin

    print("=== Compiling tests/wkwebview-accessors.m ===")
    run_cmd(["darling", "shell", "clang", "-framework", "Foundation", "-framework", "AppKit", "-framework", "WebKit", darling_src, "-o", darling_out])

    print("=== Running tests/wkwebview-accessors ===")
    out = run_cmd(["darling", "shell", darling_out])
    print(out)
    if "ALL 11 WKWebView ACCESSOR CHECKS PASSED!" not in out:
        print("FAIL: Expected success marker not found in output")
        sys.exit(1)

    print("PASS: WKWebView accessors regression suite completed successfully!")

if __name__ == "__main__":
    main()
