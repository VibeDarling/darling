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

@class UIImage;

/* Makes context the current one (for drawing with UIKit) until popped. */
extern void UIGraphicsPushContext(CGContextRef context);
extern void UIGraphicsPopContext(void);

/* A bitmap to draw into, current until it ends; scale 0 is the screen's. */
extern void UIGraphicsBeginImageContext(CGSize size);
extern void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale);
extern UIImage *UIGraphicsGetImageFromCurrentImageContext(void);
extern void UIGraphicsEndImageContext(void);

extern void UIRectFillUsingBlendMode(CGRect rect, CGBlendMode blendMode);
extern void UIRectFrameUsingBlendMode(CGRect rect, CGBlendMode blendMode);
extern void UIRectClip(CGRect rect);

#endif /* UIKIT_UIGRAPHICS_H */
