# JIT

`ios-jit.c` checks what JIT-using iOS apps (emulators, UTM) need from Darling:

- `csops(CS_OPS_STATUS)` reports `CS_DEBUGGED`. On iOS that bit means a
  debugger is (or was) attached, which is when the kernel allows writable and
  executable memory; apps read it to decide whether to JIT at all. Linux
  already lets any process map such memory, so Darling always reports it.
- `mmap` with `MAP_JIT` and `PROT_READ|PROT_WRITE|PROT_EXEC`, toggled with
  `pthread_jit_write_protect_np`, one function rewritten 2000 times (a stale
  icache gives a wrong answer on cores that are not coherent).
- W^X with `mprotect`: write RW, flip to RX, run, and again.
- A dual mapping: `mach_vm_remap` with `copy = FALSE` gives an RW alias of an
  RX region; code written through the alias runs from the original.

Build it for arm64 (`-mcpu=apple-a7` for ARMv8.0 cores), link `-lSystem` and
set the `LC_BUILD_VERSION` platform to 2 (iOS). It prints one PASS/FAIL line
per check and exits nonzero on any failure. On a Raspberry Pi 4 all 15 pass.

Not covered: the iOS 26 scheme where an app hits a `brk` and expects an
attached debugger to map its JIT region.
