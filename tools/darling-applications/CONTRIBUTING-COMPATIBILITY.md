# Contributing app and library compatibility fixes

The dated app scans are a starting point. Imported app versions, Darling
builds, and dependency graphs change; reproduce the issue before coding.
The scanner reports direct imports. A library that is absent cannot have its
own indirect dependencies inspected until a real binary is available.

## Reproduce and choose a fix

1. Use a legally obtained copy of the app. Record its version, executable
   architecture, Darling commit, and prefix. Run
   `tools/darling-applications/scan-imported-apps.py` with
   `VIBEDARLING_APP_ROOT`, `VIBEDARLING_EXTRA_APP`,
   `VIBEDARLING_INSTALLED_ROOT`, and `VIBEDARLING_SCAN_OUTPUT` set as needed.
   Set `VIBEDARLING_TRANSITIVE=1` to inspect dependencies of images that exist.
2. Confirm every reported install name with `llvm-otool -l` and every imported
   symbol with `llvm-nm -u`. Distinguish absent libraries, incompatible
   architecture, and missing exports from a present library. Check weak imports
   separately. A static clean result is not a successful launch.
3. Search the appropriate local Darling repository for an implementation and
   inspect current source and binaries. An existing framework may only need an
   install-path alias, an arm64 build, a re-export, or a real missing method.
   Put the fix in its owning repository and preserve unrelated local changes.
4. If the library is entirely missing, look for an open-source implementation
   with a usable license and API surface. Verify its current repository and
   code rather than relying on a project name. For example, OpenSwiftUI and
   OpenAttributeGraph are relevant to SwiftUI, while OpenCombine supplies
   Combine. A project for another platform may be a useful backend, but it is
   not automatically an ABI-compatible replacement.
5. For a viable open-source project, create or update its fork under
   `cristim`. Pin a commit in the Darling build; keep Darling-specific changes
   in small patches when possible, and propose general improvements upstream.
   Build for the app's architecture with the required module name, install
   name, Swift resilience settings, and dependencies. Compare exported names
   with the app's exact imports. Do not count empty symbol stubs as a fix.
6. If there is no usable open-source implementation, document the API contract
   from public sources and implement the smallest functional slice needed by
   the app in Darling. Track any daemon, storage, graphics, or system service
   the library needs. A linkable shim without working behavior is unfinished.
7. Make focused commits and PRs in the owning local repositories. Roll the
   changes into a disposable local Darling integration prefix containing all
   relevant fixes and the imported apps. Rescan, launch, exercise the app's
   core workflow, and record exact commands, logs, remaining gaps, and new
   indirect dependencies. Update the app and library issues as evidence moves.

## Using AI tools well

AI tools can map symbols to source, compare candidate projects, draft patches,
and generate focused tests. Give the tool the current executable and scanner
output, the exact missing symbols or load path, the owning source tree, and the
target architecture. Ask it to inspect actual code and build artifacts before
proposing a change. Useful prompts ask for:

> Identify the smallest functional implementation for these exact imports.
> Verify the candidate license and source, preserve the required Mach-O install
> name and Swift module ABI, add a focused behavior test, build in the local
> Darling integration prefix, and report which imports and workflows remain.

Review generated code for invented APIs, guessed Swift mangling, hidden stubs,
license problems, and tests that merely mirror an implementation. Verify with
the compiler, exported-symbol comparison, Darling runtime, and the app's real
workflow. Attach evidence to the PR and issue so another contributor can
reproduce the result.

For Brewfile casks, first get the Darling Applications viewer's native
Homebrew and Brewfile actions working end to end. Then scan every installed
cask app with the same process; keep MAS entries separate because they need
the App Store service. Cask installation alone does not prove an app runs.
