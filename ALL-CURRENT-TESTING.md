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
`wrong argument type false (expected Class)`. The exact PR70/PR71 candidate
`b2cba87f7` has now passed the explicitly authorized temporary privileged gate:
root:root mode 4755, absent/empty boot and restart, marker preservation,
partial-prefix rejection, and cleanup all passed in
`/home/cristi/build/prefix-init-validation/rt-qqm201zf/results.json`.
This validates the candidate only; the installed launcher remains unchanged
(`f78b07ff...`) and no installed-runtime update is claimed. The original
automatic-review rejection and the later explicit authorization are preserved
in the shared handoff; temporary-candidate removal is still awaiting verified
Polkit cleanup.
