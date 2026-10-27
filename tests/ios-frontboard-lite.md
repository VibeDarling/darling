# FrontBoard-lite

`ios-frontboard-lite.m` drives `frontboardd` end to end. It installs two
copies of the UIKit app built from `ios-frontboard-lite-app.m` as
`~/Applications/LifecycleA.app` and `LifecycleB.app`, starts
`/usr/libexec/frontboardd --no-system-app` (so the home screen stays out
of the way), and through FrontBoardServices:

1. opens A: A gets `didFinishLaunching`, `didBecomeActive`;
2. opens B: B launches and becomes active, A gets `willResignActive`,
   `didEnterBackground`;
3. opens A again: the same process gets `willEnterForeground`,
   `didBecomeActive`, and B goes to the background;
4. sends the foreground app home: A goes to the background;
5. terminates both: each gets `applicationWillTerminate:` and exits, and
   frontboardd forgets them;
6. opens a missing app: not found.

Each app prints its callbacks to a log (the stdout path is a debugging
option of the open request), and the test compares each app's whole
sequence with what iOS would deliver. A backgrounded app's windows are
ordered out and come back with it, so only the foreground app is on
screen; `FBL_PAUSE=<seconds>` holds each switch for screenshots.

Run it as `ios-frontboard-lite <probe binary>` with a display. It passes on
x86_64 with the probe as a Mac Catalyst binary (platform 6, UIKit referenced
at `/System/Library/Frameworks/UIKit.framework/UIKit`), and on a Raspberry
Pi 4 with probe and test as iOS binaries (platform 2).
