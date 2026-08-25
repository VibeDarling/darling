# Darling Developer Guide for AI Agents (`AGENTS.md`)

This guide provides technical instructions, conventions, and patterns for AI agents working on the **Darling** codebase (macOS emulation and translation layer for Linux).

---

## 1. Architectural Overview

Darling enables macOS binaries (Mach-O) to run natively on Linux by providing:
1. **`libsystem_kernel` (`src/external/xnu`)**: Userspace emulation of BSD syscalls and Mach traps.
2. **`dserver` / Mach IPC**: Coordination daemon for Mach ports, tasks, threads, and semaphores.
3. **`dyld` (`src/external/dyld`)**: Dynamic linker supporting macOS Mach-O binaries and shared libraries.
4. **Native Frameworks & Libc**: macOS libc (`src/external/libc`), CoreFoundation, Foundation, and system frameworks.
5. **Prefix / Container (`~/.darling`)**: Isolated filesystem tree mapping `/` for Darwin processes (`/Volumes/SystemRoot`, `/opt/`, `/usr/`, `/Library/`).

---

## 2. Emulating BSD System Calls in `libsystem_kernel`

When a program fails with `Unimplemented syscall (NNN)`:

### Step 1: Identify the Syscall
Inspect the macOS SDK syscall definitions in:
`Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/sys/syscall.h`
Find the matching number `SYS_<name>`.

### Step 2: Create Header and Implementation
All BSD syscall emulations reside under:
`src/external/xnu/darling/src/libsystem_kernel/emulation/`

1. **Header file**: `include/xnu_syscall/bsd/impl/<category>/<syscall_name>.h`
   ```c
   #ifndef LINUX_PREADV_H
   #define LINUX_PREADV_H

   #include <sys/types.h>
   #include <sys/uio.h>

   long sys_preadv(int fd, struct iovec* iovp, unsigned int len, long long ofs);
   long sys_preadv_nocancel(int fd, struct iovec* iovp, unsigned int len, long long ofs);

   #endif // LINUX_PREADV_H
   ```

2. **Source file**: `src/xnu_syscall/bsd/impl/<category>/<syscall_name>.c`
   ```c
   #include <darling/emulation/xnu_syscall/bsd/impl/<category>/<syscall_name>.h>
   #include <darling/emulation/common/base.h>
   #include <darling/emulation/conversion/errno.h>
   #include <darling/emulation/linux_premigration/linux-syscalls/linux.h>
   #include <darling/emulation/xnu_syscall/bsd/helper/bsdthread/cancelable.h>

   long sys_preadv(int fd, struct iovec* iovp, unsigned int len, long long ofs)
   {
       CANCELATION_POINT();
       return sys_preadv_nocancel(fd, iovp, len, ofs);
   }

   long sys_preadv_nocancel(int fd, struct iovec* iovp, unsigned int len, long long ofs)
   {
       long ret;

       ret = LINUX_SYSCALL(__NR_preadv, fd, iovp, len, LL_ARG(ofs));
       if (ret < 0)
           return errno_linux_to_bsd(ret);

       return ret;
   }
   ```

### Step 3: Register in Syscall Table
Edit `src/external/xnu/darling/src/libsystem_kernel/emulation/src/xnu_syscall/bsd/bsd_syscall_table.c`:
1. Add include for your header:
   ```c
   #include <darling/emulation/xnu_syscall/bsd/impl/<category>/<syscall_name>.h>
   ```
2. Add table entry at index matching the syscall number:
   ```c
   [540] = sys_preadv,
   [542] = sys_preadv_nocancel,
   ```

### Step 4: Register in `CMakeLists.txt`
Add the `.c` file to `set(xnu_syscall_bsd_sources ...)` in:
`src/external/xnu/darling/src/libsystem_kernel/emulation/CMakeLists.txt`

---

## 3. Best Practices & Rules for Syscall Implementations

- **Use `long` for return types**: Syscall functions and `LINUX_SYSCALL` return `long`. Never store the result in `int` (avoids 32-bit truncation on 64-bit transfers >2 GB).
- **Use `LL_ARG(offset)`**: For 64-bit file offsets/arguments, `LL_ARG` ensures proper splitting across registers on 32-bit architectures (i386) while passing cleanly on 64-bit (x86_64).
- **Convert Errno**: Always translate negative Linux error returns using `errno_linux_to_bsd(ret)`.
- **Cancellation Points**: Use `CANCELATION_POINT();` in the cancelable variant and delegate to `_nocancel(...)`.
- **No Magic Numbers**: Define all opcodes, bitmasks, and flags as named `#define` constants in the header file (e.g. `XNU_ULF_WAIT_CANCEL_POINT`).
- **Silence Unused Parameters in Stubs**: Explicitly cast unused parameters with `(void)param;` and include an explanatory `// NOTE:` / `// TODO:` comment.

---

## 4. Building, Installing & Running

### Building Darling
Always build from the `build/` directory:
```bash
cd /path/to/darling/build
make -j$(nproc)
sudo make install
```

### Running and Managing the Container
- **Run command in Darling container**:
  ```bash
  darling shell <command>
  ```
- **Execute Mach-O binary directly**:
  ```bash
  darling /path/to/mach-o/binary
  ```
- **Stop Darling container & dserver**:
  ```bash
  darling shutdown
  ```
- **Reset Darling prefix completely**:
  ```bash
  darling shutdown
  rm -rf ~/.darling
  darling shell echo "Clean prefix initialized"
  ```

---

## 5. Writing and Running Tests

### Guidelines for Unit Tests
1. Add new tests as pure C source files under `tests/src/<test_name>.c`.
2. Use standard assertions (`assert()`) and return `0` on success.
3. **Do NOT commit precompiled `.bin` files or `.stdout` files** to Git.

### Cross-Compiling Mach-O Test Binaries from Host Linux
To build Mach-O test executables using the in-tree toolchain headers and ld64:
```bash
DARLING_ROOT="/home/fervi/darling"

# 1. Compile C to Mach-O object
clang -target x86_64-apple-darwin20 -arch x86_64 \
    -mmacosx-version-min=11.0 -nostdinc \
    -D__DARWIN_ONLY_UNIX_CONFORMANCE=1 \
    -D__DARWIN_ONLY_64_BIT_INO_T=1 \
    -D__DARWIN_ONLY_VERS_1050=1 \
    -D__DARWIN_UNIX03 -D_DARWIN_C_SOURCE \
    -I"$DARLING_ROOT/basic-headers" \
    -I"$DARLING_ROOT/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include" \
    -isystem /usr/lib/llvm-21/lib/clang/21/include \
    -Wno-everything -c "$DARLING_ROOT/tests/src/preadv_pwritev.c" -o /tmp/test_preadv_pwritev.o

# 2. Link with in-tree ld64
"$DARLING_ROOT/build/src/external/cctools-port/cctools/ld64/src/x86_64-apple-darwin20-ld" \
    -macosx_version_min 11.0 \
    -syslibroot "$DARLING_ROOT/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" \
    -lSystem /tmp/test_preadv_pwritev.o -o /tmp/test_preadv_pwritev

# 3. Execute under Darling
darling /tmp/test_preadv_pwritev
```

---

## 6. Package Managers (Nanobrew / Homebrew)

- **Prefix location**: `/opt/nanobrew` (requires `mkdir -p ~/.darling/opt`).
- **Binary path**: `/usr/local/bin/nb`.
- **Working directory warning**: When invoking `darling shell /usr/local/bin/nb ...`, avoid running from the Darling source root directory to prevent relative symlink creation in the project workspace.
- **Handling CDN Rate Limits**: If parallel downloads fail with `DownloadFailed (network error after retries)`, re-running or installing packages sequentially resolves the CDN rate-limiting safely.
