/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_NSATTRIBUTEDSTRING_H
#define UIKIT_NSATTRIBUTEDSTRING_H

#import <Foundation/NSAttributedString.h>
#import <AppKit/NSStringDrawing.h>

/*
 * The attribute names iOS apps link from UIKit.  Their values are AppKit's,
 * which draws Darling's text, so either framework's names work in either.
 * Declared as AppKit declares them (not const) so the two headers agree.
 */
#ifdef __cplusplus
extern "C" {
#endif
extern NSAttributedStringKey NSFontAttributeName;
extern NSAttributedStringKey NSParagraphStyleAttributeName;
extern NSAttributedStringKey NSForegroundColorAttributeName;
extern NSAttributedStringKey NSBackgroundColorAttributeName;
extern NSAttributedStringKey NSLigatureAttributeName;
extern NSAttributedStringKey NSKernAttributeName;
extern NSAttributedStringKey NSStrikethroughStyleAttributeName;
extern NSAttributedStringKey NSUnderlineStyleAttributeName;
extern NSAttributedStringKey NSStrokeColorAttributeName;
extern NSAttributedStringKey NSStrokeWidthAttributeName;
extern NSAttributedStringKey NSShadowAttributeName;
extern NSAttributedStringKey NSAttachmentAttributeName;
extern NSAttributedStringKey NSLinkAttributeName;
extern NSAttributedStringKey NSBaselineOffsetAttributeName;
extern NSAttributedStringKey NSUnderlineColorAttributeName;
extern NSAttributedStringKey NSStrikethroughColorAttributeName;
extern NSAttributedStringKey NSObliquenessAttributeName;
extern NSAttributedStringKey NSExpansionAttributeName;

/* Document reading options (-initWithData:options:documentAttributes:error:). */
extern NSString *NSDocumentTypeDocumentAttribute;
extern NSString *NSCharacterEncodingDocumentAttribute;
extern NSString *NSPlainTextDocumentType;
extern NSString *NSRTFTextDocumentType;
extern NSString *NSHTMLTextDocumentType;
#ifdef __cplusplus
}
#endif

/* What string drawing may scale or squeeze, and what it then did. Darling
 * draws text at its size, so the actual values are always the identity. */
@interface NSStringDrawingContext : NSObject
@property (nonatomic) CGFloat minimumScaleFactor;
@property (nonatomic) CGFloat minimumTrackingAdjustment;
@property (nonatomic, readonly) CGFloat actualScaleFactor;
@property (nonatomic, readonly) CGFloat actualTrackingAdjustment;
@property (nonatomic, readonly) CGRect totalBounds;
@end

/* iOS 7's string drawing, which takes a context. */
@interface NSString (UIKitStringDrawing)
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(NSStringDrawingContext *)context;
- (void)drawWithRect:(CGRect)rect options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(NSStringDrawingContext *)context;
@end

@interface NSAttributedString (UIKitStringDrawing)
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options context:(NSStringDrawingContext *)context;
@end

#endif /* UIKIT_NSATTRIBUTEDSTRING_H */
