#!/usr/bin/env python3
import os
import subprocess
import sys

def main():
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    cf_url_src = os.path.join(root, "src/external/corefoundation/CFURLEnumerator.c")
    if not os.path.exists(cf_url_src):
        sys.exit(f"Source file not found at {cf_url_src}")

    # 1. Source checks
    with open(cf_url_src, "r", encoding="utf-8") as f:
        content = f.read()

    if "pushedLastItem" not in content:
        sys.exit("FAIL: CFURLEnumerator must track pushedLastItem for skipDescendents")

    if "CFRelease(item);" not in content:
        sys.exit("FAIL: CFURLEnumerator must release temporary item when url is NULL")

    # 2. Dynamic execution under Darling shell
    has_darling = subprocess.run(["darling", "shell", "true"], capture_output=True).returncode == 0
    test_src1 = os.path.join(root, "src/external/corefoundation/Tests/CFURLEnumeratorRecursion.m")
    test_src2 = os.path.join(root, "src/external/corefoundation/Tests/CFErrorUnderlyingError.m")

    for test_src, bin_name in [(test_src1, "/tmp/test_cfurl_enum"), (test_src2, "/tmp/test_cferror")]:
        src_path = f"/Volumes/SystemRoot{test_src}" if has_darling else test_src
        compile_cmd = [
            "clang",
            "-framework", "Foundation",
            "-framework", "CoreFoundation",
            src_path,
            "-o", bin_name
        ]
        if has_darling:
            compile_cmd = ["darling", "shell"] + compile_cmd

        try:
            res = subprocess.run(compile_cmd, capture_output=True, text=True)
            if res.returncode != 0:
                sys.exit(f"Compilation failed for {test_src}:\n{res.stderr}\n{res.stdout}")

            run_cmd = ["darling", "shell", bin_name] if has_darling else [bin_name]
            res = subprocess.run(run_cmd, capture_output=True, text=True)
            if res.returncode != 0:
                sys.exit(f"Execution failed for {bin_name} (code {res.returncode}):\n{res.stderr}\n{res.stdout}")

            if "failures=0" not in res.stdout:
                sys.exit(f"Test {bin_name} reported failures:\n{res.stdout}")
        finally:
            cleanup_cmd = ["darling", "shell", "rm", "-f", bin_name] if has_darling else ["rm", "-f", bin_name]
            subprocess.run(cleanup_cmd, capture_output=True)

    print("PASS: CFURLEnumerator recursion, NULL item safety, and error handling verified")

if __name__ == "__main__":
    main()
