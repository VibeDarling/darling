# How fast OpenGL ES frames reach the screen

`ios-gl-bench.m` draws as a game does: a full-screen, opaque `CAEAGLLayer`
view with a `UILabel` over it (a score), presented from a `CADisplayLink`.
After a second of warming up it counts frames for `BENCH_SECONDS` (5) and
prints the frame rate and how long `-presentRenderbuffer:` took. Then
`ios-gl-bench.sh` checks that the host shows the last frame (a green square
on red) with the label over it, and taps to quit.

```sh
# build ios-gl-bench.m as ios-opengles.m is built (see ios-opengles.md)
DARLING=darling tests/ios-gl-bench.sh ./pocket-host /path/in/prefix/ios-gl-bench out
```

`SCREEN` is the host's screen (`720x1280@2`), `BENCH_SECONDS` how long to
count, and `BENCH_ENV=DARLING_EAGL_TRACE=1` makes OpenGLES log, every
second, how long presenting spent reading frames back and showing them.
`POCKET_HOST_RGBA=1` makes pocket-host compose as Android's display does.

## Where a frame goes

1. **Read back.** `glReadPixels`, as BGRA when the host has
   `GL_EXT_read_format_bgra` (the window's order), into a buffer reused from
   the frame before.
2. **Drawn into the window.** UIKit draws the layer's contents as part of
   the view. An opaque GL view is the opaque view AppKit draws from, so
   nothing behind it is drawn again. The views in front of it that overlap
   (the label) are drawn again over it. Onyx2D copies an image drawn pixel
   for pixel (whole-pixel offsets, perhaps flipped, a rectangular clip) a
   row at a time instead of resampling it.
3. **Presented.** The window's pixels are copied into the buffer it shares
   with the host.
4. **Composed.** The host copies the part that changed, then composes the
   windows into its screen. Nothing under an opaque window that covers the
   screen is composed, and the copying loops are vectorized.

## Results

In an arm64 VM under TCG (Mesa llvmpipe, 720x1280, a loaded host, so only
roughly): 3.6 fps before, presenting 175 ms (25 ms reading back, 140 ms
showing). After: showing about 70 to 80 ms. Most of what is left there is
the label's text, drawn again each frame, and the emulated CPU.
