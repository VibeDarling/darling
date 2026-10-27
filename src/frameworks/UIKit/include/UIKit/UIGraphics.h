/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIGRAPHICS_H
#define UIKIT_UIGRAPHICS_H

#import <CoreGraphics/CGContext.h>

/* Inside -drawRect:, the context the view is drawing into. */
extern CGContextRef UIGraphicsGetCurrentContext(void);

#endif /* UIKIT_UIGRAPHICS_H */
