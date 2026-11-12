/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISTRINGDRAWING_H
#define UIKIT_UISTRINGDRAWING_H

#import <Foundation/NSString.h>
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGColor.h>
#import <AppKit/NSParagraphStyle.h>

@class UIFont, UIImage;

/* UIKit's string drawing (deprecated in iOS 7, still widely used).  It draws
 * in the color last set with -[UIColor set] or UISetColor. */
@interface NSString (UIStringDrawing)
- (CGSize)sizeWithFont:(UIFont *)font;
- (CGSize)sizeWithFont:(UIFont *)font forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)sizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size;
- (CGSize)sizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)sizeWithFont:(UIFont *)font minFontSize:(CGFloat)minFontSize actualFontSize:(CGFloat *)actualFontSize forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)drawAtPoint:(CGPoint)point withFont:(UIFont *)font;
- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width withFont:(UIFont *)font fontSize:(CGFloat)fontSize lineBreakMode:(NSLineBreakMode)lineBreakMode baselineAdjustment:(NSInteger)baselineAdjustment;
- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width withFont:(UIFont *)font minFontSize:(CGFloat)minFontSize actualFontSize:(CGFloat *)actualFontSize lineBreakMode:(NSLineBreakMode)lineBreakMode baselineAdjustment:(NSInteger)baselineAdjustment;
- (CGSize)drawInRect:(CGRect)rect withFont:(UIFont *)font;
- (CGSize)drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment;
@end

#ifdef __cplusplus
extern "C" {
#endif
void UIRectFill(CGRect rect);
void UIRectFrame(CGRect rect);
/* Private UIKit functions old apps import. */
void UISetColor(CGColorRef color);
UIImage *_UIImageWithName(NSString *name);
#ifdef __cplusplus
}
#endif

#endif /* UIKIT_UISTRINGDRAWING_H */
