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

/* The terminal's screen: a grid of character cells that the bytes a program
   writes are interpreted into, as a VT100/xterm does, with scrollback above
   it. It knows nothing of drawing or of the pty; the view draws the cells
   and asks which rows changed, the session feeds it bytes and sends back
   what it answers (cursor position reports and the like). */

#import <Foundation/Foundation.h>

/* A color: the default (foreground or background, by where it is used), one
   of the 256 indexed colors, or 24-bit RGB. */
typedef uint32_t TerminalColor;
#define TerminalColorDefault 0u
#define TerminalColorIndexed(n) (0x01000000u | ((n) & 0xFFu))
#define TerminalColorRGB(r, g, b) (0x02000000u | (((r) & 0xFFu) << 16) | (((g) & 0xFFu) << 8) | ((b) & 0xFFu))
#define TerminalColorIsIndexed(c) (((c) >> 24) == 1)
#define TerminalColorIsRGB(c) (((c) >> 24) == 2)

enum {
	TerminalAttributeBold = 1 << 0,
	TerminalAttributeFaint = 1 << 1,
	TerminalAttributeItalic = 1 << 2,
	TerminalAttributeUnderline = 1 << 3,
	TerminalAttributeBlink = 1 << 4,
	TerminalAttributeInverse = 1 << 5,
	TerminalAttributeInvisible = 1 << 6,
	TerminalAttributeStrike = 1 << 7,
	/* The right half of a double-width character: drawn by the left one. */
	TerminalAttributeWideTail = 1 << 8,
	/* The line went on to the next one by wrapping, not by a newline. */
	TerminalAttributeWrapped = 1 << 9,
};

typedef struct {
	uint32_t character; /* Unicode; 0 is an empty cell, drawn as a space */
	TerminalColor foreground, background;
	uint16_t attributes;
} TerminalCell;

@interface TerminalScreen : NSObject

/* Called with bytes the terminal answers to queries (DSR, DA). */
@property (nonatomic, copy) void (^responder)(NSData *answer);
/* The window title a program set (OSC 0/2), for whoever wants it. */
@property (nonatomic, copy, readonly) NSString *title;

@property (nonatomic, readonly) int columns, rows;
@property (nonatomic, readonly) int cursorColumn, cursorRow;
@property (nonatomic, readonly) BOOL cursorVisible;
/* DECCKM: arrows send ESC O x instead of ESC [ x. */
@property (nonatomic, readonly) BOOL applicationCursorKeys;
@property (nonatomic, readonly) BOOL alternateScreen;
/* Lines that scrolled off the top of the main screen, oldest first. */
@property (nonatomic, readonly) int scrollbackCount;

- (instancetype)initWithColumns:(int)columns rows:(int)rows scrollback:(int)maximumScrollback;

/* Interprets output; UTF-8 sequences may be split across calls. */
- (void)feed:(const uint8_t *)bytes length:(size_t)length;
- (void)resizeToColumns:(int)columns rows:(int)rows;
- (void)reset;

/* Row `row` of the screen (0 is the top), or of the scrollback when row is
   negative (-1 is the newest line in it). Returns the number of cells,
   which can be fewer than columns for old scrollback lines. */
- (const TerminalCell *)cellsOfRow:(int)row count:(int *)count;

/* Which screen rows changed since the last call: dirty[row] is set to 1
   for each (dirty holds rows bytes). Returns NO when none did. */
- (BOOL)takeDirtyRows:(uint8_t *)dirty;

@end
