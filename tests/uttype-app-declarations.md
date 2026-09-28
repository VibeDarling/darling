# App-declared UTType regression

This fixture exercises the actual UTType implementation in an app executable.
Compile `uttype-app-declarations.m` and
`src/frameworks/UniformTypeIdentifiers/src/UTType.m` with the framework's normal
Darwin compiler/include flags and `-DUTType=DarlingMergedUTTypeProbe` for **both**
translation units. Link against Foundation and its normal system dependencies.
The class rename prevents undefined duplicate-class selection if the installed
UniformTypeIdentifiers framework is also loaded. The test supplies the two tag
class string constants normally defined by UniformTypeIdentifiers.m.

Place the resulting executable at `Probe.app/Contents/MacOS/probe` and copy
`uttype-app-declarations.plist` to `Probe.app/Contents/Info.plist`. Run that app
executable inside Darling. Require exit status zero and:

    PASS: merged UTType app declarations and built-in registry

The fixture covers constructor-time bundle discovery, exported/imported types,
forward parent references, malformed declarations and tags, case-insensitive
extension lookup, MIME lookup, app-over-built-in tag priority, exported-over-
imported duplicate priority, protected built-in objects, and dynamic round trips.

Validated on ARM64 with a staged working Darling runtime. This executable-level
test does not validate replacement-framework load ordering, concurrent first
loads, x86, all type declarations installed on a system, or every collision rule.
Registry contents are a snapshot at initialization, not a live LaunchServices
database. Existing built-in identifiers cannot be replaced by app declarations.
