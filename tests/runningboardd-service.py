#!/usr/bin/env python3
# Host test: the runningboardd stand-in is wired into the build and answers requests under Darling.
# usage: python3 tests/runningboardd-service.py [REPO_ROOT]
# Static checks: the launchd plist registers the Mach service name the daemon listens on, points at the
# installed binary, and does not start the daemon at load (so processes that never contact it never start it).
# Dynamic check: tests/runningboardd-service.c, a guest program, looks the service up and sends two requests.
# On a prefix without the daemon the lookup fails and this test fails.

import os
import plistlib
import re
import subprocess
import sys

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
daemon_dir = os.path.join(root, "src/runningboardd")

with open(os.path.join(daemon_dir, "runningboardd.c"), encoding="utf-8") as f:
    daemon_source = f.read()
with open(os.path.join(daemon_dir, "com.apple.runningboard.plist"), "rb") as f:
    plist = plistlib.load(f)
with open(os.path.join(root, "src/CMakeLists.txt"), encoding="utf-8") as f:
    top_cmake = f.read()
with open(os.path.join(daemon_dir, "CMakeLists.txt"), encoding="utf-8") as f:
    daemon_cmake = f.read()

m = re.search(r'#define\s+SERVICE_NAME\s+"([^"]+)"', daemon_source)
if not m:
    sys.exit("FAIL: runningboardd.c does not define SERVICE_NAME")
service = m.group(1)

if service not in plist.get("MachServices", {}):
    sys.exit(f"FAIL: plist MachServices does not register {service}")
if plist.get("Program") != "/usr/libexec/runningboardd":
    sys.exit("FAIL: plist Program is not /usr/libexec/runningboardd")
if "libexec/darling/usr/libexec" not in daemon_cmake:
    sys.exit("FAIL: the daemon is not installed to usr/libexec")
if plist.get("RunAtLoad") or plist.get("KeepAlive"):
    sys.exit("FAIL: plist must not start the daemon at load: it is on-demand")
if not re.search(r"^\s*add_subdirectory\(runningboardd\)", top_cmake, re.M):
    sys.exit("FAIL: src/CMakeLists.txt does not add runningboardd")

has_darling = subprocess.run(["darling", "shell", "true"], capture_output=True).returncode == 0
test_src = os.path.join(root, "tests/runningboardd-service.c")
guest_bin = "/tmp/runningboardd_service_test"
src_path = f"/Volumes/SystemRoot{test_src}" if has_darling else test_src
prefix = ["darling", "shell"] if has_darling else []

try:
    res = subprocess.run(prefix + ["clang", src_path, "-o", guest_bin], capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit(f"Compilation failed:\n{res.stderr}\n{res.stdout}")
    res = subprocess.run(prefix + [guest_bin], capture_output=True, text=True, timeout=120)
    if res.returncode != 0:
        sys.exit(f"Execution failed (code {res.returncode}):\n{res.stderr}\n{res.stdout}")
    if "PASS:" not in res.stdout:
        sys.exit(f"Execution did not report PASS:\n{res.stdout}")
    print("PASS: runningboardd is wired in and answers requests with an explicit reply")
finally:
    subprocess.run(prefix + ["rm", "-f", guest_bin], capture_output=True)
