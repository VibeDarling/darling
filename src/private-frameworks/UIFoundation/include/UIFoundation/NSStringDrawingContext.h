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

#include <Foundation/Foundation.h>

@interface NSStringDrawingContext : NSObject
{
    CGFloat _minimumScaleFactor;
    CGFloat _actualScaleFactor;
    NSRect _totalBounds;
    CGFloat _baselineOffset;
    CGFloat _firstBaselineOffset;
    CGFloat _scaledLineHeight;
    CGFloat _scaledBaselineOffset;
    BOOL _wrapsForTruncationMode;
    BOOL _wantsBaselineOffset;
    BOOL _wantsScaledLineHeight;
    BOOL _wantsScaledBaselineOffset;
    BOOL _cachesLayout;
    NSInteger _maximumNumberOfLines;
    BOOL _wantsNumberOfLineFragments;
    NSUInteger _activeRenderers;
    id _layout;
    NSInteger _numberOfLineFragments;
    BOOL _hasTruncatedRanges;
    id _linkTextAttributesProvider;
}

@property (nonatomic) CGFloat minimumScaleFactor;
@property (nonatomic, readonly) CGFloat actualScaleFactor;
@property (nonatomic, readonly) NSRect totalBounds;

@property (nonatomic) CGFloat baselineOffset;
@property (nonatomic) CGFloat firstBaselineOffset;
@property (nonatomic) CGFloat scaledLineHeight;
@property (nonatomic) CGFloat scaledBaselineOffset;
@property (nonatomic) BOOL wrapsForTruncationMode;
@property (nonatomic) BOOL wantsBaselineOffset;
@property (nonatomic) BOOL wantsScaledLineHeight;
@property (nonatomic) BOOL wantsScaledBaselineOffset;
@property (nonatomic) BOOL cachesLayout;
@property (nonatomic) NSInteger maximumNumberOfLines;
@property (nonatomic) BOOL wantsNumberOfLineFragments;
@property (nonatomic) NSUInteger activeRenderers;
@property (nonatomic, retain) id layout;
@property (nonatomic, readonly) NSInteger numberOfLineFragments;
@property (nonatomic, readonly) BOOL hasTruncatedRanges;
@property (nonatomic, copy) id linkTextAttributesProvider;

@end
