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

#import <Automator/AMSplitView.h>
#import "AMStubSignature.h"

@implementation AMSplitView

@synthesize collapsesToRightOrBottom = _collapsesToRightOrBottom;
@synthesize expandedPosition = _expandedPosition;

- (int)_collapsingDivider
{
    return _collapsesToRightOrBottom ? (int)[[self subviews] count] - 2 : 0;
}

- (NSView *)_collapsingSubview
{
    NSArray *subviews = [self subviews];
    return _collapsesToRightOrBottom ? [subviews lastObject] : [subviews firstObject];
}

- (CGFloat)_extent
{
    NSRect bounds = [self bounds];
    return [self isVertical] ? NSWidth(bounds) : NSHeight(bounds);
}

// Divider positions are measured from the left or top; expandedPosition is the collapsing pane's size.
- (CGFloat)_paneSizeForPosition:(CGFloat)position
{
    return _collapsesToRightOrBottom ? [self _extent] - position - [self dividerThickness] : position;
}

// A size saved in a larger window is capped so the other pane keeps some room.
- (CGFloat)_positionForPaneSize:(CGFloat)size
{
    size = MIN(size, [self _extent] - [self dividerThickness] - 1);
    return _collapsesToRightOrBottom ? [self _extent] - size - [self dividerThickness] : size;
}

- (BOOL)_isCollapsed
{
    return [self _currentPaneSize] <= 0;
}

- (CGFloat)_currentPaneSize
{
    NSSize size = [[self _collapsingSubview] frame].size;
    return [self isVertical] ? size.width : size.height;
}

- (void)collapse
{
    if ([[self subviews] count] < 2 || [self _isCollapsed])
        return;
    _expandedPosition = [self _currentPaneSize];
    [self setPosition:[self _positionForPaneSize:0] ofDividerAtIndex:[self _collapsingDivider]];
}

- (void)expand
{
    if ([[self subviews] count] < 2 || ![self _isCollapsed] || _expandedPosition <= 0)
        return;
    [self setPosition:[self _positionForPaneSize:_expandedPosition] ofDividerAtIndex:[self _collapsingDivider]];
}

// Cocotron's split view does not animate divider moves.
- (void)collapseWithAnimation:(BOOL)animate
{
    [self collapse];
}

- (void)expandWithAnimation:(BOOL)animate
{
    [self expand];
}

- (void)applyExpandedPosition
{
    if ([[self subviews] count] < 2 || [self _isCollapsed] || _expandedPosition <= 0)
        return;
    [self setPosition:[self _positionForPaneSize:_expandedPosition] ofDividerAtIndex:[self _collapsingDivider]];
}

// Sent from the delegate's splitView:constrainSplitPosition:ofSubviewAt:, for drags and programmatic moves.
- (void)updateExpandedPositionWithProposedPosition:(CGFloat)position ofSubViewAt:(NSInteger)index
{
    if ([[self subviews] count] < 2 || index != [self _collapsingDivider])
        return;
    CGFloat size = [self _paneSizeForPosition:position];
    if (size > 0 && size < [self _extent] - [self dividerThickness])
        _expandedPosition = size;
}

AM_STUB_FORWARDING

@end
