<p align=center>
  <a href="https://darlinghq.org/">
    <img alt="Darling logo" src="https://darlinghq.org/img/darling250.png">
  </a>
</p>

---

<p align=center>
  <a href="https://github.com/VibeDarling/darling/releases/latest">
    <img alt="VibeDarling Latest Release" src="https://img.shields.io/badge/latest-release-0688CB.svg">
  </a>
  <a href="LICENSE">
    <img alt="License" src="https://img.shields.io/badge/license-GNU_GPL_3.0-E44E4A.svg">
  </a>
  <a href="https://opencollective.com/darlinghq">
    <img alt="Donate" src="https://img.shields.io/badge/%24-donate-FF813F.svg">
  </a>
</p>

# VibeDarling

VibeDarling is an experimental fork of [Darling](https://github.com/darlinghq/darling)
focused on running unmodified macOS applications on Linux without a virtual machine.
We use apps distributed through Homebrew casks to test everyday workflows and find
gaps in Darling's macOS compatibility.

The name comes from **vibe coding**. AI coding agents are a primary development
tool in the fork. We use them to investigate app failures, try compatibility
fixes, and turn our findings into reproducible reports and tests for Darling.

## Quick links

[Releases](https://github.com/VibeDarling/darling/releases) &bull;
[Bug tracker](https://github.com/VibeDarling/darling/issues) &bull;
[Known issues](known-issues.md) &bull;
[Development notes](CLAUDE.md) &bull;
[Upstream Darling documentation](https://docs.darlinghq.org/)

## Project status

Compatibility depends on the app version, architecture, and runtime build.
We track installation, loading, launch, and completion of a tested workflow
as separate milestones. Day-to-day development exercises ARM64, and work spans
ARM64 and x86_64 loading, Darwin runtime services, AppKit, Swift interoperability,
and graphics.

Darling's [Q4 2026 development update](https://blog.darlinghq.org/2026/11/08/development-update-q4-2026/)
credits VibeDarling's day-to-day ARM64 testing and describes plans to bring
work from the forks into mainline. When an upstream fix lands, we aim to rerun
the original app workflow and retire the overlapping fork patch once that
workflow passes.

Darling consists of a Mach-O binary loader and a userspace kernel server
(`darlingserver`) implementing Mach IPC, POSIX, and Darwin syscall interfaces on
Linux, alongside framework implementations including Foundation, AppKit (based
on Cocotron), CoreAudio, and CoreFoundation. Low-level components draw on
[Apple's open-source releases](https://github.com/apple-oss-distributions).
Graphics work includes X11 and Wayland backends and Metal-to-Vulkan translation;
these remain areas of active development.

See [known issues](known-issues.md) for recorded limitations and
[Darling Applications](tools/darling-applications/README.md) for the application
viewer and guest Homebrew integration, including its payload and prefix setup
requirements. The viewer runs Brewfiles using a Homebrew payload staged in
the guest prefix.

## Getting started

### Packages

To try a VibeDarling fix, check which revision contains it and choose a build
for your architecture. The [VibeDarling releases](https://github.com/VibeDarling/darling/releases)
page lists tagged versions and any attached packages. Use the source setup
below for a source-only release or a change available only on `master`.

For changes that have landed in mainline, check which revision is included in
[Darling's releases](https://github.com/darlinghq/darling/releases) or
[community packages](https://docs.darlinghq.org/community/packages.html).

### Building from source

Start with the dependencies described in the
[upstream build instructions](https://docs.darlinghq.org/build-instructions.html),
then read this fork's [local development notes](CLAUDE.md). Upstream instructions
provide background; build and architecture differences in this fork may require
additional setup.

Clone VibeDarling with its submodules and fetch the Swift Git LFS payloads
(requires Git LFS):

```sh
git clone --recurse-submodules https://github.com/VibeDarling/darling.git
cd darling
git -C src/external/swift lfs pull
```

Keep this checkout's `origin` pointing at VibeDarling when initializing
submodules: their relative URLs resolve against that remote. Use a separate
remote for pushing to a personal fork. For builds alongside an existing checkout,
follow the independent-clone guidance in the [development notes](CLAUDE.md).

After installing the build dependencies, configure an out-of-source Ninja build:

```sh
cmake -S . -B build -G Ninja
cmake --build build
ninja -C build -n
```

Check that the final dry run reports no remaining work. The development notes
also describe staging a runtime with `DESTDIR` and testing it in a disposable
prefix before installing it system-wide.

## Contributing

Submit issues and pull requests to [VibeDarling](https://github.com/VibeDarling/darling),
with component fixes in the corresponding VibeDarling submodule repository.
Read the [issue collaboration protocol](.claude/ISSUE_COLLABORATION.md) before
picking up an issue; it describes work claims, app testing, issue linkage, and
review requirements.

### Report an app workflow

Include the cask name, app version and architecture, Linux environment,
VibeDarling and submodule revisions, reproduction steps, and relevant logs.
State whether the app installs, loads, launches, and completes the workflow
you tested. Keep Homebrew and application binaries unmodified when assessing
compatibility. The [framework-gap triage guide](docs/framework-gap-tiering.md)
can help investigate missing-library failures.

### Share findings with upstream Darling

Darling accepts AI-assisted contributions
under its [clean-room and review policy](https://github.com/darlinghq/darling/blob/master/AGENTS.md).
VibeDarling has its own [contributor rules](AGENTS.md) for work in the fork.

When a workflow exposes a shared compatibility gap, keep the app reproduction
and isolate the underlying behavior in a focused test. For an upstream patch,
implement the API contract at the framework layer where the gap originates,
document the evidence for any undocumented behavior, and have a human author
who can explain the change and answer review questions. A reproduction and test
can help upstream even when the fork's implementation needs further work.

## License

The main project is licensed under the [GNU GPL 3.0](LICENSE). Individual
submodules and bundled components have their own licenses and notices; consult
their repositories when building or distributing a runtime.

## Usage

### Prefixes

Darling has support for DPREFIXes, which are very similar to WINEPREFIXes. They provide a macOS-like filesystem structure for installed software and its data. The default DPREFIX location is `~/.darling`, but this can be changed by exporting an identically named environment variable set to an absolute path. A prefix is automatically created and initialized on first use.

Please note that we use `overlayfs` for creating prefixes, and so we cannot support putting prefix on a filesystem like NFS or eCryptfs. In particular, the default prefix location won't work if you have an encrypted home directory.

### Hello world

Let's start with a Hello world:

````
$ darling shell echo Hello world
Hello world
````

Congratulations, you have printed Hello world through Darling's OS X system call emulation and runtime libraries.

### Installing software

#### Working with `.pkg` files

You can install `.pkg` packages with the installer tool available inside shell. It is a somewhat limited cousin of OS X's installer:

```sh
$ darling shell
Darling [~]$ installer -pkg mc-4.8.7-0.pkg -target /
```

> Darling does not support installing [`.mpkg`](https://github.com/darlinghq/darling/issues/1662) files yet

The Midnight Commander package from the above example is [available for download](https://darling-misc.s3.eu-central-1.amazonaws.com/mc-4.8.7-0.pkg).

You can uninstall and list packages with the `uninstaller` command.

#### Working with DMG images

DMG images can be attached and detached from inside `darling shell` with `hdiutil`. This is how you can install Xcode along with its toolchain and SDKs (note that Xcode itself doesn't run yet):

```sh
Darling [~]$ hdiutil attach Xcode_7.2.dmg
/Volumes/Xcode_7.2
Darling [~]$ cp -r /Volumes/Xcode_7.2/Xcode.app /Applications
Darling [~]$ export SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk
Darling [~]$ echo 'void main() { puts("Hello world"); }' > helloworld.c
Darling [~]$ /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang helloworld.c -o helloworld
Darling [~]$ ./helloworld
Hello world
```

Congratulations, you have just compiled and run your own Hello world application with Apple's toolchain.

#### Working with XIP archives

Xcode is now distributed in `.xip` files. These can be installed using `unxip`:

```sh
cd /Applications
unxip Xcode_11.3.xip
```
