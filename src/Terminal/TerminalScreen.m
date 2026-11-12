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

/* The escape sequence interpreter: the xterm subset that shells, readline,
   ls --color and full-screen programs (top, less, vi) use. The parser is
   the usual DEC/ANSI state machine (ground, escape, CSI, OSC, and strings
   that are skipped); anything it does not know is consumed and ignored, so
   unknown sequences never leave junk on the screen.

   Lines are arrays of cells. The main screen keeps the lines that scroll
   off its top in a ring of scrollback; the alternate screen (what full-
   screen programs draw on) has none. */

#import "TerminalScreen.h"
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#define TerminalMaxParameters 32
#define TerminalMaxOSC 4096

typedef enum {
	TerminalStateGround,
	TerminalStateEscape,
	TerminalStateEscapeIntermediate,
	TerminalStateCSI,
	TerminalStateOSC,
	TerminalStateOSCEscape,
	TerminalStateString,       /* DCS, SOS, PM, APC: skipped */
	TerminalStateStringEscape,
} TerminalState;

/* What DECSC saves and DECRC restores. */
typedef struct {
	int column, row;
	TerminalCell pen;
	BOOL originMode, wrapPending;
	BOOL graphics[2];
	int charset;
} TerminalSavedCursor;

/* The DEC special graphics set (ESC ( 0), for 0x5F to 0x7E: the line
   drawing characters that dialog, mc and older curses programs use. */
static const uint16_t TerminalGraphics[32] = {
	0x00A0, 0x25C6, 0x2592, 0x2409, 0x240C, 0x240D, 0x240A, 0x00B0,
	0x00B1, 0x2424, 0x240B, 0x2518, 0x2510, 0x250C, 0x2514, 0x253C,
	0x23BA, 0x23BB, 0x2500, 0x23BC, 0x23BD, 0x251C, 0x2524, 0x2534,
	0x252C, 0x2502, 0x2264, 0x2265, 0x03C0, 0x2260, 0x00A3, 0x00B7,
};

@implementation TerminalScreen {
	int _columns, _rows;
	/* The active screen's lines are _lines: _main or _alternate. */
	TerminalCell **_main, **_alternate, **_lines;

	/* Scrollback: a ring of lines, each with the width it had. */
	TerminalCell **_scrollback;
	int *_scrollbackWidths;
	int _scrollbackLimit, _scrollbackStart, _scrollbackCount;

	int _cx, _cy;
	/* The cursor is past the last column: the next character wraps. */
	BOOL _wrapPending;
	/* The attributes new characters get (its character is unused). */
	TerminalCell _pen;
	/* The scroll region, rows inclusive. */
	int _top, _bottom;
	BOOL _originMode, _autowrap, _insertMode, _cursorVisible, _applicationCursorKeys;
	BOOL _alternateActive;
	uint8_t *_tabStops;
	TerminalSavedCursor _saved[2]; /* main, alternate */
	BOOL _graphics[2];             /* G0 and G1 are DEC graphics */
	int _charset;                  /* the one in use: 0 (SI) or 1 (SO) */
	uint8_t *_dirty;

	/* The parser. */
	TerminalState _state;
	int _parameters[TerminalMaxParameters];
	/* Bit n: parameter n followed a ':' (an SGR sub-parameter). */
	uint32_t _subParameters;
	int _parameterCount;
	char _private;
	char _intermediates[4];
	int _intermediateCount;
	NSMutableData *_osc;

	uint32_t _utf8;
	int _utf8Remaining;
	uint32_t _lastCharacter;
}

#pragma mark - Lines

static TerminalCell *TerminalNewLine(int columns, TerminalColor background)
{
	TerminalCell *line = calloc((size_t)columns, sizeof(TerminalCell));
	for (int i = 0; i < columns; i++)
		line[i].background = background;
	return line;
}

/* What erased cells become: blank, with the current background (as xterm
   does it, "background color erase"). */
static inline TerminalCell TerminalBlank(TerminalScreen *self)
{
	TerminalCell blank = { 0, TerminalColorDefault, self->_pen.background, 0 };
	return blank;
}

static void TerminalFreeLines(TerminalCell **lines, int count)
{
	if (lines == NULL)
		return;
	for (int i = 0; i < count; i++)
		free(lines[i]);
	free(lines);
}

- (instancetype)initWithColumns:(int)columns rows:(int)rows scrollback:(int)maximumScrollback
{
	if ((self = [super init])) {
		_columns = MAX(columns, 2);
		_rows = MAX(rows, 2);
		_scrollbackLimit = MAX(maximumScrollback, 0);
		_scrollback = calloc((size_t)MAX(_scrollbackLimit, 1), sizeof(TerminalCell *));
		_scrollbackWidths = calloc((size_t)MAX(_scrollbackLimit, 1), sizeof(int));
		_main = calloc((size_t)_rows, sizeof(TerminalCell *));
		_alternate = calloc((size_t)_rows, sizeof(TerminalCell *));
		for (int i = 0; i < _rows; i++) {
			_main[i] = TerminalNewLine(_columns, TerminalColorDefault);
			_alternate[i] = TerminalNewLine(_columns, TerminalColorDefault);
		}
		_lines = _main;
		_dirty = calloc((size_t)_rows, 1);
		_tabStops = calloc((size_t)_columns, 1);
		_osc = [NSMutableData data];
		[self reset];
	}
	return self;
}

- (void)dealloc
{
	TerminalFreeLines(_main, _rows);
	TerminalFreeLines(_alternate, _rows);
	for (int i = 0; i < _scrollbackCount; i++)
		free(_scrollback[(_scrollbackStart + i) % _scrollbackLimit]);
	free(_scrollback);
	free(_scrollbackWidths);
	free(_dirty);
	free(_tabStops);
}

- (void)resetTabStops
{
	for (int i = 0; i < _columns; i++)
		_tabStops[i] = (i % 8) == 0 && i > 0;
}

- (void)markAllDirty
{
	memset(_dirty, 1, (size_t)_rows);
}

- (void)reset
{
	memset(&_pen, 0, sizeof(_pen));
	_cx = _cy = 0;
	_wrapPending = NO;
	_top = 0;
	_bottom = _rows - 1;
	_originMode = NO;
	_autowrap = YES;
	_insertMode = NO;
	_cursorVisible = YES;
	_applicationCursorKeys = NO;
	_graphics[0] = _graphics[1] = NO;
	_charset = 0;
	_alternateActive = NO;
	_lines = _main;
	memset(_saved, 0, sizeof(_saved));
	_saved[0].pen = _saved[1].pen = _pen;
	for (int row = 0; row < _rows; row++) {
		for (int i = 0; i < _columns; i++) {
			_main[row][i] = TerminalBlank(self);
			_alternate[row][i] = TerminalBlank(self);
		}
	}
	[self resetTabStops];
	_state = TerminalStateGround;
	_utf8Remaining = 0;
	[self markAllDirty];
}

- (int)columns { return _columns; }
- (int)rows { return _rows; }
- (int)cursorColumn { return _cx; }
- (int)cursorRow { return _cy; }
- (BOOL)cursorVisible { return _cursorVisible; }
- (BOOL)applicationCursorKeys { return _applicationCursorKeys; }
- (BOOL)alternateScreen { return _alternateActive; }
- (int)scrollbackCount { return _scrollbackCount; }

- (const TerminalCell *)cellsOfRow:(int)row count:(int *)count
{
	if (row >= 0) {
		if (row >= _rows) {
			*count = 0;
			return NULL;
		}
		*count = _columns;
		return _lines[row];
	}
	int age = -row; /* 1 is the newest */
	if (age > _scrollbackCount) {
		*count = 0;
		return NULL;
	}
	int index = (_scrollbackStart + _scrollbackCount - age) % _scrollbackLimit;
	*count = _scrollbackWidths[index];
	return _scrollback[index];
}

- (BOOL)takeDirtyRows:(uint8_t *)dirty
{
	BOOL any = NO;
	for (int i = 0; i < _rows; i++) {
		dirty[i] = _dirty[i];
		any |= _dirty[i];
	}
	memset(_dirty, 0, (size_t)_rows);
	return any;
}

/* Keeps a line that scrolled off the top of the main screen. The line is
   the scrollback's from now on. */
- (void)pushScrollback:(TerminalCell *)line
{
	if (_scrollbackLimit == 0) {
		free(line);
		return;
	}
	int index;
	if (_scrollbackCount < _scrollbackLimit) {
		index = (_scrollbackStart + _scrollbackCount) % _scrollbackLimit;
		_scrollbackCount++;
	} else {
		index = _scrollbackStart;
		free(_scrollback[index]);
		_scrollbackStart = (_scrollbackStart + 1) % _scrollbackLimit;
	}
	_scrollback[index] = line;
	_scrollbackWidths[index] = _columns;
}

- (void)clearScrollback
{
	for (int i = 0; i < _scrollbackCount; i++)
		free(_scrollback[(_scrollbackStart + i) % _scrollbackLimit]);
	_scrollbackStart = _scrollbackCount = 0;
}

#pragma mark - Scrolling and erasing

/* Moves rows top..bottom up by count, blank lines coming in at the bottom.
   Lines leaving the top of the main screen go to the scrollback when
   toScrollback is set (a line feed, not a delete). */
- (void)scrollUpFrom:(int)top to:(int)bottom by:(int)count toScrollback:(BOOL)toScrollback
{
	if (top > bottom)
		return;
	count = MIN(count, bottom - top + 1);
	for (int n = 0; n < count; n++) {
		TerminalCell *gone = _lines[top];
		memmove(&_lines[top], &_lines[top + 1], sizeof(TerminalCell *) * (size_t)(bottom - top));
		if (toScrollback && top == 0 && !_alternateActive) {
			[self pushScrollback:gone];
			_lines[bottom] = TerminalNewLine(_columns, _pen.background);
		} else {
			TerminalCell blank = TerminalBlank(self);
			for (int i = 0; i < _columns; i++)
				gone[i] = blank;
			_lines[bottom] = gone;
		}
	}
	memset(_dirty + top, 1, (size_t)(bottom - top + 1));
}

/* Moves rows top..bottom down by count, blank lines coming in at the top. */
- (void)scrollDownFrom:(int)top to:(int)bottom by:(int)count
{
	if (top > bottom)
		return;
	count = MIN(count, bottom - top + 1);
	TerminalCell blank = TerminalBlank(self);
	for (int n = 0; n < count; n++) {
		TerminalCell *gone = _lines[bottom];
		memmove(&_lines[top + 1], &_lines[top], sizeof(TerminalCell *) * (size_t)(bottom - top));
		for (int i = 0; i < _columns; i++)
			gone[i] = blank;
		_lines[top] = gone;
	}
	memset(_dirty + top, 1, (size_t)(bottom - top + 1));
}

- (void)eraseRow:(int)row from:(int)start to:(int)end
{
	start = MAX(start, 0);
	end = MIN(end, _columns);
	TerminalCell blank = TerminalBlank(self);
	for (int i = start; i < end; i++)
		_lines[row][i] = blank;
	_dirty[row] = 1;
}

- (void)lineFeed
{
	_wrapPending = NO;
	if (_cy == _bottom)
		[self scrollUpFrom:_top to:_bottom by:1 toScrollback:YES];
	else if (_cy < _rows - 1)
		_cy++;
}

- (void)reverseIndex
{
	_wrapPending = NO;
	if (_cy == _top)
		[self scrollDownFrom:_top to:_bottom by:1];
	else if (_cy > 0)
		_cy--;
}

/* Cursor moves: the region bounds them when the cursor is inside it. */
- (void)moveToColumn:(int)column row:(int)row
{
	int minimum = 0, maximum = _rows - 1;
	if (_originMode) {
		minimum = _top;
		maximum = _bottom;
	}
	_cx = MAX(0, MIN(column, _columns - 1));
	_cy = MAX(minimum, MIN(row, maximum));
	_wrapPending = NO;
}

- (void)moveVertically:(int)delta
{
	int row = _cy + delta;
	/* Inside the region the cursor stops at its edges; outside, at the screen's. */
	if (_cy >= _top && _cy <= _bottom)
		row = MAX(_top, MIN(row, _bottom));
	_cy = MAX(0, MIN(row, _rows - 1));
	_wrapPending = NO;
}

#pragma mark - Printing

- (void)print:(uint32_t)character
{
	if (character >= 0x5F && character <= 0x7E && _graphics[_charset])
		character = TerminalGraphics[character - 0x5F];

	int width = 1;
	if (character >= 0x300) {
		width = wcwidth((wchar_t)character);
		if (width == 0)
			return; /* combining marks: not drawn here */
		if (width < 0)
			width = 1;
		width = MIN(width, 2);
	}

	if (_wrapPending) {
		_wrapPending = NO;
		if (_autowrap) {
			_lines[_cy][_columns - 1].attributes |= TerminalAttributeWrapped;
			_cx = 0;
			[self lineFeed];
		}
	}
	if (width == 2 && _cx == _columns - 1) {
		/* No room for both halves: wrap first, as xterm does. */
		if (!_autowrap)
			return;
		[self eraseRow:_cy from:_cx to:_columns];
		_lines[_cy][_columns - 1].attributes |= TerminalAttributeWrapped;
		_cx = 0;
		[self lineFeed];
	}

	TerminalCell *line = _lines[_cy];
	if (_insertMode) {
		memmove(&line[_cx + width], &line[_cx], sizeof(TerminalCell) * (size_t)(_columns - _cx - width));
	}
	/* Overwriting half of a double-width character leaves the other half blank. */
	if ((line[_cx].attributes & TerminalAttributeWideTail) && _cx > 0)
		line[_cx - 1] = TerminalBlank(self);
	if (_cx + width < _columns && (line[_cx + width].attributes & TerminalAttributeWideTail))
		line[_cx + width] = TerminalBlank(self);

	TerminalCell cell = _pen;
	cell.character = character;
	cell.attributes &= ~(TerminalAttributeWideTail | TerminalAttributeWrapped);
	line[_cx] = cell;
	if (width == 2) {
		cell.character = 0;
		cell.attributes |= TerminalAttributeWideTail;
		line[_cx + 1] = cell;
	}
	_dirty[_cy] = 1;
	_lastCharacter = character;

	_cx += width;
	if (_cx >= _columns) {
		_cx = _columns - 1;
		_wrapPending = YES;
	}
}

- (void)tabForward:(int)count
{
	while (count-- > 0) {
		int column = _cx + 1;
		while (column < _columns - 1 && !_tabStops[column])
			column++;
		_cx = MIN(column, _columns - 1);
	}
	_wrapPending = NO;
}

- (void)tabBackward:(int)count
{
	while (count-- > 0 && _cx > 0) {
		int column = _cx - 1;
		while (column > 0 && !_tabStops[column])
			column--;
		_cx = column;
	}
	_wrapPending = NO;
}

#pragma mark - Saved cursor and the alternate screen

- (void)saveCursor
{
	TerminalSavedCursor *saved = &_saved[_alternateActive];
	saved->column = _cx;
	saved->row = _cy;
	saved->pen = _pen;
	saved->originMode = _originMode;
	saved->wrapPending = _wrapPending;
	saved->graphics[0] = _graphics[0];
	saved->graphics[1] = _graphics[1];
	saved->charset = _charset;
}

- (void)restoreCursor
{
	TerminalSavedCursor *saved = &_saved[_alternateActive];
	_pen = saved->pen;
	_originMode = saved->originMode;
	_graphics[0] = saved->graphics[0];
	_graphics[1] = saved->graphics[1];
	_charset = saved->charset;
	_cx = MAX(0, MIN(saved->column, _columns - 1));
	_cy = MAX(0, MIN(saved->row, _rows - 1));
	_wrapPending = saved->wrapPending;
}

- (void)useAlternateScreen:(BOOL)alternate clear:(BOOL)clear
{
	if (alternate == _alternateActive)
		return;
	_alternateActive = alternate;
	_lines = alternate ? _alternate : _main;
	if (clear)
		for (int row = 0; row < _rows; row++)
			[self eraseRow:row from:0 to:_columns];
	[self markAllDirty];
}

#pragma mark - Resizing

/* Fits a screen's lines to the new size. Rows that no longer fit come off
   the bottom while they are below the cursor, then off the top (into the
   scrollback for the main screen), so the cursor's line stays. Lines are
   cut or padded, not rewrapped. */
- (TerminalCell **)resizeLines:(TerminalCell **)lines cursorRow:(int *)cursorRow
                       columns:(int)columns rows:(int)rows main:(BOOL)isMain
{
	int fromTop = 0, keep = _rows;
	if (rows < _rows) {
		int drop = _rows - rows;
		int below = MAX(0, _rows - 1 - *cursorRow);
		int fromBottom = MIN(drop, below);
		fromTop = drop - fromBottom;
		keep = rows;
	}
	TerminalCell **resized = calloc((size_t)rows, sizeof(TerminalCell *));
	for (int i = 0; i < _rows; i++) {
		if (i < fromTop) {
			if (isMain)
				[self pushScrollback:lines[i]];
			else
				free(lines[i]);
		} else if (i - fromTop < keep) {
			TerminalCell *line = realloc(lines[i], sizeof(TerminalCell) * (size_t)columns);
			for (int c = _columns; c < columns; c++)
				memset(&line[c], 0, sizeof(TerminalCell));
			resized[i - fromTop] = line;
		} else {
			free(lines[i]);
		}
	}
	for (int i = 0; i < rows; i++)
		if (resized[i] == NULL)
			resized[i] = TerminalNewLine(columns, TerminalColorDefault);
	free(lines);
	*cursorRow = MAX(0, *cursorRow - fromTop);
	return resized;
}

- (void)resizeToColumns:(int)columns rows:(int)rows
{
	columns = MAX(columns, 2);
	rows = MAX(rows, 2);
	if (columns == _columns && rows == _rows)
		return;
	/* The scrollback keeps the old width: lines record their own. */
	int mainRow = _alternateActive ? _saved[0].row : _cy;
	int alternateRow = _alternateActive ? _cy : _saved[1].row;
	/* pushScrollback records _columns, which is still the old width here. */
	_main = [self resizeLines:_main cursorRow:&mainRow columns:columns rows:rows main:YES];
	_alternate = [self resizeLines:_alternate cursorRow:&alternateRow columns:columns rows:rows main:NO];
	_lines = _alternateActive ? _alternate : _main;
	if (_alternateActive) {
		_cy = alternateRow;
		_saved[0].row = mainRow;
	} else {
		_cy = mainRow;
		_saved[1].row = alternateRow;
	}

	_columns = columns;
	_rows = rows;
	free(_dirty);
	_dirty = calloc((size_t)rows, 1);
	free(_tabStops);
	_tabStops = calloc((size_t)columns, 1);
	[self resetTabStops];
	_top = 0;
	_bottom = rows - 1;
	_cx = MIN(_cx, columns - 1);
	_cy = MIN(_cy, rows - 1);
	for (int i = 0; i < 2; i++) {
		_saved[i].column = MIN(_saved[i].column, columns - 1);
		_saved[i].row = MIN(_saved[i].row, rows - 1);
	}
	_wrapPending = NO;
	[self markAllDirty];
}

#pragma mark - Answers

- (void)answer:(NSString *)text
{
	if (_responder != nil)
		_responder([text dataUsingEncoding:NSUTF8StringEncoding]);
}

#pragma mark - Control characters

- (void)control:(uint8_t)byte
{
	switch (byte) {
	case 0x07: /* BEL: no bell here */
		break;
	case 0x08: /* BS */
		if (_cx > 0)
			_cx--;
		_wrapPending = NO;
		break;
	case 0x09: /* HT */
		[self tabForward:1];
		break;
	case 0x0A: /* LF, VT, FF */
	case 0x0B:
	case 0x0C:
		[self lineFeed];
		break;
	case 0x0D: /* CR */
		_cx = 0;
		_wrapPending = NO;
		break;
	case 0x0E: /* SO: G1 */
		_charset = 1;
		break;
	case 0x0F: /* SI: G0 */
		_charset = 0;
		break;
	default:
		break;
	}
}

#pragma mark - Escape sequences

- (void)escapeFinal:(uint8_t)byte
{
	if (_intermediateCount > 0) {
		/* Character sets: ESC ( 0 is line drawing, anything else ASCII. */
		if (_intermediates[0] == '(' || _intermediates[0] == ')')
			_graphics[_intermediates[0] == ')'] = byte == '0';
		else if (_intermediates[0] == '#' && byte == '8') {
			/* DECALN: the screen full of E. */
			for (int row = 0; row < _rows; row++) {
				for (int i = 0; i < _columns; i++) {
					TerminalCell cell = { 'E', TerminalColorDefault, TerminalColorDefault, 0 };
					_lines[row][i] = cell;
				}
			}
			[self markAllDirty];
		}
		return;
	}
	switch (byte) {
	case '7': [self saveCursor]; break;
	case '8': [self restoreCursor]; break;
	case 'D': [self lineFeed]; break;
	case 'E': _cx = 0; [self lineFeed]; break;
	case 'M': [self reverseIndex]; break;
	case 'H': _tabStops[_cx] = 1; break;
	case 'c': [self reset]; break;
	default: break; /* DECKPAM/DECKPNM (=, >) and the rest: nothing to do */
	}
}

/* Parameter n, or the default when it is missing or 0. */
static inline int TerminalParameter(TerminalScreen *self, int n, int fallback)
{
	if (n >= self->_parameterCount || self->_parameters[n] == 0)
		return fallback;
	return self->_parameters[n];
}

static inline BOOL TerminalIsSubParameter(TerminalScreen *self, int n)
{
	return n < self->_parameterCount && (self->_subParameters & (1u << n)) != 0;
}

/* The color after SGR 38 or 48 at parameter *index, in either form:
   38;5;N, 38;2;R;G;B or with colons, 38:5:N, 38:2:[colorspace:]R:G:B.
   Leaves *index on its last parameter. */
- (BOOL)extendedColorAt:(int *)index color:(TerminalColor *)color
{
	int i = *index;
	if (TerminalIsSubParameter(self, i + 1)) {
		int count = 0;
		while (TerminalIsSubParameter(self, i + 1 + count))
			count++;
		int kind = _parameters[i + 1];
		*index = i + count;
		if (kind == 5 && count >= 2) {
			*color = TerminalColorIndexed(_parameters[i + 2]);
			return YES;
		}
		if (kind == 2 && count >= 4) {
			int first = count >= 5 ? i + 3 : i + 2;
			*color = TerminalColorRGB(_parameters[first], _parameters[first + 1], _parameters[first + 2]);
			return YES;
		}
		return NO;
	}
	if (i + 1 >= _parameterCount)
		return NO;
	int kind = _parameters[i + 1];
	if (kind == 5 && i + 2 < _parameterCount) {
		*color = TerminalColorIndexed(_parameters[i + 2]);
		*index = i + 2;
		return YES;
	}
	if (kind == 2 && i + 4 < _parameterCount) {
		*color = TerminalColorRGB(_parameters[i + 2], _parameters[i + 3], _parameters[i + 4]);
		*index = i + 4;
		return YES;
	}
	*index = i + 1;
	return NO;
}

- (void)selectGraphicRendition
{
	if (_parameterCount == 0) {
		memset(&_pen, 0, sizeof(_pen));
		return;
	}
	for (int i = 0; i < _parameterCount; i++) {
		int p = _parameters[i];
		TerminalColor color;
		switch (p) {
		case 0: memset(&_pen, 0, sizeof(_pen)); break;
		case 1: _pen.attributes |= TerminalAttributeBold; break;
		case 2: _pen.attributes |= TerminalAttributeFaint; break;
		case 3: _pen.attributes |= TerminalAttributeItalic; break;
		case 4:
			/* 4:0 is no underline; 4:N any other style is one. */
			if (TerminalIsSubParameter(self, i + 1) && _parameters[i + 1] == 0)
				_pen.attributes &= ~TerminalAttributeUnderline;
			else
				_pen.attributes |= TerminalAttributeUnderline;
			break;
		case 5: case 6: _pen.attributes |= TerminalAttributeBlink; break;
		case 7: _pen.attributes |= TerminalAttributeInverse; break;
		case 8: _pen.attributes |= TerminalAttributeInvisible; break;
		case 9: _pen.attributes |= TerminalAttributeStrike; break;
		case 21: _pen.attributes |= TerminalAttributeUnderline; break;
		case 22: _pen.attributes &= ~(TerminalAttributeBold | TerminalAttributeFaint); break;
		case 23: _pen.attributes &= ~TerminalAttributeItalic; break;
		case 24: _pen.attributes &= ~TerminalAttributeUnderline; break;
		case 25: _pen.attributes &= ~TerminalAttributeBlink; break;
		case 27: _pen.attributes &= ~TerminalAttributeInverse; break;
		case 28: _pen.attributes &= ~TerminalAttributeInvisible; break;
		case 29: _pen.attributes &= ~TerminalAttributeStrike; break;
		case 38:
			if ([self extendedColorAt:&i color:&color])
				_pen.foreground = color;
			break;
		case 39: _pen.foreground = TerminalColorDefault; break;
		case 48:
			if ([self extendedColorAt:&i color:&color])
				_pen.background = color;
			break;
		case 49: _pen.background = TerminalColorDefault; break;
		default:
			if (p >= 30 && p <= 37)
				_pen.foreground = TerminalColorIndexed(p - 30);
			else if (p >= 40 && p <= 47)
				_pen.background = TerminalColorIndexed(p - 40);
			else if (p >= 90 && p <= 97)
				_pen.foreground = TerminalColorIndexed(p - 90 + 8);
			else if (p >= 100 && p <= 107)
				_pen.background = TerminalColorIndexed(p - 100 + 8);
			break;
		}
		/* Sub-parameters belong to the one before; skip what is left of them. */
		while (TerminalIsSubParameter(self, i + 1))
			i++;
	}
}

- (void)setMode:(BOOL)set
{
	for (int i = 0; i < MAX(_parameterCount, 1); i++) {
		int mode = i < _parameterCount ? _parameters[i] : 0;
		if (_private == '?') {
			switch (mode) {
			case 1: _applicationCursorKeys = set; break;
			case 6:
				_originMode = set;
				[self moveToColumn:0 row:set ? _top : 0];
				break;
			case 7: _autowrap = set; break;
			case 25: _cursorVisible = set; break;
			case 47:
			case 1047:
				[self useAlternateScreen:set clear:mode == 1047 && set];
				break;
			case 1048:
				if (set)
					[self saveCursor];
				else
					[self restoreCursor];
				break;
			case 1049:
				/* The cursor is saved on the main screen and restored there. */
				if (set) {
					if (!_alternateActive) {
						[self saveCursor];
						[self useAlternateScreen:YES clear:YES];
					}
				} else if (_alternateActive) {
					[self useAlternateScreen:NO clear:NO];
					[self restoreCursor];
				}
				break;
			default:
				/* Bracketed paste (2004), mouse reporting, focus events, blinking
				   cursor and the rest: accepted and ignored. */
				break;
			}
		} else if (_private == 0) {
			if (mode == 4)
				_insertMode = set;
		}
	}
}

- (void)CSIFinal:(uint8_t)final
{
	/* Only DECSCUSR (CSI Ps SP q) and the like use intermediates; none matter here. */
	if (_intermediateCount > 0)
		return;
	if (_private != 0 && _private != '?' && final != 'c')
		return;

	int n = TerminalParameter(self, 0, 1);
	switch (final) {
	case '@': { /* ICH: insert blanks */
		TerminalCell *line = _lines[_cy];
		n = MIN(n, _columns - _cx);
		memmove(&line[_cx + n], &line[_cx], sizeof(TerminalCell) * (size_t)(_columns - _cx - n));
		[self eraseRow:_cy from:_cx to:_cx + n];
		_wrapPending = NO;
		break;
	}
	case 'A': [self moveVertically:-n]; break;
	case 'B': case 'e': [self moveVertically:n]; break;
	case 'C': case 'a': _cx = MIN(_cx + n, _columns - 1); _wrapPending = NO; break;
	case 'D': _cx = MAX(_cx - n, 0); _wrapPending = NO; break;
	case 'E': _cx = 0; [self moveVertically:n]; break;
	case 'F': _cx = 0; [self moveVertically:-n]; break;
	case 'G': case '`': _cx = MAX(0, MIN(n - 1, _columns - 1)); _wrapPending = NO; break;
	case 'H': case 'f': {
		int row = TerminalParameter(self, 0, 1) - 1, column = TerminalParameter(self, 1, 1) - 1;
		[self moveToColumn:column row:row + (_originMode ? _top : 0)];
		break;
	}
	case 'I': [self tabForward:n]; break;
	case 'Z': [self tabBackward:n]; break;
	case 'J': { /* ED */
		int mode = TerminalParameter(self, 0, 0);
		if (mode == 0) {
			[self eraseRow:_cy from:_cx to:_columns];
			for (int row = _cy + 1; row < _rows; row++)
				[self eraseRow:row from:0 to:_columns];
		} else if (mode == 1) {
			for (int row = 0; row < _cy; row++)
				[self eraseRow:row from:0 to:_columns];
			[self eraseRow:_cy from:0 to:_cx + 1];
		} else if (mode == 2) {
			for (int row = 0; row < _rows; row++)
				[self eraseRow:row from:0 to:_columns];
		} else if (mode == 3) {
			[self clearScrollback];
		}
		_wrapPending = NO;
		break;
	}
	case 'K': { /* EL */
		int mode = TerminalParameter(self, 0, 0);
		if (mode == 0)
			[self eraseRow:_cy from:_cx to:_columns];
		else if (mode == 1)
			[self eraseRow:_cy from:0 to:_cx + 1];
		else if (mode == 2)
			[self eraseRow:_cy from:0 to:_columns];
		_wrapPending = NO;
		break;
	}
	case 'L': /* IL */
		if (_cy >= _top && _cy <= _bottom) {
			[self scrollDownFrom:_cy to:_bottom by:n];
			_cx = 0;
			_wrapPending = NO;
		}
		break;
	case 'M': /* DL */
		if (_cy >= _top && _cy <= _bottom) {
			[self scrollUpFrom:_cy to:_bottom by:n toScrollback:NO];
			_cx = 0;
			_wrapPending = NO;
		}
		break;
	case 'P': { /* DCH */
		TerminalCell *line = _lines[_cy];
		n = MIN(n, _columns - _cx);
		memmove(&line[_cx], &line[_cx + n], sizeof(TerminalCell) * (size_t)(_columns - _cx - n));
		[self eraseRow:_cy from:_columns - n to:_columns];
		_wrapPending = NO;
		break;
	}
	case 'S': [self scrollUpFrom:_top to:_bottom by:n toScrollback:NO]; break;
	case 'T': [self scrollDownFrom:_top to:_bottom by:n]; break;
	case 'X': [self eraseRow:_cy from:_cx to:_cx + n]; break;
	case 'b': /* REP */
		if (_lastCharacter != 0)
			for (int i = 0; i < MIN(n, 65535); i++)
				[self print:_lastCharacter];
		break;
	case 'c': /* DA */
		if (_private == '>')
			[self answer:@"\033[>0;276;0c"];
		else if (_private == 0)
			[self answer:@"\033[?1;2c"];
		break;
	case 'd': /* VPA */
		[self moveToColumn:_cx row:n - 1 + (_originMode ? _top : 0)];
		break;
	case 'g': /* TBC */
		if (TerminalParameter(self, 0, 0) == 0)
			_tabStops[_cx] = 0;
		else if (TerminalParameter(self, 0, 0) == 3)
			memset(_tabStops, 0, (size_t)_columns);
		break;
	case 'h': [self setMode:YES]; break;
	case 'l': [self setMode:NO]; break;
	case 'm': if (_private == 0) [self selectGraphicRendition]; break;
	case 'n': /* DSR */
		if (_private != 0)
			break;
		if (TerminalParameter(self, 0, 0) == 5)
			[self answer:@"\033[0n"];
		else if (TerminalParameter(self, 0, 0) == 6)
			[self answer:[NSString stringWithFormat:@"\033[%d;%dR", _cy + 1 - (_originMode ? _top : 0), _cx + 1]];
		break;
	case 'r': { /* DECSTBM */
		if (_private != 0)
			break;
		int top = TerminalParameter(self, 0, 1) - 1, bottom = TerminalParameter(self, 1, _rows) - 1;
		bottom = MIN(bottom, _rows - 1);
		if (top < bottom) {
			_top = top;
			_bottom = bottom;
			[self moveToColumn:0 row:_originMode ? _top : 0];
		}
		break;
	}
	case 's': if (_private == 0) [self saveCursor]; break;
	case 'u': if (_private == 0) [self restoreCursor]; break;
	default:
		break; /* window operations (t) and the rest */
	}
}

- (void)OSCFinished
{
	/* "0;title" and "2;title" set the window title; the rest are ignored. */
	NSString *text = [[NSString alloc] initWithData:_osc encoding:NSUTF8StringEncoding];
	NSRange separator = [text rangeOfString:@";"];
	if (separator.location != NSNotFound) {
		NSString *command = [text substringToIndex:separator.location];
		if ([command isEqualToString:@"0"] || [command isEqualToString:@"2"])
			_title = [[text substringFromIndex:NSMaxRange(separator)] copy];
	}
	[_osc setLength:0];
}

#pragma mark - The parser

- (void)beginEscape
{
	_state = TerminalStateEscape;
	_intermediateCount = 0;
	_utf8Remaining = 0;
}

- (void)feed:(const uint8_t *)bytes length:(size_t)length
{
	for (size_t index = 0; index < length; index++) {
		uint8_t byte = bytes[index];

		/* Strings run to BEL or ST (ESC \) and take anything else. */
		switch (_state) {
		case TerminalStateOSC:
			if (byte == 0x07) {
				[self OSCFinished];
				_state = TerminalStateGround;
			} else if (byte == 0x1B) {
				_state = TerminalStateOSCEscape;
			} else if (byte == 0x18 || byte == 0x1A) {
				[_osc setLength:0];
				_state = TerminalStateGround;
			} else if ([_osc length] < TerminalMaxOSC) {
				[_osc appendBytes:&byte length:1];
			}
			continue;
		case TerminalStateOSCEscape:
			[self OSCFinished];
			_state = TerminalStateGround;
			if (byte == '\\')
				continue;
			[self beginEscape];
			index--; /* the ESC started something else: read this byte again */
			continue;
		case TerminalStateString:
			if (byte == 0x1B)
				_state = TerminalStateStringEscape;
			else if (byte == 0x18 || byte == 0x1A || byte == 0x07)
				_state = TerminalStateGround;
			continue;
		case TerminalStateStringEscape:
			_state = byte == '\\' ? TerminalStateGround : TerminalStateString;
			continue;
		default:
			break;
		}

		/* Control characters act in the middle of sequences too. */
		if (byte < 0x20) {
			if (byte == 0x1B)
				[self beginEscape];
			else if (byte == 0x18 || byte == 0x1A)
				_state = TerminalStateGround;
			else {
				_utf8Remaining = 0;
				[self control:byte];
			}
			continue;
		}
		if (byte == 0x7F)
			continue;

		switch (_state) {
		case TerminalStateGround:
			if (byte < 0x80) {
				_utf8Remaining = 0;
				[self print:byte];
			} else if ((byte & 0xC0) == 0x80) {
				if (_utf8Remaining == 0) {
					[self print:0xFFFD];
					break;
				}
				_utf8 = (_utf8 << 6) | (byte & 0x3F);
				if (--_utf8Remaining == 0)
					[self print:(_utf8 > 0x10FFFF || (_utf8 >= 0xD800 && _utf8 <= 0xDFFF)) ? 0xFFFD : _utf8];
			} else {
				if (_utf8Remaining != 0)
					[self print:0xFFFD];
				if ((byte & 0xE0) == 0xC0) {
					_utf8 = byte & 0x1F;
					_utf8Remaining = 1;
				} else if ((byte & 0xF0) == 0xE0) {
					_utf8 = byte & 0x0F;
					_utf8Remaining = 2;
				} else if ((byte & 0xF8) == 0xF0) {
					_utf8 = byte & 0x07;
					_utf8Remaining = 3;
				} else {
					_utf8Remaining = 0;
					[self print:0xFFFD];
				}
			}
			break;

		case TerminalStateEscape:
			if (byte >= 0x20 && byte <= 0x2F) {
				_intermediates[_intermediateCount++] = (char)byte;
				_state = TerminalStateEscapeIntermediate;
			} else if (byte == '[') {
				_state = TerminalStateCSI;
				_parameterCount = 0;
				_subParameters = 0;
				_private = 0;
				_intermediateCount = 0;
			} else if (byte == ']') {
				_state = TerminalStateOSC;
				[_osc setLength:0];
			} else if (byte == 'P' || byte == 'X' || byte == '^' || byte == '_') {
				_state = TerminalStateString;
			} else {
				_state = TerminalStateGround;
				[self escapeFinal:byte];
			}
			break;

		case TerminalStateEscapeIntermediate:
			if (byte >= 0x20 && byte <= 0x2F) {
				if (_intermediateCount < (int)sizeof(_intermediates))
					_intermediates[_intermediateCount++] = (char)byte;
			} else {
				_state = TerminalStateGround;
				if (byte < 0x80)
					[self escapeFinal:byte];
			}
			break;

		case TerminalStateCSI:
			if (byte >= '0' && byte <= '9') {
				if (_parameterCount == 0) {
					_parameterCount = 1;
					_parameters[0] = 0;
				}
				int *p = &_parameters[_parameterCount - 1];
				if (*p < 100000)
					*p = *p * 10 + (byte - '0');
			} else if (byte == ';' || byte == ':') {
				if (_parameterCount == 0) {
					_parameterCount = 1;
					_parameters[0] = 0;
				}
				if (_parameterCount < TerminalMaxParameters) {
					if (byte == ':')
						_subParameters |= 1u << _parameterCount;
					_parameters[_parameterCount++] = 0;
				}
			} else if (byte >= 0x3C && byte <= 0x3F) {
				if (_parameterCount == 0)
					_private = (char)byte;
			} else if (byte >= 0x20 && byte <= 0x2F) {
				if (_intermediateCount < (int)sizeof(_intermediates))
					_intermediates[_intermediateCount++] = (char)byte;
			} else if (byte >= 0x40 && byte <= 0x7E) {
				_state = TerminalStateGround;
				[self CSIFinal:byte];
			} else {
				/* Bytes above 0x7F do not belong in a sequence: drop it. */
				_state = TerminalStateGround;
			}
			break;

		default:
			_state = TerminalStateGround;
			break;
		}
	}
}

@end
