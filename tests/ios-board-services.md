# iOS board services

`ios-board-services.m` exercises the best-effort GraphicsServices,
RunningBoardServices and FrontBoardServices in `src/private-frameworks`:

- GraphicsServices: screen info defaults and `GSSetMainScreenInfo`,
  `GSCurrentEventTimestamp`, and `GSEventRunModal` switching to a pushed run
  loop mode and returning after `GSEventStopModal`.
- RunningBoardServices: `RBSProcessHandle` for the current process and by pid,
  the not-found error, and acquiring and invalidating an `RBSAssertion`.
- FrontBoardServices: `FBSSystemService` finds an installed app by bundle
  identifier, launches it, reports its pid, does not launch a second copy,
  terminates it, and reports a missing app as not found. `FBSSceneSettings`
  copies.

The app it launches is the test binary itself, installed as
`~/Applications/Sleeper.app`, so the test needs no other fixture. Launching it
depends on `posix_spawn` working, which needed the darling-xnu fix that renews
the Yama ptracer exception in every forked child (and, on arm64, checks the
child in with darlingserver before exec).

Build it like any Darling test program, linking `-framework GraphicsServices
-framework RunningBoardServices -framework FrontBoardServices -framework
Foundation`. To test it as an iOS binary on arm64, link it for macOS and set
the `LC_BUILD_VERSION` platform to 2 (iOS); it passes as both on a Raspberry
Pi 4, and as a macOS binary on x86_64. It prints one PASS/FAIL line per check
and exits nonzero on any failure.

Provenance: class names, selectors and option keys follow class-dumped iOS
headers (nst/iOS-Runtime-Headers and Theos); behaviour is our own, since
there is no FrontBoard or runningboardd behind them yet.
