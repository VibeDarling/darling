#!/usr/bin/env python3
"""A failed compile must not leave the output directory behind, so the same path can be retried."""
from pathlib import Path
import subprocess
import sys
import tempfile

recipe = Path(__file__).resolve().parents[1] / 'src/frameworks/Symbols/build-source.py'
failures = []
with tempfile.TemporaryDirectory(dir=Path.home()) as tmp:
    root = Path(tmp)
    output = root / 'out'
    command = [sys.executable, '-I', str(recipe), '--swiftc', '/bin/false', '--clang', '/bin/false',
               '--sdk', str(root), '--resources', str(root), '--guest-root', str(root),
               '--target', 'arm64-apple-macos13.0', '--minimum-os', '13.0',
               '--module-triple', 'arm64-apple-macos', '--output', str(output)]
    for attempt in (1, 2):
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode == 0:
            failures.append('attempt %d: a failing compiler reported success' % attempt)
        if 'Output must be a new directory' in result.stderr:
            failures.append('attempt %d: the failed first run left the output directory behind' % attempt)
        if output.exists():
            failures.append('attempt %d: output directory still exists' % attempt)
if failures:
    sys.exit('FAIL ' + '; '.join(failures))
print('PASS a failed build removes its output directory and can be retried')
