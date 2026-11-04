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

VibeDarling is a development fork of [Darling](https://github.com/darlinghq/darling),
a compatibility layer for running macOS software on Linux without a virtual machine.
It builds on the work of the Darling project and the open-source components it integrates.

“Vibe” refers to **vibe coding**: AI coding agents are the primary development
tools used in this fork. VibeDarling provides a home for that development approach,
with its own testing and review process. Upstream Darling has
[expressed reservations about AI-generated contributions](https://github.com/darlinghq/darling/pull/1753#issuecomment-4949512178),
while leaving room to review smaller changes with supporting tests. Contributions
to this fork are reviewed here; acceptance here does not imply upstream acceptance.

## Quick links

[Releases](https://github.com/VibeDarling/darling/releases) &bull;
[Bug tracker](https://github.com/VibeDarling/darling/issues) &bull;
[Known issues](known-issues.md) &bull;
[Development notes](CLAUDE.md) &bull;
[Upstream Darling documentation](https://docs.darlinghq.org/)

## Project status

The goal of this fork is to run unmodified macOS applications distributed through
Homebrew casks and exercise their core workflows. Work spans ARM64 and x86_64
loading, Darwin runtime services, AppKit, Swift interoperability, and graphics.
Application compatibility is experimental and depends on the app version,
architecture, frameworks, and runtime build. Installing an app, resolving its
symbols, or opening a window does not establish that its workflows work.

Darling consists of a Mach-O binary loader and a userspace kernel server
(`darlingserver`) implementing Mach IPC, POSIX, and Darwin syscall interfaces on
Linux, alongside framework implementations including Foundation, AppKit (based
on Cocotron), CoreAudio, and CoreFoundation. Low-level components draw on
[Apple's open-source releases](https://github.com/apple-oss-distributions).
Graphics work includes X11 and Wayland backends and Metal-to-Vulkan translation;
these remain areas of active development.

See [known issues](known-issues.md) for recorded limitations and
[Darling Applications](tools/darling-applications/README.md) for the application
viewer and guest Homebrew integration. That integration has additional payload
and prefix setup requirements; it is not a general-purpose Homebrew installer.

## Getting started

### Packages

See this fork's [release page](https://github.com/VibeDarling/darling/releases)
for release notes and any attached packages. Entries may be source-only; if no
binary package is attached, use the source setup below. Check the architecture
and version of any package you choose: a release does not necessarily contain
the latest changes on `master`.

The original Darling project's [releases](https://github.com/darlinghq/darling/releases)
and [community packages](https://docs.darlinghq.org/community/packages.html) are
separate distribution channels. Do not assume they include VibeDarling changes.

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

For compatibility reports, include the application version and architecture,
Linux environment, Darling and submodule revisions, reproduction commands, and
logs. State whether the app installs, loads, launches, and completes the workflow
you tested. Keep Homebrew and application binaries unmodified when assessing
compatibility. The [framework-gap triage guide](docs/framework-gap-tiering.md)
can help investigate missing-library failures.

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
