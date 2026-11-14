#!/usr/bin/env python3
# Host test: the cfprefsd stand-in is wired into the build, registered on demand, and stores what a client writes.
# usage: python3 tests/cfprefsd-service.py [REPO_ROOT]
# Static checks: the launchd plist registers the Mach service the daemon listens on, points at the installed binary, and does not
# start the daemon at load (processes that never ask for it never start it); no domain name can reach outside the preferences
# directory (the path code rejects '/', '.', '..' and empty names).
# Dynamic check: tests/cfprefsd-service.c, a guest program, sends operations 9, 1 and 5 and checks the plist files.
# On a prefix without the daemon the lookup fails and this test fails.

import os
import plistlib
import re
import subprocess
import sys

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
daemon_dir = os.path.join(root, "src/cfprefsd")

def read(name):
    with open(os.path.join(daemon_dir, name), encoding="utf-8") as f:
        return f.read()

daemon_source = read("cfprefsd.c")
paths_source = read("paths.c")
daemon_cmake = read("CMakeLists.txt")
with open(os.path.join(daemon_dir, "com.apple.cfprefsd.daemon.plist"), "rb") as f:
    plist = plistlib.load(f)
with open(os.path.join(root, "src/CMakeLists.txt"), encoding="utf-8") as f:
    top_cmake = f.read()

m = re.search(r'#define\s+SERVICE_NAME\s+"([^"]+)"', daemon_source)
if not m:
    sys.exit("FAIL: cfprefsd.c does not define SERVICE_NAME")
service = m.group(1)

if service not in plist.get("MachServices", {}):
    sys.exit(f"FAIL: plist MachServices does not register {service}")
if plist.get("Program") != "/usr/sbin/cfprefsd":
    sys.exit("FAIL: plist Program is not /usr/sbin/cfprefsd")
if "libexec/darling/usr/sbin" not in daemon_cmake:
    sys.exit("FAIL: the daemon is not installed to usr/sbin")
if plist.get("RunAtLoad") or plist.get("KeepAlive"):
    sys.exit("FAIL: plist must not start the daemon at load: it is on-demand")
if not re.search(r"^\s*add_subdirectory\(cfprefsd\)", top_cmake, re.M):
    sys.exit("FAIL: src/CMakeLists.txt does not add cfprefsd")
for needle in ("strchr(domain, '/')", '"."', '".."'):
    if needle not in paths_source:
        sys.exit(f"FAIL: paths.c no longer rejects domain names containing {needle}")

has_darling = subprocess.run(["darling", "shell", "true"], capture_output=True).returncode == 0
test_src = os.path.join(root, "tests/cfprefsd-service.c")
guest_bin = "/tmp/cfprefsd_service_test"
src_path = f"/Volumes/SystemRoot{test_src}" if has_darling else test_src
prefix = ["darling", "shell"] if has_darling else []

try:
    res = subprocess.run(prefix + ["clang", src_path, "-framework", "CoreFoundation", "-o", guest_bin], capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit(f"Compilation failed:\n{res.stderr}\n{res.stdout}")
    res = subprocess.run(prefix + [guest_bin], capture_output=True, text=True, timeout=120)
    if res.returncode != 0:
        sys.exit(f"Execution failed (code {res.returncode}):\n{res.stderr}\n{res.stdout}")
    if "PASS:" not in res.stdout:
        sys.exit(f"Execution did not report PASS:\n{res.stdout}")
    print("PASS: cfprefsd is wired in, answers operations 9, 1 and 5 and stores writes")
finally:
    subprocess.run(prefix + ["rm", "-f", guest_bin], capture_output=True)
