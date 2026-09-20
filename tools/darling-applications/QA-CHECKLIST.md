# Applications viewer QA profile

`run-qa-profile.sh` launches the Applications viewer in a disposable prefix on
native Wayland, so a build can be exercised without touching a persistent
prefix or the installed runtime.

## Running it

Build the viewer first, then point the script at that build:

```sh
export DARLING_VIEWER_OUTPUT=<build-standalone.py output directory>
bash tools/darling-applications/run-qa-profile.sh
```

The script resolves the bundle from that build's `manifest.json` and verifies
it still matches the hashes the build recorded. It initializes only its own
prefix (`~/.darling-qa` unless `DARLING_QA_PREFIX` says otherwise), stages the
viewer plus the TextEdit and Stickies bundles, and on exit shuts down that
prefix alone.

Two safeguards are worth knowing about, because both will stop the run rather
than guess:

* It refuses a prefix it did not initialize itself, so it cannot stage over a
  persistent prefix that was passed in by mistake.
* It checks the host for a live container on the prefix before staging. A free
  lock file only means no lock-taking caller is running; it never proves the
  runtime is free.

## Manual checks

1. Scroll rapidly, diagonally and vertically. Scrolling should retain both axes
   without bursts or missing total movement.
2. Resize the viewer. Icons should stay sharp, the grid should fit, and the
   status strip should stay below the buttons with readable tooltips.
3. Import a directory containing nested apps. Check progress reporting,
   cancellation, collision preservation, and that no partial `.importing-*`
   bundles are left behind.
4. Double-click the TextEdit and Stickies rows and confirm each opens on native
   Wayland. Do not save documents in this disposable profile.
5. Copy Unicode text between Linux, TextEdit and Stickies, in both directions.
6. In TextEdit select `alpha beta`, right-click inside `beta`, and confirm the
   original selection is preserved.

## Known limits

Ruby 4 and the Homebrew packages are not ready; Ruby still raises
`wrong argument type false (expected Class)`.

The prefix-initialization work has been validated only as an unprivileged
candidate binary. Staging a privileged setuid candidate was rejected on review
and that rejection stands, so no privileged installed-runtime behaviour is
covered here. Nothing in this profile modifies the installed launcher.

**The manual checks above have not been run yet.** The profile is verified up to
and including launching the viewer, but on this machine the viewer starts into a
healthy container and **no window appears**, so none of the six checks can be
performed. The cause is not yet established.

What is known: the installed runtime does ship
`AppKit.framework/.../Backends/Wayland.backend` with its executable, while
`CoreGraphics.framework/.../Backends` has only `X11.backend`. Whether AppKit's
Wayland path needs a matching CoreGraphics backend is an open question, not a
diagnosis.

Do not diagnose this by listing a stopped prefix. A prefix that is not running
shows only a directory skeleton: the *working* `X11.backend` also appears to have
an empty `Contents/MacOS` there, so an apparently missing backend binary in a
stopped prefix is an artifact of the inspection, not a finding.

If you stage a backend yourself, require the bundle layout rather than the name:
a build tree contains a same-named directory of generated protocol sources, and
the loadable bundle only exists after the install step.
