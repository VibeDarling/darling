#!/usr/bin/env python3
"""
Host test: ColorSync device dictionary keys and device class constants
are defined with correct Apple values and declared in the public header.
usage: python3 tests/colorsync-device-constants.py [REPO_ROOT]
"""

import os
import re
import sys
import tempfile
import subprocess

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXPECTED = {
    "kColorSyncDeviceProfileURL": "DeviceProfileURL",
    "kColorSyncDeviceModeDescriptions": "DeviceModeDescriptions",
    "kColorSyncDeviceDefaultProfileID": "DeviceDefaultProfileID",
    "kColorSyncDeviceDescriptions": "DeviceDescriptions",
    "kColorSyncFactoryProfiles": "FactoryProfiles",
    "kColorSyncDeviceUserScope": "DeviceUserScope",
    "kColorSyncDeviceHostScope": "DeviceHostScope",
    "kColorSyncPrinterDeviceClass": "prnt",
    "kColorSyncCustomProfiles": "CustomProfiles",
    "kColorSyncDisplayDeviceClass": "mntr",
}

colorsync_c_path = os.path.join(root, "src", "frameworks", "ColorSync", "src", "ColorSync.c")
colorsync_h_path = os.path.join(root, "src", "frameworks", "ColorSync", "include", "ColorSync", "ColorSync.h")

with open(colorsync_c_path, "r", encoding="utf-8") as f:
    colorsync_c_lines = f.readlines()
colorsync_c = "".join(colorsync_c_lines)

with open(colorsync_h_path, "r", encoding="utf-8") as f:
    colorsync_h = f.read()

failed = False

for name, expected_val in EXPECTED.items():
    # Check definition in ColorSync.c
    pattern = rf'^\s*CFStringRef\s+{name}\s*=\s*CFSTR\("{re.escape(expected_val)}"\);'
    matches = re.findall(pattern, colorsync_c, re.MULTILINE)
    if len(matches) != 1:
        print(f"FAIL: {name} in ColorSync.c expected definition CFSTR(\"{expected_val}\"), found {len(matches)} matches", file=sys.stderr)
        failed = True

    # Check declaration in ColorSync.h
    decl_pattern = rf'^\s*extern\s+CFStringRef\s+{name}\s*;'
    if not re.search(decl_pattern, colorsync_h, re.MULTILINE):
        print(f"FAIL: {name} is not declared as 'extern CFStringRef {name};' in ColorSync.h", file=sys.stderr)
        failed = True

if failed:
    sys.exit(1)

# Extract constant definitions directly from ColorSync.c and compile into an object file
defs = [l for l in colorsync_c_lines if re.match(r'^\s*CFStringRef\s+kColorSync\w+\s*=\s*CFSTR\(', l)]
if not defs:
    print("FAIL: no constant definitions found in ColorSync.c", file=sys.stderr)
    sys.exit(1)

with tempfile.TemporaryDirectory(prefix="colorsync-test-") as tmpdir:
    cf_h = os.path.join(tmpdir, "cf.h")
    with open(cf_h, "w", encoding="utf-8") as f:
        f.write("typedef const struct __CFString *CFStringRef;\n#define CFSTR(s) ((CFStringRef)(s))\n")

    defs_c = os.path.join(tmpdir, "colorsync_defs.c")
    with open(defs_c, "w", encoding="utf-8") as f:
        f.write('#include "cf.h"\n' + "".join(defs))

    defs_o = os.path.join(tmpdir, "colorsync_defs.o")
    subprocess.check_call(["clang", "-fPIC", "-c", defs_c, "-o", defs_o])

    # Probe declares extern constants and links against colorsync_defs.o compiled from ColorSync.c
    probe_c = os.path.join(tmpdir, "probe.c")
    with open(probe_c, "w", encoding="utf-8") as f:
        f.write(r"""#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef const struct __CFString *CFStringRef;

extern CFStringRef kColorSyncDeviceProfileURL;
extern CFStringRef kColorSyncDeviceModeDescriptions;
extern CFStringRef kColorSyncDeviceDefaultProfileID;
extern CFStringRef kColorSyncDeviceDescriptions;
extern CFStringRef kColorSyncFactoryProfiles;
extern CFStringRef kColorSyncDeviceUserScope;
extern CFStringRef kColorSyncDeviceHostScope;
extern CFStringRef kColorSyncPrinterDeviceClass;
extern CFStringRef kColorSyncCustomProfiles;
extern CFStringRef kColorSyncDisplayDeviceClass;

int main(void) {
    assert(strcmp((const char *)kColorSyncDeviceProfileURL, "DeviceProfileURL") == 0);
    assert(strcmp((const char *)kColorSyncDeviceModeDescriptions, "DeviceModeDescriptions") == 0);
    assert(strcmp((const char *)kColorSyncDeviceDefaultProfileID, "DeviceDefaultProfileID") == 0);
    assert(strcmp((const char *)kColorSyncDeviceDescriptions, "DeviceDescriptions") == 0);
    assert(strcmp((const char *)kColorSyncFactoryProfiles, "FactoryProfiles") == 0);
    assert(strcmp((const char *)kColorSyncDeviceUserScope, "DeviceUserScope") == 0);
    assert(strcmp((const char *)kColorSyncDeviceHostScope, "DeviceHostScope") == 0);
    assert(strcmp((const char *)kColorSyncPrinterDeviceClass, "prnt") == 0);
    assert(strcmp((const char *)kColorSyncCustomProfiles, "CustomProfiles") == 0);
    assert(strcmp((const char *)kColorSyncDisplayDeviceClass, "mntr") == 0);

    CFStringRef all[] = {
        kColorSyncDeviceProfileURL,
        kColorSyncDeviceModeDescriptions,
        kColorSyncDeviceDefaultProfileID,
        kColorSyncDeviceDescriptions,
        kColorSyncFactoryProfiles,
        kColorSyncDeviceUserScope,
        kColorSyncDeviceHostScope,
        kColorSyncPrinterDeviceClass,
        kColorSyncCustomProfiles,
        kColorSyncDisplayDeviceClass,
    };
    int count = sizeof(all) / sizeof(all[0]);
    for (int i = 0; i < count; i++) {
        for (int j = i + 1; j < count; j++) {
            assert(all[i] != all[j]);
            assert(strcmp((const char *)all[i], (const char *)all[j]) != 0);
        }
    }

    puts("PASS: ColorSync device constants verified via extracted object");
    return 0;
}
""")
    probe_bin = os.path.join(tmpdir, "probe")
    subprocess.check_call(["clang", "-fsanitize=address,undefined", "-fno-sanitize-recover=undefined", probe_c, defs_o, "-o", probe_bin])
    subprocess.check_call([probe_bin])

print("PASS: all ColorSync device constants defined and declared correctly")
