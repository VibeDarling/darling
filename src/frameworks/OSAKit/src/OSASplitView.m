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

#import <OSAKit/OSASplitView.h>
#import <AppKit/AppKit.h>

// Script Editor saves and restores its split views through these (window state, divider dragging).
@implementation NSSplitView (OSAKit)

- (CGFloat)_osa_positionOfDivider:(NSInteger)index
{
    NSRect frame = [[[self subviews] objectAtIndex:index] frame];
    return [self isVertical] ? NSMaxX(frame) : NSMaxY(frame);
}

- (void)_osa_setPosition:(CGFloat)position ofDivider:(NSInteger)index
{
    [self setPosition:position ofDividerAtIndex:(int)index];
}

@end

@implementation OSASplitView

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
