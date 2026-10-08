# OSType conversion regression

Apple's published [Adopting Uniform Type Identifiers guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/understanding_utis/understand_utis.tasks/understand_utis_tasks.html)
permits a four-character printable ASCII literal such as `CFSTR("TEXT")` as an
OSType tag. The public [encoding](https://developer.apple.com/documentation/coreservices/1442804-utcreatestringforostype)
and [decoding](https://developer.apple.com/documentation/coreservices/1450472-utgetostypefromstring)
functions convert between a tag and its integer OSType (clean-room rung 3).
The vendored `LaunchServices/UTType.h` establishes the signatures (rung 2).
The OSS CoreFoundation `CFString.h` comments establish that direct string pointers
may be null and storage must not determine the result (rung 1/2).

The three guest cases check creation and roundtrip of `0x54455854`, literal
`TEXT` decoding, and roundtrip from external UTF-16 storage. The indirect fixture
explicitly checks that `CFStringGetCStringPtr` returns null before decoding.
No padding, non-ASCII encoding, embedded-null or invalid-input contract is asserted.
The existing null and overlong checks remain in the implementation.

The focused builder compiles the complete `UTType.m` translation unit and builds
a guest executable from the two unchanged function definitions extracted from it.
This exercises the owning source with the real guest CoreFoundation, without
inventing database mocks or requiring the unrelated FMDB runtime. It does not
verify a full LaunchServices framework link or Messages calling these APIs.
The build technique follows the focused UIKit harness's explicit Darling headers
and Darwin linker dependency mapping; no Linux headers are used.

Populate independent dependencies at the superproject's recorded gitlinks,
including CoreFoundation's nested swift-corelibs-foundation checkout. The complete
translation unit additionally needs FMDB, cctools and Security headers. Configure
and compile only under the shared build lock:

```sh
flock /tmp/agent-locks/darling-heavy-build.lock python3 \
  src/frameworks/CoreServices/tests/build-ostype.py \
  --source-root . --runtime-root "$runtime/libexec/darling" \
  --build-dir "$scratch/build" --linker "$darwin_linker"
```

Use a fresh private DPREFIX, bootstrap with the snapshot's non-setuid launcher
`shell true`, and replace its host-home bridge symlinks with empty directories
before tests. For each of `create`, `decode`, and `indirect`, run:

```sh
DPREFIX="$scratch/prefix" DARLING_INSTALL_PREFIX="$runtime" \
  "$launcher" shell "/Volumes/SystemRoot$scratch/build/ostype" indirect
```

Each corrected case exits 0 and prints `PASS: OSType TEXT conversion`. Baseline
creation and literal decoding exit 1; the baseline indirect case reaches its
fixture checkpoint and fails while dereferencing the null pointer. Shut down
only this prefix with the launcher `shutdown`; do not signal guest processes.
Generated extraction, commands, dependency files and build artifacts stay in the
scratch build directory and must not be committed or installed from dirty source.
