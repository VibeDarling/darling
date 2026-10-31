/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

/* The terminal's view: draws the screen's cells in a monospaced font and
   turns typing into the bytes a terminal sends.

   Drawing is software (Onyx2D), where every fill and every glyph run costs
   a rasterizer pass, so only rows the screen reports as changed are
   invalidated, and a row is drawn as a few runs: one fill per stretch of
   background color and one glyph call per stretch of foreground color. */

#import "TerminalView.h"
#import <CoreText/CoreText.h>
#import <AppKit/NSEvent.h>
#include <stdio.h>

static void TerminalLog(NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	fprintf(stderr, "Terminal: %s\n", [line UTF8String]);
}

/* Pointer travel beyond which a touch scrolls instead of tapping. */
static const CGFloat TerminalTapSlop = 10;
/* Points around the grid. */
static const CGFloat TerminalPadding = 4;
static const CGFloat TerminalDefaultFontSize = 12;

/* The function key characters AppKit's key events carry (NSEvent.h), which
   is how arrows and the like reach a view here. */
enum {
	TerminalKeyUp = 0xF700,
	TerminalKeyDown = 0xF701,
	TerminalKeyLeft = 0xF702,
	TerminalKeyRight = 0xF703,
	TerminalKeyF1 = 0xF704,
	TerminalKeyF12 = 0xF70F,
	TerminalKeyInsert = 0xF727,
	TerminalKeyForwardDelete = 0xF728,
	TerminalKeyHome = 0xF729,
	TerminalKeyEnd = 0xF72B,
	TerminalKeyPageUp = 0xF72C,
	TerminalKeyPageDown = 0xF72D,
};

#pragma mark - Colors

typedef struct { CGFloat r, g, b; } TerminalRGB;

static const TerminalRGB TerminalDefaultForeground = { 0.90, 0.90, 0.88 };
static const TerminalRGB TerminalDefaultBackground = { 0.07, 0.08, 0.09 };
static const TerminalRGB TerminalCursorColor = { 0.85, 0.85, 0.82 };

/* The 16 basic colors (a softened xterm palette), then the 6x6x6 cube and
   the gray ramp of the 256-color set. */
static TerminalRGB TerminalPaletteColor(int index)
{
	static const uint8_t basic[16][3] = {
		{ 0x1c, 0x1f, 0x22 }, { 0xe0, 0x4b, 0x4b }, { 0x5f, 0xc1, 0x5a }, { 0xe0, 0xc0, 0x4a },
		{ 0x4a, 0x8c, 0xe8 }, { 0xc3, 0x6a, 0xd6 }, { 0x3f, 0xbf, 0xc8 }, { 0xcf, 0xcf, 0xca },
		{ 0x6a, 0x70, 0x76 }, { 0xff, 0x6e, 0x6e }, { 0x8a, 0xe6, 0x7e }, { 0xff, 0xe0, 0x6a },
		{ 0x74, 0xae, 0xff }, { 0xe0, 0x8c, 0xf0 }, { 0x6a, 0xe2, 0xea }, { 0xff, 0xff, 0xff },
	};
	TerminalRGB color;
	if (index < 16) {
		color.r = basic[index][0] / 255.0;
		color.g = basic[index][1] / 255.0;
		color.b = basic[index][2] / 255.0;
	} else if (index < 232) {
		int cube = index - 16;
		static const int levels[6] = { 0, 95, 135, 175, 215, 255 };
		color.r = levels[(cube / 36) % 6] / 255.0;
		color.g = levels[(cube / 6) % 6] / 255.0;
		color.b = levels[cube % 6] / 255.0;
	} else {
		CGFloat gray = (8 + (index - 232) * 10) / 255.0;
		color.r = color.g = color.b = gray;
	}
	return color;
}

static TerminalRGB TerminalResolveColor(TerminalColor color, TerminalRGB fallback)
{
	if (TerminalColorIsIndexed(color))
		return TerminalPaletteColor(color & 0xFF);
	if (TerminalColorIsRGB(color)) {
		TerminalRGB rgb = { ((color >> 16) & 0xFF) / 255.0, ((color >> 8) & 0xFF) / 255.0, (color & 0xFF) / 255.0 };
		return rgb;
	}
	return fallback;
}

static inline BOOL TerminalRGBEqual(TerminalRGB a, TerminalRGB b)
{
	return a.r == b.r && a.g == b.g && a.b == b.b;
}

/* A cell's colors once bold, inverse, faint and invisible are applied. */
static void TerminalCellColors(const TerminalCell *cell, TerminalRGB *foreground, TerminalRGB *background)
{
	TerminalColor fg = cell->foreground;
	/* Bold makes the first eight colors bright, as xterm does by default. */
	if ((cell->attributes & TerminalAttributeBold) && TerminalColorIsIndexed(fg) && (fg & 0xFF) < 8)
		fg = TerminalColorIndexed((fg & 0xFF) + 8);
	TerminalRGB f = TerminalResolveColor(fg, TerminalDefaultForeground);
	TerminalRGB b = TerminalResolveColor(cell->background, TerminalDefaultBackground);
	if (cell->attributes & TerminalAttributeInverse) {
		TerminalRGB swap = f;
		f = b;
		b = swap;
	}
	if (cell->attributes & TerminalAttributeFaint) {
		f.r = (f.r + b.r) / 2;
		f.g = (f.g + b.g) / 2;
		f.b = (f.b + b.b) / 2;
	}
	if (cell->attributes & TerminalAttributeInvisible)
		f = b;
	*foreground = f;
	*background = b;
}

#pragma mark - The font

/* Monospaced fonts to look for, in order. Darling's CoreText matches names
   through fontconfig, which always answers with something, so a candidate
   counts only if the family it gives back is the one asked for and its
   glyphs are all one width. "monospace" is fontconfig's own alias, the
   last resort. */
static CTFontRef TerminalCreateFont(CGFloat size)
{
	NSArray<NSString *> *candidates = @[
		@"Menlo", @"SF Mono", @"DejaVu Sans Mono", @"Droid Sans Mono", @"Noto Sans Mono",
		@"Roboto Mono", @"Liberation Mono", @"Ubuntu Mono", @"Cutive Mono", @"Courier New",
		@"Courier", @"FreeMono",
	];
	NSString *preferred = [[NSUserDefaults standardUserDefaults] stringForKey:@"TerminalFontName"];
	if (preferred != nil)
		candidates = [@[ preferred ] arrayByAddingObjectsFromArray:candidates];
	for (NSString *name in candidates) {
		CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)name, size, NULL);
		if (font == NULL)
			continue;
		NSString *family = CFBridgingRelease(CTFontCopyFamilyName(font));
		UniChar characters[3] = { 'i', 'W', '.' };
		CGGlyph glyphs[3] = { 0 };
		CGSize advances[3];
		CTFontGetGlyphsForCharacters(font, characters, glyphs, 3);
		CTFontGetAdvancesForGlyphs(font, kCTFontOrientationDefault, glyphs, advances, 3);
		BOOL fixed = glyphs[0] != 0 && advances[0].width > 0 && advances[0].width == advances[1].width
			&& advances[1].width == advances[2].width;
		if (fixed && [family caseInsensitiveCompare:name] == NSOrderedSame) {
			TerminalLog(@"font %@ %.1f", family, size);
			return font;
		}
		CFRelease(font);
	}
	CTFontRef font = CTFontCreateWithName(CFSTR("monospace"), size, NULL);
	TerminalLog(@"font %@ (fontconfig's monospace) %.1f", CFBridgingRelease(CTFontCopyFamilyName(font)), size);
	return font;
}

#pragma mark - The view

@implementation TerminalView {
	CTFontRef _font;
	CGFontRef _graphicsFont;
	CGFloat _fontSize;
	CGFloat _cellWidth, _cellHeight, _ascent;
	/* Glyphs of the Basic Multilingual Plane, looked up once each. */
	CGGlyph *_glyphs;
	uint8_t *_glyphKnown;

	uint8_t *_dirtyRows;
	int _dirtyCapacity;
	/* Where the cursor was drawn, so its old row is redrawn when it moves. */
	int _drawnCursorRow, _drawnCursorColumn;
	BOOL _drawnCursorVisible;

	/* Lines scrolled back into the scrollback, 0 when following output. */
	int _scrollOffset;
	CGPoint _touchStart;
	int _touchStartOffset;
	BOOL _touchScrolling;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		CGFloat size = [[NSUserDefaults standardUserDefaults] doubleForKey:@"TerminalFontSize"];
		_fontSize = size >= 6 && size <= 48 ? size : TerminalDefaultFontSize;
		_font = TerminalCreateFont(_fontSize);
		_graphicsFont = CTFontCopyGraphicsFont(_font, NULL);
		_glyphs = calloc(0x10000, sizeof(CGGlyph));
		_glyphKnown = calloc(0x10000 / 8, 1);

		/* Cells are whole pixels, so rows and columns never straddle one. */
		CGFloat scale = MAX([[UIScreen mainScreen] scale], 1);
		UniChar m = 'M';
		CGGlyph glyph = 0;
		CGSize advance = CGSizeZero;
		CTFontGetGlyphsForCharacters(_font, &m, &glyph, 1);
		CTFontGetAdvancesForGlyphs(_font, kCTFontOrientationDefault, &glyph, &advance, 1);
		CGFloat width = advance.width > 0 ? advance.width : _fontSize * 0.6;
		_cellWidth = ceil(width * scale) / scale;
		_ascent = ceil(CTFontGetAscent(_font) * scale) / scale;
		_cellHeight = ceil((CTFontGetAscent(_font) + CTFontGetDescent(_font) + MAX(CTFontGetLeading(_font), 0)) * scale) / scale;
		_cellHeight = MAX(_cellHeight, ceil(_fontSize * 1.15 * scale) / scale);

		_screen = [[TerminalScreen alloc] initWithColumns:80 rows:24 scrollback:5000];
		_drawnCursorRow = -1;
		[self setOpaque:YES];
		[self setMultipleTouchEnabled:NO];
	}
	return self;
}

- (void)dealloc
{
	if (_font != NULL)
		CFRelease(_font);
	CGFontRelease(_graphicsFont);
	free(_glyphs);
	free(_glyphKnown);
	free(_dirtyRows);
}

- (CGRect)rectOfRow:(int)row
{
	return CGRectMake(0, TerminalPadding + row * _cellHeight, [self bounds].size.width, _cellHeight);
}

/* The grid follows the view's size. */
- (void)layoutSubviews
{
	[super layoutSubviews];
	CGSize size = [self bounds].size;
	int columns = MAX(2, (int)floor((size.width - 2 * TerminalPadding) / _cellWidth));
	int rows = MAX(2, (int)floor((size.height - 2 * TerminalPadding) / _cellHeight));
	if (columns == [_screen columns] && rows == [_screen rows])
		return;
	[_screen resizeToColumns:columns rows:rows];
	_scrollOffset = 0;
	[self setNeedsDisplay:YES];
	[_delegate terminalView:self didResizeToColumns:columns rows:rows];
}

- (void)screenDidChange
{
	int rows = [_screen rows];
	if (_dirtyCapacity < rows) {
		free(_dirtyRows);
		_dirtyRows = calloc((size_t)rows, 1);
		_dirtyCapacity = rows;
	}
	BOOL changed = [_screen takeDirtyRows:_dirtyRows];
	/* New output brings a scrolled-back view down to it. */
	if (_scrollOffset != 0 && changed) {
		_scrollOffset = 0;
		[self setNeedsDisplay:YES];
		return;
	}
	if (_scrollOffset != 0)
		return;
	for (int row = 0; row < rows; row++)
		if (_dirtyRows[row])
			[self setNeedsDisplayInRect:[self rectOfRow:row]];
	[self cursorDidChange];
}

/* Redraws the cursor's old and new cells when it moved or changed. */
- (void)cursorDidChange
{
	int row = [_screen cursorRow], column = [_screen cursorColumn];
	BOOL visible = [_screen cursorVisible] && _scrollOffset == 0;
	if (row == _drawnCursorRow && column == _drawnCursorColumn && visible == _drawnCursorVisible)
		return;
	if (_drawnCursorRow >= 0 && _drawnCursorRow < [_screen rows])
		[self setNeedsDisplayInRect:[self rectOfRow:_drawnCursorRow]];
	[self setNeedsDisplayInRect:[self rectOfRow:row]];
}

#pragma mark - Drawing

- (CGGlyph)glyphForCharacter:(uint32_t)character
{
	if (character < 0x10000) {
		if (!(_glyphKnown[character >> 3] & (1 << (character & 7)))) {
			UniChar unit = (UniChar)character;
			CGGlyph glyph = 0;
			CTFontGetGlyphsForCharacters(_font, &unit, &glyph, 1);
			_glyphs[character] = glyph;
			_glyphKnown[character >> 3] |= 1 << (character & 7);
		}
		return _glyphs[character];
	}
	UniChar pair[2] = { (UniChar)(0xD800 + ((character - 0x10000) >> 10)), (UniChar)(0xDC00 + ((character - 0x10000) & 0x3FF)) };
	CGGlyph glyphs[2] = { 0, 0 };
	CTFontGetGlyphsForCharacters(_font, pair, glyphs, 2);
	return glyphs[0];
}

static void TerminalSetFill(CGContextRef context, TerminalRGB color)
{
	CGContextSetRGBFillColor(context, color.r, color.g, color.b, 1);
}

/* One row: background runs, then glyph runs, then underlines. `cursor` is
   the column the block cursor covers, or -1. */
- (void)drawCells:(const TerminalCell *)cells count:(int)count atY:(CGFloat)y
           cursor:(int)cursor context:(CGContextRef)context
{
	int columns = [_screen columns];
	CGFloat x0 = TerminalPadding;
	CGFloat onePixel = 1 / MAX([[UIScreen mainScreen] scale], 1);
	static const TerminalCell empty = { 0, TerminalColorDefault, TerminalColorDefault, 0 };

	/* Backgrounds that differ from the view's. */
	int runStart = -1;
	TerminalRGB runColor = TerminalDefaultBackground;
	for (int c = 0; c <= columns; c++) {
		TerminalRGB fg, bg = TerminalDefaultBackground;
		if (c < columns) {
			const TerminalCell *cell = c < count ? &cells[c] : &empty;
			TerminalCellColors(cell, &fg, &bg);
			if (c == cursor)
				bg = TerminalCursorColor;
		}
		if (runStart >= 0 && (c == columns || !TerminalRGBEqual(bg, runColor))) {
			TerminalSetFill(context, runColor);
			CGContextFillRect(context, CGRectMake(x0 + runStart * _cellWidth, y, (c - runStart) * _cellWidth, _cellHeight));
			runStart = -1;
		}
		if (c < columns && runStart < 0 && !TerminalRGBEqual(bg, TerminalDefaultBackground)) {
			runStart = c;
			runColor = bg;
		}
	}

	/* Glyphs, in runs of one color and weight. */
	CGGlyph glyphs[columns];
	CGSize advances[columns];
	int glyphCount = 0, runColumn = 0;
	TerminalRGB glyphColor = TerminalDefaultForeground;
	BOOL glyphBold = NO;
	for (int c = 0; c <= columns; c++) {
		const TerminalCell *cell = (c < columns && c < count) ? &cells[c] : &empty;
		BOOL blank = c >= columns || cell->character == 0 || cell->character == ' '
			|| (cell->attributes & (TerminalAttributeWideTail | TerminalAttributeInvisible));
		TerminalRGB fg = TerminalDefaultForeground, bg;
		BOOL bold = NO;
		if (!blank) {
			TerminalCellColors(cell, &fg, &bg);
			if (c == cursor)
				fg = TerminalDefaultBackground;
			bold = (cell->attributes & TerminalAttributeBold) != 0;
		}
		if (glyphCount > 0 && (blank || !TerminalRGBEqual(fg, glyphColor) || bold != glyphBold)) {
			TerminalSetFill(context, glyphColor);
			/* The run's last advance is where it ends: unused. */
			CGContextSetTextPosition(context, x0 + runColumn * _cellWidth, y + _ascent);
			CGContextShowGlyphsWithAdvances(context, glyphs, advances, (unsigned)glyphCount);
			if (glyphBold) {
				/* No bold face is loaded: strike the run twice, a pixel apart. */
				CGContextSetTextPosition(context, x0 + runColumn * _cellWidth + onePixel, y + _ascent);
				CGContextShowGlyphsWithAdvances(context, glyphs, advances, (unsigned)glyphCount);
			}
			glyphCount = 0;
		}
		if (blank)
			continue;
		if (glyphCount == 0) {
			runColumn = c;
			glyphColor = fg;
			glyphBold = bold;
		}
		/* A glyph's advance takes it to the next drawn cell. */
		int width = (c + 1 < count && (cells[c + 1].attributes & TerminalAttributeWideTail)) ? 2 : 1;
		glyphs[glyphCount] = [self glyphForCharacter:cell->character];
		advances[glyphCount] = CGSizeMake(width * _cellWidth, 0);
		glyphCount++;
		/* Blanks end a run (advances cannot skip cells); a wide glyph's
		   right half is part of it. */
		if (width == 2)
			c++;
	}

	/* Underlines and strikethroughs. */
	for (int c = 0; c < MIN(count, columns); c++) {
		const TerminalCell *cell = &cells[c];
		if (!(cell->attributes & (TerminalAttributeUnderline | TerminalAttributeStrike)))
			continue;
		TerminalRGB fg, bg;
		TerminalCellColors(cell, &fg, &bg);
		TerminalSetFill(context, c == cursor ? TerminalDefaultBackground : fg);
		CGFloat x = x0 + c * _cellWidth;
		if (cell->attributes & TerminalAttributeUnderline)
			CGContextFillRect(context, CGRectMake(x, y + _ascent + 2 * onePixel, _cellWidth, onePixel));
		if (cell->attributes & TerminalAttributeStrike)
			CGContextFillRect(context, CGRectMake(x, y + _ascent * 0.65, _cellWidth, onePixel));
	}
}

- (void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	TerminalSetFill(context, TerminalDefaultBackground);
	CGContextFillRect(context, rect);

	CGContextSetFont(context, _graphicsFont);
	CGContextSetFontSize(context, _fontSize);
	/* The view is flipped (UIKit's top-left origin); glyphs are not. */
	CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1, -1));

	int rows = [_screen rows];
	int first = MAX(0, (int)floor((CGRectGetMinY(rect) - TerminalPadding) / _cellHeight));
	int last = MIN(rows - 1, (int)floor((CGRectGetMaxY(rect) - TerminalPadding) / _cellHeight));

	BOOL focused = [self isFirstResponder];
	int cursorRow = [_screen cursorRow], cursorColumn = [_screen cursorColumn];
	BOOL cursorVisible = ([_screen cursorVisible] || _ended) && _scrollOffset == 0;
	for (int row = first; row <= last; row++) {
		int count = 0;
		const TerminalCell *cells = [_screen cellsOfRow:row - _scrollOffset count:&count];
		BOOL block = cursorVisible && focused && row == cursorRow;
		[self drawCells:cells count:count atY:TerminalPadding + row * _cellHeight
		         cursor:block ? cursorColumn : -1 context:context];
	}

	/* Without the keyboard the cursor is an outline. */
	if (cursorVisible && !focused && cursorRow >= first && cursorRow <= last) {
		CGFloat onePixel = 1 / MAX([[UIScreen mainScreen] scale], 1);
		CGRect cell = CGRectMake(TerminalPadding + cursorColumn * _cellWidth, TerminalPadding + cursorRow * _cellHeight, _cellWidth, _cellHeight);
		TerminalSetFill(context, TerminalCursorColor);
		CGContextFillRect(context, CGRectMake(cell.origin.x, cell.origin.y, cell.size.width, onePixel));
		CGContextFillRect(context, CGRectMake(cell.origin.x, CGRectGetMaxY(cell) - onePixel, cell.size.width, onePixel));
		CGContextFillRect(context, CGRectMake(cell.origin.x, cell.origin.y, onePixel, cell.size.height));
		CGContextFillRect(context, CGRectMake(CGRectGetMaxX(cell) - onePixel, cell.origin.y, onePixel, cell.size.height));
	}

	/* A scroll position marker while looking at the scrollback. */
	if (_scrollOffset > 0) {
		int total = [_screen scrollbackCount] + rows;
		CGFloat height = [self bounds].size.height;
		CGFloat knob = MAX(20, height * rows / total);
		CGFloat top = (height - knob) * (CGFloat)([_screen scrollbackCount] - _scrollOffset) / MAX(1, [_screen scrollbackCount]);
		CGContextSetRGBFillColor(context, 1, 1, 1, 0.35);
		CGContextFillRect(context, CGRectMake([self bounds].size.width - 4, top, 3, knob));
	}

	_drawnCursorRow = cursorRow;
	_drawnCursorColumn = cursorColumn;
	_drawnCursorVisible = [_screen cursorVisible] && _scrollOffset == 0;
}

#pragma mark - First responder

- (BOOL)canBecomeFirstResponder
{
	return YES;
}

/* AppKit asks this on a click; taps go through -touchesEnded: instead. */
- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	BOOL became = [super becomeFirstResponder];
	if (became)
		[self setNeedsDisplayInRect:[self rectOfRow:[_screen cursorRow]]];
	return became;
}

- (BOOL)resignFirstResponder
{
	BOOL resigned = [super resignFirstResponder];
	if (resigned)
		[self setNeedsDisplayInRect:[self rectOfRow:[_screen cursorRow]]];
	return resigned;
}

#pragma mark - Typing

- (void)send:(NSString *)text
{
	NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
	if ([data length] == 0)
		return;
	if (_scrollOffset != 0) {
		_scrollOffset = 0;
		[self setNeedsDisplay:YES];
	}
	[_delegate terminalView:self sendData:data];
}

- (void)setControlLatched:(BOOL)latched
{
	_controlLatched = latched;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TerminalControlLatchChanged" object:self];
}

/* The control character for a key typed with Ctrl, or 0 for none. */
static unichar TerminalControlCharacter(unichar c)
{
	if (c >= 'a' && c <= 'z')
		return c - 'a' + 1;
	if (c >= '@' && c <= '_')
		return c - '@';
	if (c == ' ' || c == '2')
		return 0x00;
	if (c == '?' || c == '8')
		return 0x7F;
	if (c >= '3' && c <= '7')
		return 0x1B + (c - '3');
	return 0xFFFF;
}

- (BOOL)hasText
{
	return YES;
}

/* Text from the keyboard: Return is a carriage return to a terminal, and a
   latched Ctrl turns the next character into its control code. */
- (void)insertText:(NSString *)text
{
	if (_controlLatched && [text length] > 0) {
		unichar control = TerminalControlCharacter([text characterAtIndex:0]);
		[self setControlLatched:NO];
		if (control != 0xFFFF) {
			unichar rest[1] = { control };
			[self send:[[NSString stringWithCharacters:rest length:1] stringByAppendingString:[text substringFromIndex:1]]];
			return;
		}
	}
	[self send:[text stringByReplacingOccurrencesOfString:@"\n" withString:@"\r"]];
}

- (void)deleteBackward
{
	[self send:@"\x7f"];
}

- (void)sendText:(NSString *)text
{
	[self insertText:text];
}

/* Arrows and the other function keys, as xterm sends them. */
- (void)sendSpecialKey:(unichar)key modifiers:(NSUInteger)modifiers
{
	BOOL application = [_screen applicationCursorKeys];
	/* xterm's modifier parameter: 1 + shift + 2*alt + 4*ctrl. */
	int modifier = 1 + ((modifiers & NSEventModifierFlagShift) ? 1 : 0) + ((modifiers & NSEventModifierFlagOption) ? 2 : 0)
		+ (((modifiers & NSEventModifierFlagControl) || _controlLatched) ? 4 : 0);
	[self setControlLatched:NO];
	char final = 0;
	switch (key) {
	case TerminalKeyUp: final = 'A'; break;
	case TerminalKeyDown: final = 'B'; break;
	case TerminalKeyRight: final = 'C'; break;
	case TerminalKeyLeft: final = 'D'; break;
	case TerminalKeyHome: final = 'H'; break;
	case TerminalKeyEnd: final = 'F'; break;
	default: break;
	}
	if (final != 0) {
		if (modifier > 1)
			[self send:[NSString stringWithFormat:@"\033[1;%d%c", modifier, final]];
		else
			[self send:[NSString stringWithFormat:application ? @"\033O%c" : @"\033[%c", final]];
		return;
	}
	int code = 0;
	switch (key) {
	case TerminalKeyInsert: code = 2; break;
	case TerminalKeyForwardDelete: code = 3; break;
	case TerminalKeyPageUp: code = 5; break;
	case TerminalKeyPageDown: code = 6; break;
	default: break;
	}
	if (code != 0) {
		[self send:modifier > 1 ? [NSString stringWithFormat:@"\033[%d;%d~", code, modifier] : [NSString stringWithFormat:@"\033[%d~", code]];
		return;
	}
	if (key >= TerminalKeyF1 && key <= TerminalKeyF12) {
		static const char *functionKeys[12] = {
			"\033OP", "\033OQ", "\033OR", "\033OS", "\033[15~", "\033[17~",
			"\033[18~", "\033[19~", "\033[20~", "\033[21~", "\033[23~", "\033[24~",
		};
		[self send:[NSString stringWithUTF8String:functionKeys[key - TerminalKeyF1]]];
	}
}

- (void)sendSpecialKey:(unichar)key
{
	[self sendSpecialKey:key modifiers:0];
}

/* Keys from a hardware keyboard (or the host's key events). UIKit would turn
   them into -insertText: and -deleteBackward, but a terminal also wants the
   arrows, Escape and the modifiers, which only the key event has. */
- (void)keyDown:(NSEvent *)event
{
	NSString *characters = [event characters];
	NSUInteger modifiers = [event modifierFlags];
	if ([characters length] == 0)
		return;
	unichar c = [characters characterAtIndex:0];

	if (c >= 0xF700 && c <= 0xF8FF) {
		[self sendSpecialKey:c modifiers:modifiers];
		return;
	}
	if (c == 0x08 || c == 0x7F) {
		[self send:(modifiers & NSEventModifierFlagOption) ? @"\033\x7f" : @"\x7f"];
		return;
	}
	if (c == '\r' || c == 0x03 || c == '\n') {
		[self send:@"\r"];
		return;
	}
	if (c == '\t' && (modifiers & NSEventModifierFlagShift)) {
		[self send:@"\033[Z"];
		return;
	}
	if (modifiers & NSEventModifierFlagControl) {
		NSString *plain = [event charactersIgnoringModifiers];
		unichar control = TerminalControlCharacter([plain length] > 0 ? [[plain lowercaseString] characterAtIndex:0] : c);
		if (control != 0xFFFF) {
			unichar bytes[1] = { control };
			[self send:[NSString stringWithCharacters:bytes length:1]];
			return;
		}
	}
	/* Option is Meta: ESC before the character. */
	if ((modifiers & NSEventModifierFlagOption) && c < 0x80) {
		[self send:[@"\033" stringByAppendingString:characters]];
		return;
	}
	[self insertText:characters];
}

#pragma mark - Touches

/* A tap brings the keyboard (or restarts an ended shell); a vertical drag
   scrolls through the scrollback. */
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	_touchStart = [[touches anyObject] locationInView:self];
	_touchStartOffset = _scrollOffset;
	_touchScrolling = NO;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	CGPoint point = [[touches anyObject] locationInView:self];
	CGFloat dy = point.y - _touchStart.y;
	if (!_touchScrolling && fabs(dy) < TerminalTapSlop)
		return;
	_touchScrolling = YES;
	if ([_screen alternateScreen])
		return; /* full-screen programs have no scrollback */
	int offset = _touchStartOffset + (int)lround(dy / _cellHeight);
	offset = MAX(0, MIN(offset, [_screen scrollbackCount]));
	if (offset != _scrollOffset) {
		_scrollOffset = offset;
		[self setNeedsDisplay:YES];
	}
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	if (_touchScrolling)
		return;
	if (_ended) {
		[_delegate terminalViewWantsRestart:self];
		return;
	}
	if ([self isFirstResponder]) {
		/* The host may have hidden its keyboard (Android's Back does) without
		   telling the app: give up first responder for one frame so that
		   becoming it again asks for the keyboard anew. */
		[self resignFirstResponder];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
			[self becomeFirstResponder];
		});
		return;
	}
	[self becomeFirstResponder];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	_touchScrolling = NO;
}

@end

#pragma mark - The extra keys

typedef NS_ENUM(NSInteger, TerminalBarKeyKind) {
	TerminalBarKeyText,
	TerminalBarKeySpecial,
	TerminalBarKeyControl,
};

@interface TerminalBarKey : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic) TerminalBarKeyKind kind;
@property (nonatomic, copy) NSString *text;
@property (nonatomic) unichar special;
/* Arrows are drawn as triangles: 0 none, else the direction's key. */
@property (nonatomic) unichar arrow;
@end

@implementation TerminalBarKey
+ (instancetype)keyWithLabel:(NSString *)label text:(NSString *)text
{
	TerminalBarKey *key = [[self alloc] init];
	key.label = label;
	key.text = text;
	key.kind = TerminalBarKeyText;
	return key;
}
+ (instancetype)arrow:(unichar)special
{
	TerminalBarKey *key = [[self alloc] init];
	key.kind = TerminalBarKeySpecial;
	key.special = special;
	key.arrow = special;
	return key;
}
@end

@implementation TerminalKeyBar {
	NSArray<TerminalBarKey *> *_keys;
	NSInteger _pressed;
	CTFontRef _font;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		TerminalBarKey *control = [TerminalBarKey keyWithLabel:@"ctrl" text:nil];
		control.kind = TerminalBarKeyControl;
		_keys = @[
			[TerminalBarKey keyWithLabel:@"esc" text:@"\033"],
			control,
			[TerminalBarKey keyWithLabel:@"tab" text:@"\t"],
			[TerminalBarKey arrow:TerminalKeyLeft],
			[TerminalBarKey arrow:TerminalKeyDown],
			[TerminalBarKey arrow:TerminalKeyUp],
			[TerminalBarKey arrow:TerminalKeyRight],
			[TerminalBarKey keyWithLabel:@"-" text:@"-"],
			[TerminalBarKey keyWithLabel:@"/" text:@"/"],
			[TerminalBarKey keyWithLabel:@"|" text:@"|"],
			[TerminalBarKey keyWithLabel:@"~" text:@"~"],
		];
		_pressed = -1;
		_font = TerminalCreateFont(13);
		[self setOpaque:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(latchChanged:)
			name:@"TerminalControlLatchChanged" object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_font != NULL)
		CFRelease(_font);
}

- (void)latchChanged:(NSNotification *)notification
{
	[self setNeedsDisplay:YES];
}

- (CGRect)rectOfKey:(NSUInteger)index
{
	CGSize size = [self bounds].size;
	CGFloat scale = MAX([[UIScreen mainScreen] scale], 1);
	CGFloat width = size.width / [_keys count];
	CGFloat left = round(index * width * scale) / scale, right = round((index + 1) * width * scale) / scale;
	return CGRectMake(left, 0, right - left, size.height);
}

- (void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGFloat onePixel = 1 / MAX([[UIScreen mainScreen] scale], 1);
	CGContextSetRGBFillColor(context, 0.13, 0.14, 0.16, 1);
	CGContextFillRect(context, rect);
	CGContextSetRGBFillColor(context, 0.25, 0.26, 0.28, 1);
	CGContextFillRect(context, CGRectMake(0, 0, [self bounds].size.width, onePixel));

	CGFontRef graphicsFont = CTFontCopyGraphicsFont(_font, NULL);
	CGContextSetFont(context, graphicsFont);
	CGContextSetFontSize(context, CTFontGetSize(_font));
	CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1, -1));

	[_keys enumerateObjectsUsingBlock:^(TerminalBarKey *key, NSUInteger index, BOOL *stop) {
		CGRect frame = CGRectInset([self rectOfKey:index], 3, 5);
		if (!CGRectIntersectsRect(frame, rect))
			return;
		BOOL lit = index == (NSUInteger)self->_pressed
			|| (key.kind == TerminalBarKeyControl && [self.terminalView controlLatched]);
		if (lit)
			CGContextSetRGBFillColor(context, 0.38, 0.40, 0.44, 1);
		else
			CGContextSetRGBFillColor(context, 0.22, 0.23, 0.25, 1);
		CGContextFillRect(context, frame);

		CGContextSetRGBFillColor(context, 0.92, 0.92, 0.90, 1);
		CGFloat midX = CGRectGetMidX(frame), midY = CGRectGetMidY(frame), s = 5;
		if (key.arrow != 0) {
			CGContextBeginPath(context);
			switch (key.arrow) {
			case TerminalKeyLeft:
				CGContextMoveToPoint(context, midX - s, midY);
				CGContextAddLineToPoint(context, midX + s, midY - s);
				CGContextAddLineToPoint(context, midX + s, midY + s);
				break;
			case TerminalKeyRight:
				CGContextMoveToPoint(context, midX + s, midY);
				CGContextAddLineToPoint(context, midX - s, midY - s);
				CGContextAddLineToPoint(context, midX - s, midY + s);
				break;
			case TerminalKeyUp:
				CGContextMoveToPoint(context, midX, midY - s);
				CGContextAddLineToPoint(context, midX - s, midY + s);
				CGContextAddLineToPoint(context, midX + s, midY + s);
				break;
			default:
				CGContextMoveToPoint(context, midX, midY + s);
				CGContextAddLineToPoint(context, midX - s, midY - s);
				CGContextAddLineToPoint(context, midX + s, midY - s);
				break;
			}
			CGContextClosePath(context);
			CGContextFillPath(context);
			return;
		}
		NSString *label = key.label;
		NSUInteger length = MIN([label length], (NSUInteger)8);
		UniChar characters[8];
		CGGlyph glyphs[8];
		CGSize advances[8];
		[label getCharacters:characters range:NSMakeRange(0, length)];
		CTFontGetGlyphsForCharacters(self->_font, characters, glyphs, (CFIndex)length);
		double width = CTFontGetAdvancesForGlyphs(self->_font, kCTFontOrientationDefault, glyphs, advances, (CFIndex)length);
		CGFloat baseline = midY + (CTFontGetAscent(self->_font) - CTFontGetDescent(self->_font)) / 2;
		CGContextSetTextPosition(context, round(midX - width / 2), round(baseline));
		CGContextShowGlyphsWithAdvances(context, glyphs, advances, (unsigned)length);
	}];
	CGFontRelease(graphicsFont);
}

- (NSInteger)keyAtPoint:(CGPoint)point
{
	for (NSUInteger i = 0; i < [_keys count]; i++)
		if (CGRectContainsPoint([self rectOfKey:i], point))
			return (NSInteger)i;
	return -1;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	_pressed = [self keyAtPoint:[[touches anyObject] locationInView:self]];
	[self setNeedsDisplay:YES];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	NSInteger key = [self keyAtPoint:[[touches anyObject] locationInView:self]];
	if (key != _pressed) {
		_pressed = -1;
		[self setNeedsDisplay:YES];
	}
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	NSInteger index = _pressed;
	_pressed = -1;
	[self setNeedsDisplay:YES];
	if (index < 0 || index >= (NSInteger)[_keys count])
		return;
	TerminalBarKey *key = _keys[(NSUInteger)index];
	TerminalView *terminal = self.terminalView;
	switch (key.kind) {
	case TerminalBarKeyControl:
		[terminal setControlLatched:![terminal controlLatched]];
		break;
	case TerminalBarKeySpecial:
		[terminal sendSpecialKey:key.special];
		break;
	case TerminalBarKeyText:
		[terminal sendText:key.text];
		break;
	}
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	_pressed = -1;
	[self setNeedsDisplay:YES];
}

@end
