# Sound in an iOS app

`ios-audio.mm` plays tones through AudioQueue, as iOS games do (SDL's iOS
audio is an AudioQueue). It checks:

- The `AVAudioSession` takes the playback category and activates.
- For 44.1 kHz stereo 16-bit, then 22.05 kHz mono float, then the first
  format again (games stop and restart the queue for each song):
  - the queue is made and starts;
  - the device takes the first buffer within 3 seconds;
  - from then on, it takes the tone in real time (0.8 to 1.25 times). Taken
    faster would be a device that drops it; slower, one that stalls;
  - the queue stops.

It prints one PASS/FAIL line per check and exits nonzero on any failure.

It builds like `ios-uikit-classes.m` (see `ios-uikit-classes.md`), with
`-framework AVFoundation -framework AudioToolbox -framework Foundation`. It is
Objective-C++, since Darling's AudioToolbox headers need C++. Build it for
ARMv8.0 (`-mcpu=apple-a7`), as iOS arm64 apps are. Otherwise clang's default
macOS CPU uses LSE atomics, and ARMv8.0 phones (Exynos M3) get SIGILL.

Passes:
- on Android 13 (Galaxy Note10 Lite), on AAudio;
- on x86_64 Linux (as a macOS program), on PulseAudio.

In an arm64 VM under TCG, the device takes the tone at only 0.4 to 0.7 times
real time. The emulated render thread is too slow.

## Where the sound goes

CoreAudio's devices are the host's (`src/CoreAudio/CoreAudio`):

- **Android: AAudio** (`aaudio/`), when `libaaudio.so` opens.
  - A thread of ours calls the device's IOProc a period at a time and
    writes the result with AAudio's blocking write, which paces it.
  - Formats AAudio does not take (8-bit, 24-bit, 32-bit integers,
    big-endian) are converted to float.
  - AAudio resamples, so the stream is in the format the app asked for.
  - When headphones come or go, the stream is disconnected, and a new one is
    opened on the new route.
  - `DARLING_COREAUDIO_TRACE=1` logs each stream opened, and how many frames
    the device read when it closes.
  - Input has no streams yet (it would need `RECORD_AUDIO`).
- **Linux: PulseAudio** (`pulse/`).
  - A thread of ours renders a period at a time and writes it under the
    threaded main loop's lock as the stream takes it.
  - The stream holds three periods, as a device's buffer would.
    PulseAudio's default is about two seconds, which takes a whole song's
    first seconds at once.

Not obvious:

- **No Darwin code on the host's audio threads.** AAudio's and
  PulseAudio's callbacks run on threads that Darwin never made. Darling
  finds a thread's TSD by its Linux thread pointer, so those threads share
  one zero page. A lock taken there (malloc's, for one) corrupts it, and
  the main thread later aborts in `os_unfair_lock`. So the IOProc runs on a
  thread of ours. PulseAudio's write callback only wakes it, and AAudio
  gets no callback.
- **A stream's PulseAudio callbacks are cleared before it is disconnected.**
  PulseAudio's thread may still report a state change after the stream's
  object is gone.
- **AudioQueue starts its device with its mutex released.** Starting waits
  for the device, whose render thread may be waiting for that mutex in the
  IOProc.
