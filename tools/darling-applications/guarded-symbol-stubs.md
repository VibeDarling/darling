# Guarded missing-symbol diagnostics

Use this only when diagnostic placeholders have been explicitly requested.
It does not implement the reported APIs or permit an app to run normally.

Generate sources from a filtered demand scan of an imported guest app:

```sh
python3 tools/darling-applications/guarded-symbol-stubs.py \
  --scan /scratch/scan/apps-filtered.json \
  --output /scratch/guarded-sources \
  --runtime-root /scratch/committed-image/usr/local/libexec/darling
```

The output must be absent. Each generated Objective-C source defines requested
class/metaclass names and opaque addresses for other unresolved export names.
Those addresses deliberately specify neither callable signatures nor data
types. Every image terminates during initialization with an explicit diagnostic
and tool-defined exit status 78. Placeholder class initialization also terminates.
Removing these guards would expose invalid API/ABI assumptions.

Compile the generated sources as Mach-O dylibs for the selected architecture,
with their recorded install names, linking the committed runtime's libobjc and
libSystem. If a module records `reexport`, retain that original library using
the linker's re-export-library option. This preserves existing exports when an
iOSSupport alias has a distinct canonical implementation. Overwriting an
existing canonical image is rejected.

Use the shared build lock. Review and commit the generator before staging any
build output into a fresh private prefix. Verify all requested exports with
`llvm-nm`, then run the real loader path and confirm the explicit refusal rather
than reporting binding success as API compatibility. Keep runtime/source pins,
commands, hashes and test results in private scratch records.

Never commit the scan, generated sources, symbol lists, manifest or binaries.
The output directory contains an ignore-all file as an additional safeguard.
Do not stage these diagnostic images into a shared or installed runtime.

The generic generation regression uses only authored interfaces:

```sh
flock /tmp/agent-locks/darling-heavy-build.lock \
  python3 tools/darling-applications/test-guarded-symbol-stubs.py
```
