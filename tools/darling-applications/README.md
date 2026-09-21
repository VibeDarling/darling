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

* `install-homebrew` runs the guest bootstrap gate described below.
* `install-brewfile` stages a Brewfile inside the prefix and runs native
  `/opt/homebrew/bin/brew bundle --file ...` through Darling.

The helper refuses a missing/stopped prefix, symlink escapes, and host `brew`.
MAS entries are always skipped: installing one needs an Apple ID and an App Store
purchase, neither of which is available under Darling, so there is deliberately no
option to attempt them.
It does not delete existing Applications, Homebrew, or user data.

On an Omarchy Wayland session the native viewer selects Wayland by default when
no backend is explicitly set, unsets `DISPLAY`, and child apps inherit that
socket/backend. X11 is explicit opt-in via `DARLING_APPKIT_BACKEND=x11`; it is
never reported as native Wayland. The active image must contain the provenance-
pinned `Wayland.backend` bundle.

`homebrew-bootstrap` is a gate, not an installer. It reports whether a payload
is already staged at `/opt/homebrew`, `/opt/nanobrew/prefix` or `/usr/local/bin`
in the prefix, and execs that payload's version command; it never downloads or
places anything. Exit 66 means nothing is staged, so the viewer's Homebrew
action reports rather than installs.

Payloads are staged out of tree, because official bottles are intentionally not
committed. The current native bootstrap evidence and the staging steps are
recorded in `~/.local/share/darling/macos-apps/brew/PROGRESS.md`.
