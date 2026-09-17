# Darling Applications integration

This directory contains the small, prefix-safe backend used by an Applications
viewer.  The viewer must never run a Linux `brew`, copy host applications into a
guest, or expose a temporary prefix as persistent state.

The persistent Darling prefix is selected explicitly (normally
`~/.darling-apps`).  Homebrew belongs at `/opt/homebrew` in that prefix and
applications installed by casks belong at `/Applications`.  A Brewfile is
copied into the prefix before invoking guest `brew bundle`; its source path is
never passed as a host path to a guest process.

`homebrew-actions.py` implements the two viewer actions:

* `install-homebrew` invokes a configured, checksum-verifying guest bootstrap.
* `install-brewfile` stages a Brewfile inside the prefix and runs native
  `/opt/homebrew/bin/brew bundle --file ...` through Darling.

The helper refuses a missing/stopped prefix, symlink escapes, host `brew`, and
MAS entries unless the caller explicitly confirms the Apple ID/login step.
It does not delete existing Applications, Homebrew, or user data.

On an Omarchy Wayland session the native viewer selects Wayland by default when
no backend is explicitly set, unsets `DISPLAY`, and child apps inherit that
socket/backend. X11 is explicit opt-in via `DARLING_APPKIT_BACKEND=x11`; it is
never reported as native Wayland. The active image must contain the provenance-
pinned `Wayland.backend` bundle.

The current native bootstrap evidence is recorded outside the source tree in
`~/.local/share/darling/macos-apps/brew/PROGRESS.md`; official bottle payloads
are intentionally not committed.
