#!/usr/bin/env python3
import json
from pathlib import Path
import re
import subprocess
import sys


def check(condition, message):
    if not condition:
        sys.exit('FAIL ' + str(message))


# Inspect only the output of our source-framework recipe.
output = Path(sys.argv[1]).resolve()
commands = json.loads((output / 'commands.json').read_text())
binary = output / 'Symbols.framework/Versions/A/Symbols'
check(Path(commands[1][-1]).resolve() == binary, 'link output is not the framework binary')
framework = Path(__file__).resolve().parents[1] / 'src/frameworks/Symbols'
cmake = (framework / 'CMakeLists.txt').read_text()
headers = subprocess.check_output(['llvm-objdump', '--macho', '--private-headers', str(binary)], text=True)
start = headers.index('cmd LC_ID_DYLIB')
identity = headers[start:headers.find('Load command', start + 1)]
check('/System/Library/Frameworks/Symbols.framework/Versions/A/Symbols' in identity, identity)
for key, label in [('DYLIB_COMPAT_VERSION', 'compatibility'), ('DYLIB_CURRENT_VERSION', 'current')]:
    version = re.search(r'set\(' + key + r' "([^"]+)"\)', cmake).group(1)
    check(label + ' version ' + version in identity, identity)
expected = set(re.findall(r'^\.globl (\S+)', (framework / 'src/Symbols.S').read_text(), re.M))
symbols = subprocess.check_output(['llvm-nm', '--defined-only', '--extern-only', str(binary)], text=True)
exports = {line.split()[-1] for line in symbols.splitlines() if line.split()}
check(not expected - exports, sorted(expected - exports))
print(f'PASS canonical framework identity, versions and {len(expected)} interface exports')
