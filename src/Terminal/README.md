# Terminal

An iOS app (Objective-C, UIKit) that runs a shell on a pseudo-terminal. It
installs to `libexec/darling/Applications/Terminal.app` (bundle identifier
`org.darlinghq.terminal`), so SpringBoard-lite lists it, and in Darling Pocket
it is the terminal people get out of the box.

| File | What it is |
| --- | --- |
| `Terminal.m` | the pty session (`forkpty`, a reader thread), the root view and app delegate |
| `TerminalScreen.{h,m}` | the escape sequence parser and the cell grid, with scrollback |
| `TerminalView.{h,m}` | drawing, keyboard input, scrolling, the extra-keys bar |
| `Info.plist`, `AppIcon60x60*.png` | the bundle; `make-icon.py` redraws the icon |
| `set-ios-platform.py` | marks the linked binary as iOS (platform 2, iOS 14.0) |

## What it does

- **Shell:** `$SHELL`, else `/bin/bash`, else `/bin/sh`, as a login shell in
  `$HOME`, with `TERM=xterm-256color`, `COLORTERM=truecolor`, and `LANG`
  defaulting to `en_US.UTF-8`. The pty's window size (`TIOCSWINSZ`) follows
  the view. When the shell exits the screen says `[Process completed]`, and a
  tap starts a new one.
- **Emulation** (an xterm subset):
  - C0 controls: CR, LF/VT/FF, BS, HT, SO/SI.
  - Cursor: CUU/CUD/CUF/CUB, CNL/CPL, CHA/HPA/HPR, VPA/VPR, CUP/HVP, CHT/CBT,
    DECSC/DECRC and CSI s/u, IND/NEL/RI, HTS/TBC.
  - Editing: ED (0 to 3, 3 clears the scrollback), EL, ECH, ICH/DCH, IL/DL,
    SU/SD, REP, DECSTBM, insert mode (IRM).
  - SGR: bold (also brightens colors 0 to 7), faint, italic (stored but not
    drawn), underline, inverse, invisible, strikethrough; 16 and 256 colors and
    24-bit color, in the `;` and `:` forms.
  - Modes: DECCKM, DECOM, DECAWM, DECTCEM, alternate screen 47/1047/1049,
    1048.
  - Other: the DEC line-drawing set (`ESC ( 0`), DECALN, DSR 5/6, primary and
    secondary DA, OSC 0/2 (title, kept but not shown), UTF-8 with
    double-width characters.
  - Bracketed paste, mouse reporting and DCS strings are accepted and
    ignored. Unknown sequences are consumed without output.
- **Drawing:** a monospaced font through CoreText. It tries Menlo,
  DejaVu Sans Mono, Droid Sans Mono, Noto Sans Mono and others, accepts a
  font only if fontconfig really returns that family and its glyphs share one
  width, and falls back to fontconfig's `monospace`. Override with the
  `TerminalFontName` and `TerminalFontSize` defaults (12 pt by default). Only
  rows that changed are redrawn. Output is read on its own thread and handed
  to the main thread in batches, so a redraw covers a batch, not a byte.
  The cursor is a block, or an outline while the view is not first responder.
- **Scrollback:** 5000 lines. Drag down to look back; new output or typing
  brings the view back down.
- **Input:** the view adopts `UIKeyInput`, so becoming first responder asks
  the host for its keyboard. Text goes to the pty, Return sends CR, Delete
  sends DEL (0x7f). Key events also give arrows, Home/End, PgUp/PgDn,
  forward delete, F1 to F12, Shift-Tab, Ctrl-letters and Option as Meta.
  A tap brings the keyboard back. Below the terminal is a row of extra keys:
  esc, ctrl (latches for the next key), tab, the four arrows, `-` `/` `|` `~`.
- **Layout:** the terminal and the key row stay inside `safeAreaInsets`, and
  above the keyboard when UIKit posts `UIKeyboardWillChangeFrameNotification`.

## UIKit support it relies on

- `UIKeyInput` (`UIKit/UITextInput.h`), and iOS meanings for
  `-becomeFirstResponder`, `-resignFirstResponder`, `-canBecomeFirstResponder`
  and `-isFirstResponder` on any `UIView` (`src/frameworks/UIKit/src/UIKeyInput.m`).
- AppKit's Pocket backend shows the soft keyboard while the first responder
  adopts `UIKeyInput`, as it does for text fields.

## Not done

- Lines are cut or padded on a resize, not rewrapped.
- No selection, copy or paste; no bell; no title display; italic is not drawn;
  bold is drawn by striking twice rather than with a bold face.
- Glyphs missing from the chosen font show as the font's missing-glyph box
  (no per-character font fallback).
- UIKit does not post keyboard frame notifications yet, so on a phone the
  keyboard may cover the bottom rows until it does.

## Building and testing

Built with the rest of the `gui` component. On its own:

```sh
ninja -C build-arm64 src/Terminal/Terminal
DESTDIR=<staging> cmake -P build-arm64/src/Terminal/cmake_install.cmake
```

On a phone host stand-in (`tools/pocket-host`), from a shell where `darling`
runs:

```sh
pocket-host /tmp/pocket.sock 720x1280@2 48,0,32,0 < commands &
darling shell env DARLING_POCKET_DISPLAY=/tmp/pocket.sock /Applications/Terminal.app/Terminal
```

and write commands to pocket-host: `text echo hello`, `key 36` (Return),
`key 53` (Escape), `key 126` (Up), `shot out.png`. A non-root prefix keeps its
own `/Applications`, so copy `Terminal.app` there from the install first.
