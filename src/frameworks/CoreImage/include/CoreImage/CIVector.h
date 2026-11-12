/*
 This file is part of Darling.

 Copyright (C) 2017 Lubos Dolezel

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
#include <CoreGraphics/CoreGraphics.h>

@interface CIVector : NSObject

+ (CIVector *) vectorWithValues: (const CGFloat *) values count: (size_t) count;

+ (CIVector *) vectorWithX: (CGFloat) x;
+ (CIVector *) vectorWithX: (CGFloat) x Y: (CGFloat) y;
+ (CIVector *) vectorWithX: (CGFloat) x Y: (CGFloat) y Z: (CGFloat) z;
+ (CIVector *) vectorWithX: (CGFloat) x
                         Y: (CGFloat) y
                         Z: (CGFloat) z
                         W: (CGFloat) w;

- initWithValues: (const CGFloat *) values count: (size_t) count;
- initWithX: (CGFloat) x;
- initWithX: (CGFloat) x Y: (CGFloat) y;
- initWithX: (CGFloat) x Y: (CGFloat) y Z: (CGFloat) z;
- initWithX: (CGFloat) x Y: (CGFloat) y Z: (CGFloat) z W: (CGFloat) w;

- (size_t) count;
- (CGFloat) valueAtIndex: (size_t) index;

- (CGFloat) X;
- (CGFloat) Y;
- (CGFloat) Z;
- (CGFloat) W;

@end
