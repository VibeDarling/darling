/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <Foundation/Foundation.h>

/* How the iPad pointer looks over a view. There is no pointer here; the Swift overlay's
 * init(effect:shape:) makes one that nothing reads. */
@interface UIPointerStyle : NSObject <NSCopying>
@end
