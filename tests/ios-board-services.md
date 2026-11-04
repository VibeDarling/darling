# iOS board services

`ios-board-services.m` exercises DarlingBoard
(`src/private-frameworks/DarlingBoard`) with no frontboardd running, the
path where each call does its work in the calling process:

- `DBProcessIsAlive` for this process and for a pid that does not exist;
- `DBApplicationService` finds an installed app by bundle identifier,
  launches it, reports its pid (also found by `DBProcessesForApplication`),
  does not launch a second copy, terminates it, and reports a missing app
  as `DBOpenApplicationErrorNotFound`.

The app it launches is the test binary itself, installed as
`~/Applications/Sleeper.app`, so the test needs no other fixture. Launching it
depends on `posix_spawn` working, which needed the darling-xnu fix that renews
the Yama ptracer exception in every forked child (and, on arm64, checks the
child in with darlingserver before exec).

Build it like any Darling test program, linking `-framework DarlingBoard
-framework Foundation`. To test it as an iOS binary on arm64, link it for
macOS and set the `LC_BUILD_VERSION` platform to 2 (iOS). It prints one
PASS/FAIL line per check and exits nonzero on any failure.

Provenance: DarlingBoard is Darling's own interface; its names and
behaviour are not taken from Apple's, and no guest app links it.
GraphicsServices, FrontBoardServices and RunningBoardServices, which this
test used to cover with names recalled from class-dumped headers, now
export nothing (see their headers for why the frameworks are kept).
