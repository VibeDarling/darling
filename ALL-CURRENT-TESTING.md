# All-current private integration test

This branch combines the current Darling application viewer, profile launcher,
and Cocotron Wayland fixes without modifying the installed runtime or persistent
Darling prefixes.

Run from a terminal in the active Wayland desktop session:

```sh
bash /home/cristi/src/darling-integration-all/tools/darling-applications/run-all-current-private.sh
```

The command verifies every private artifact hash, initializes only
`/home/cristi/.darling-all-current-test`, stages the viewer plus the verified
TextEdit and Stickies bundles, and launches the viewer through the native
Wayland backend. Closing the viewer shuts down only this test prefix.

Manual checks:

1. Rapidly scroll diagonally and vertically; scrolling should retain both axes
   without bursts or missing total movement.
2. Resize the viewer and confirm icons remain sharp, the grid fits, and the
   status strip stays below the buttons with readable tooltips.
3. Import a directory containing nested apps; check progress, cancellation,
   collision preservation, and absence of partial `.importing-*` bundles.
4. Double-click the TextEdit and Stickies rows and confirm each opens on native
   Wayland. Do not save documents in this disposable test profile.
5. Copy Unicode text between Linux, TextEdit, and Stickies in both directions.
6. In TextEdit select `alpha beta`, right-click inside `beta`, and confirm the
   original selection is preserved.

Known limits: Ruby 4/Homebrew package execution is not ready; Ruby still raises
`wrong argument type false (expected Class)`. The installed setuid launcher is
unchanged, so the combined PR70/PR71 launcher has host and non-root candidate
coverage but not a privileged installed-runtime gate.
