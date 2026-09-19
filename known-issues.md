# Known issues

## Darling Applications viewer + Cocotron on Wayland

### Applications viewer fixes landed (branch fix/applications-grid-icon-flip)
- Grid icons are mirrored around their own rect so rows below the first
  render upright and in place (commit 18d875e23, completing the flip fix
  landed in b23a5318b).
- Decoded app icons are cached in an NSCache across grid refreshes, so
  re-listing avoids re-reading each bundle and re-decoding its PNG/ICNS
  (commit ab2ff9068), removing the 20-30ms per-icon first-draw cost on
  scroll.
- The grid scrolls by one cell row per wheel notch instead of the coarse
  default step (commit 61c6d146a), and grid double-clicks launch by grid
  index rather than by table selection (commit 44fa9a5ca).

### TextEdit cursor drift with arrow keys (OPEN, not yet fixed)
- Symptom: in TextEdit, after using arrow keys within a line, the typing cursor
  drifts further and further from the typed text as more characters are typed on
  that line. A new line starts back at the correct position, then drifts right
  again as you type. Clicking inside a word lands the cursor in the middle of
  characters rather than at a character boundary.
- Suspected cause: NSLayoutManager/NSTextView glyph-to-character index mapping.
  Cocotron has no per-glyph char-index table on the fly; placement likely assumes
  fixed/avg glyph width (see `suggestEntryLocationForPoint:` and
  `characterIndexForGlyphAtIndex:` in `AppKit/NSTextView.subproj/NSLayoutManager.m`
  and NSTextView mouse/arrow handling).
- Confirmed NOT caused by the FreeType glyph-raster cache (commit 38757104):
  `showGlyphs:` advance semantics are byte-identical (`cached->advance >> 6`).
- TextEdit typing works on Wayland but not X11 (separate, also open).
