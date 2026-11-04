# Terminating call diagnostics

`raw-call-stubs.py` emits C formatting code and ARM64 assembly entry points for
exports independently established to be functions. These are diagnostic traps,
not compatibility implementations: the first call logs register interpretations
and exits 78. Never substitute them for working implementations.

Provide a JSON array with `symbol`, `kind` and `evidence` fields. Only
`kind: "function"` with an evidence reference generates an entry point. Class
data cannot be declared callable. Unknown/data exports receive name annotations
only and remain unresolved. Output must be a new scratch directory:

```
python3 tools/darling-applications/raw-call-stubs.py \
  --exports /scratch/exports.json --output /scratch/call-diagnostics
```

Each entry captures x0-x8, x20-x21, caller LR/SP and v0-v7 before entering C.
It prints integer widths 8/16/32/64, hexadecimal pointer bits, binary32 and
binary64 interpretations, and full 128-bit vector bits. No pointer is
dereferenced, no object description is requested, and no caller stack memory
is read. The snapshot itself is owned by the diagnostic entry point.

These are register slots, not numbered arguments. Unused registers may contain
unrelated values. Stack arguments, indirect aggregates, variadic arguments,
Objective-C selectors not established by headers, and architecture-specific
calling conventions cannot be reconstructed from this snapshot. `object` is
reported as an unverified address, never as an identified object. Printed
floating-point values reinterpret bits; they do not establish a floating-point
argument. Arguments cannot all be enumerated without a signature.

Names identify Objective-C class/metaclass data and recognizable Swift/C++
mangling prefixes. Swift's source-built demangler is used if available.
Lexical hints such as Notification, Identifier, Copy and Get are reported as
hints, not declarations of symbol kind, types, ownership or behavior.

Specification: Arm's published AAPCS64, sections 6.1 and 6.4, describes register
roles and 16-byte stack alignment:
https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst
The logger is original diagnostic code based on that public ABI specification;
no Apple implementation is examined. Mach-O relocation spelling is exercised
by compiling our own assembly with Clang.

Verification:

```
flock /tmp/agent-locks/darling-heavy-build.lock \
  python3 tools/darling-applications/test-raw-call-stubs.py
```

The native ARM64 fixture calls an authored function with -42, an invalid address
1, a double 3.25 and a float -2.5; the test checks capture and exit 78. The invalid
address verifies that pointer interpretation does not dereference it. Separate
tests compile Mach-O entry points and reject callable class data/missing evidence.
This does not establish execution in Darling or successful Messages startup.
