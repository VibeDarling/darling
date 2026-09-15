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

#import <AppKit/AppKit.h>

// Automator.app's document window controller places its log, variables and library views with
// -am_constrainToSuperview and keeps the window on its screen with -am_constrainToScreen:adjustWidth:adjustHeight:.

@implementation NSView (AMLayoutAdditions)

- (void)am_constrainToSuperview
{
    NSView *superview = [self superview];
    if (superview == nil)
        return;
    [self setFrame:[superview bounds]];
    [self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
}

@end

@implementation NSWindow (AMLayoutAdditions)

- (void)am_constrainToScreen:(NSScreen *)screen adjustWidth:(BOOL)adjustWidth adjustHeight:(BOOL)adjustHeight
{
    // -[NSWindow screen] is nil for a window that overlaps no screen, which is the case this fixes.
    NSScreen *target = screen ?: [NSScreen mainScreen];
    NSRect visible = [target visibleFrame];
    if (NSIsEmptyRect(visible))
        return;

    NSRect frame = [self frame];
    if (adjustWidth && NSWidth(frame) > NSWidth(visible))
        frame.size.width = NSWidth(visible);
    if (adjustHeight && NSHeight(frame) > NSHeight(visible))
        frame.size.height = NSHeight(visible);
    frame = [self constrainFrameRect:frame toScreen:target];

    if (!NSEqualRects(frame, [self frame]))
        [self setFrame:frame display:YES];
}

@end
