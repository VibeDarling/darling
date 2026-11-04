# Guarded missing-symbol diagnostics

Use this only when diagnostic placeholders have been explicitly requested.
It does not implement the reported APIs or permit an app to run normally.

Generate sources from a filtered demand scan of an imported guest app:

```sh
python3 tools/darling-applications/guarded-symbol-stubs.py \
  --scan /scratch/scan/apps-filtered.json \
  --output /scratch/guarded-sources \
  --runtime-root /scratch/committed-image/usr/local/libexec/darling \
  --runtime-root-is-darling-output
```

The tool reads install names from images under `--runtime-root` with
`llvm-objdump --macho --dylib-id`. AGENTS.md section 1 allows that only on
Darling's own build output, so the tool refuses to run unless
`--runtime-root-is-darling-output` is passed. The flag is an attestation, not a
check: never point the root at a macOS install or a volume copied from one.

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

Review and commit the generator before staging any
build output into a fresh private prefix. Verify all requested exports with
`llvm-nm`, then run the real loader path and confirm the explicit refusal rather
than reporting binding success as API compatibility. Keep runtime/source pins,
commands, hashes and test results in private scratch records.

Never commit the scan, generated sources, symbol lists, manifest or binaries.
The output directory contains an ignore-all file as an additional safeguard.
Do not stage these diagnostic images into a shared or installed runtime.

The generic generation regression uses only authored interfaces:

```sh
python3 tools/darling-applications/test-guarded-symbol-stubs.py
```
