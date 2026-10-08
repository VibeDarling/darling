The authored ARC client passes borrowed NSURL/NSDictionary values through their
published CF bridge types to CGImageSourceCreateWithURL. It reproduces the
published MIT DodgeDanger texture source compilation failure. No image loading
or game runtime success is claimed by this syntax test.

From the Darling repository root, with `$BUILD` a configured Darling AppKit build tree:

```sh
python3 src/frameworks/ImageIO/tests/arc-bridging/build.py "$BUILD" --baseline
python3 src/frameworks/ImageIO/tests/arc-bridging/build.py "$BUILD"
```

Unmodified donor header: exit1, both casts require explicit bridges. Candidate:
exit0. The candidate reuses CGImageDestination.h's existing audited-region
macros. CGImageSource.m borrows input references and follows Create/Copy/Get
ownership; CFBase.h defines the auditing pragmas. No runtime behavior changes.
