/*
 This file is part of Darling.

 Copyright (C) 2025 Darling Developers

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

#import <UIFoundation/NSStringDrawingContext.h>

@implementation NSStringDrawingContext

@synthesize minimumScaleFactor = _minimumScaleFactor;
@synthesize actualScaleFactor = _actualScaleFactor;
@synthesize totalBounds = _totalBounds;
@synthesize baselineOffset = _baselineOffset;
@synthesize firstBaselineOffset = _firstBaselineOffset;
@synthesize scaledLineHeight = _scaledLineHeight;
@synthesize scaledBaselineOffset = _scaledBaselineOffset;
@synthesize wrapsForTruncationMode = _wrapsForTruncationMode;
@synthesize wantsBaselineOffset = _wantsBaselineOffset;
@synthesize wantsScaledLineHeight = _wantsScaledLineHeight;
@synthesize wantsScaledBaselineOffset = _wantsScaledBaselineOffset;
@synthesize cachesLayout = _cachesLayout;
@synthesize maximumNumberOfLines = _maximumNumberOfLines;
@synthesize wantsNumberOfLineFragments = _wantsNumberOfLineFragments;
@synthesize activeRenderers = _activeRenderers;
@synthesize layout = _layout;
@synthesize numberOfLineFragments = _numberOfLineFragments;
@synthesize hasTruncatedRanges = _hasTruncatedRanges;
@synthesize linkTextAttributesProvider = _linkTextAttributesProvider;

- (void)setActualScaleFactor:(CGFloat)scale
{
    _actualScaleFactor = scale;
}

- (void)setTotalBounds:(NSRect)bounds
{
    _totalBounds = bounds;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _actualScaleFactor = 1.0;
        _totalBounds = NSZeroRect;
    }
    return self;
}

- (void)dealloc
{
    [_layout release];
    [_linkTextAttributesProvider release];
    [super dealloc];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
