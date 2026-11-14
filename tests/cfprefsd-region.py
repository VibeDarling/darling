#!/usr/bin/env python3
# Host test: the cfprefsd stand-in never reuses a pre-existing shared region and refuses to run without a trustworthy one.
# usage: CFPREFSD_GUEST_BIN=<guest path of the compiled tests/cfprefsd-service.c> python3 tests/cfprefsd-region.py
# The region is the host's /dev/shm/apple.cfprefs.daemonv1, one name for every container on the host: run this on a host where no
# other Darling session is using it, because the test plants and removes that name and ends the container (darling shutdown).
#  1. A region planted before the daemon starts (100 bytes, mode 0666) with a second hard link to the same object: after the daemon
#     has started, the second link must be unchanged (the daemon made a new object instead of growing and reusing the planted one),
#     and the region must be 16384 bytes, mode 0644.
#  2. A directory planted under the region's name: the daemon cannot make a region, so it must not answer (the guest test then
#     reports that nothing replied, or hangs on the reply: both count as "not answered").
import os
import stat
import subprocess
import sys

REGION = "/dev/shm/apple.cfprefs.daemonv1"
LINK = "/dev/shm/apple.cfprefs.daemonv1-planted-link"
guest_bin = os.environ.get("CFPREFSD_GUEST_BIN")
if not guest_bin:
    sys.exit("FAIL: set CFPREFSD_GUEST_BIN to the guest path of the compiled tests/cfprefsd-service.c")

def shutdown():
    subprocess.run(["darling", "shutdown"], capture_output=True)

def clean():
    for p in (LINK, REGION):
        try:
            if os.path.isdir(p) and not os.path.islink(p):
                os.rmdir(p)
            else:
                os.unlink(p)
        except FileNotFoundError:
            pass

def run_guest(timeout=180):
    return subprocess.run(["darling", "shell", guest_bin], capture_output=True, text=True, timeout=timeout)

def run_guest_retrying(timeout=180):
    # A cold container start can time out for reasons unrelated to the daemon (a few percent of boots were measured to: the unmutated
    # build timed out once in the first phase). One retry after a shutdown; two timeouts in a row are a failure.
    try:
        return run_guest(timeout)
    except subprocess.TimeoutExpired:
        shutdown()
        return run_guest(timeout)

try:
    shutdown()
    clean()
    fd = os.open(REGION, os.O_CREAT | os.O_WRONLY, 0o666)
    os.fchmod(fd, 0o666)
    os.ftruncate(fd, 100)
    os.close(fd)
    os.link(REGION, LINK)
    res = run_guest_retrying()
    if "PASS:" not in res.stdout:
        sys.exit(f"FAIL: the guest test did not pass with a planted region:\n{res.stdout}{res.stderr}")
    planted = os.stat(LINK)
    if planted.st_size != 100 or stat.S_IMODE(planted.st_mode) != 0o666:
        sys.exit(f"FAIL: the planted object was reused (size {planted.st_size}, mode {stat.S_IMODE(planted.st_mode):o})")
    region = os.stat(REGION)
    if region.st_size != 16384 or stat.S_IMODE(region.st_mode) != 0o644:
        sys.exit(f"FAIL: the region is size {region.st_size} mode {stat.S_IMODE(region.st_mode):o}, expected 16384 and 644")

    shutdown()
    clean()
    os.mkdir(REGION)
    try:
        res = run_guest(timeout=60)
    except subprocess.TimeoutExpired:
        # the request is never answered: the daemon refused to run, which is the expected outcome. A cold-boot timeout would look the
        # same, which is why phase 1 (which must see a PASS) is the check that the container and the daemon work at all.
        res = None
    if res is not None and "PASS:" in res.stdout:
        sys.exit(f"FAIL: the daemon answered although it could not create its region:\n{res.stdout}{res.stderr}")
    print("PASS: a planted region is replaced, and the daemon does not run without a region of its own")
finally:
    shutdown()
    clean()
