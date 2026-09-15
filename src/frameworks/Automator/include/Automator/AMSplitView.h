/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#include <AppKit/AppKit.h>

// A split view whose first pane (or last, with collapsesToRightOrBottom) collapses and expands back to
// expandedPosition, the size that pane had while expanded.
@interface AMSplitView : NSSplitView
{
    BOOL _collapsesToRightOrBottom;
    CGFloat _expandedPosition;
}

@property BOOL collapsesToRightOrBottom;
@property CGFloat expandedPosition;

- (void)collapse;
- (void)expand;
- (void)collapseWithAnimation:(BOOL)animate;
- (void)expandWithAnimation:(BOOL)animate;
- (void)applyExpandedPosition;
- (void)updateExpandedPositionWithProposedPosition:(CGFloat)position ofSubViewAt:(NSInteger)index;

@end
