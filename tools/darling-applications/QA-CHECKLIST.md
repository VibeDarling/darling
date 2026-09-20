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
and including launching the viewer, but a prefix takes its frameworks from the
*installed* runtime, and a runtime whose payload predates the AppKit Wayland
backend gives the viewer no surface to draw on: the container comes up healthy
and no window appears. The profile refuses in that case rather than starting an
invisible viewer, so run it against a runtime that ships `Wayland.backend`, or
point `DARLING_VIEWER_IMAGE` at an installed image that provides one. Note that
a plain build tree does not: `AppKit/Wayland.backend` there is generated
protocol source, and the loadable bundle comes from the install step.
