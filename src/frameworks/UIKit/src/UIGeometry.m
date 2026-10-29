/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIGeometry.h>
#import <UIKit/NSAttributedString.h>
#import <Foundation/NSString.h>
#include <stdlib.h>

#pragma mark - Attribute names

/* AppKit's values (cocotron/AppKit/NSAttributedString.m). */
NSAttributedStringKey NSFontAttributeName = @"NSFont";
NSAttributedStringKey NSParagraphStyleAttributeName = @"NSParagraphStyle";
NSAttributedStringKey NSForegroundColorAttributeName = @"NSForegroundColorAttributeName";
NSAttributedStringKey NSBackgroundColorAttributeName = @"NSBackgroundColorAttributeName";
NSAttributedStringKey NSLigatureAttributeName = @"NSLigatureAttributeName";
NSAttributedStringKey NSKernAttributeName = @"NSKernAttributeName";
NSAttributedStringKey NSStrikethroughStyleAttributeName = @"NSStrikethroughStyleAttributeName";
NSAttributedStringKey NSUnderlineStyleAttributeName = @"NSUnderlineStyleAttributeName";
NSAttributedStringKey NSStrokeColorAttributeName = @"NSStrokeColorAttributeName";
NSAttributedStringKey NSStrokeWidthAttributeName = @"NSStrokeWidthAttributeName";
NSAttributedStringKey NSShadowAttributeName = @"NSShadowAttributeName";
NSAttributedStringKey NSAttachmentAttributeName = @"NSAttachmentAttributeName";
NSAttributedStringKey NSLinkAttributeName = @"NSLinkAttributeName";
NSAttributedStringKey NSBaselineOffsetAttributeName = @"NSBaselineOffsetAttributeName";
NSAttributedStringKey NSUnderlineColorAttributeName = @"NSUnderlineColorAttributeName";
NSAttributedStringKey NSStrikethroughColorAttributeName = @"NSStrikethroughColorAttributeName";
NSAttributedStringKey NSObliquenessAttributeName = @"NSObliquenessAttributeName";
NSAttributedStringKey NSExpansionAttributeName = @"NSExpansionAttributeName";

NSString *NSDocumentTypeDocumentAttribute = @"DocumentType";
NSString *NSCharacterEncodingDocumentAttribute = @"CharacterEncoding";
NSString *NSPlainTextDocumentType = @"NSPlainText";
NSString *NSRTFTextDocumentType = @"NSRTF";
NSString *NSHTMLTextDocumentType = @"NSHTML";

#pragma mark - NSStringDrawingContext

@implementation NSStringDrawingContext

@synthesize minimumScaleFactor = _minimumScaleFactor;
@synthesize minimumTrackingAdjustment = _minimumTrackingAdjustment;

- (CGFloat)actualScaleFactor { return 1; }
- (CGFloat)actualTrackingAdjustment { return 0; }
- (CGRect)totalBounds { return CGRectZero; }

@end

#pragma mark - Geometry strings

const UIEdgeInsets UIEdgeInsetsZero = { 0, 0, 0, 0 };
const UIOffset UIOffsetZero = { 0, 0 };

NSString *NSStringFromCGPoint(CGPoint point)
{
	return [NSString stringWithFormat:@"{%g, %g}", point.x, point.y];
}

NSString *NSStringFromCGSize(CGSize size)
{
	return [NSString stringWithFormat:@"{%g, %g}", size.width, size.height];
}

NSString *NSStringFromCGRect(CGRect rect)
{
	return [NSString stringWithFormat:@"{{%g, %g}, {%g, %g}}", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

NSString *NSStringFromCGAffineTransform(CGAffineTransform t)
{
	return [NSString stringWithFormat:@"[%g, %g, %g, %g, %g, %g]", t.a, t.b, t.c, t.d, t.tx, t.ty];
}

NSString *NSStringFromUIEdgeInsets(UIEdgeInsets insets)
{
	return [NSString stringWithFormat:@"{%g, %g, %g, %g}", insets.top, insets.left, insets.bottom, insets.right];
}

/* The numbers in string, in order, ignoring the braces and commas around them. */
static NSUInteger UIKitNumbers(NSString *string, CGFloat *numbers, NSUInteger count)
{
	const char *p = [string UTF8String];
	NSUInteger found = 0;
	while (p != NULL && *p != '\0' && found < count) {
		char *end;
		double value = strtod(p, &end);
		if (end != p) {
			numbers[found++] = value;
			p = end;
		} else
			p++;
	}
	for (NSUInteger i = found; i < count; i++)
		numbers[i] = 0;
	return found;
}

CGPoint CGPointFromString(NSString *string)
{
	CGFloat n[2];
	UIKitNumbers(string, n, 2);
	return CGPointMake(n[0], n[1]);
}

CGSize CGSizeFromString(NSString *string)
{
	CGFloat n[2];
	UIKitNumbers(string, n, 2);
	return CGSizeMake(n[0], n[1]);
}

CGRect CGRectFromString(NSString *string)
{
	CGFloat n[4];
	UIKitNumbers(string, n, 4);
	return CGRectMake(n[0], n[1], n[2], n[3]);
}

CGAffineTransform CGAffineTransformFromString(NSString *string)
{
	CGFloat n[6];
	if (UIKitNumbers(string, n, 6) < 6)
		return CGAffineTransformIdentity;
	return CGAffineTransformMake(n[0], n[1], n[2], n[3], n[4], n[5]);
}

UIEdgeInsets UIEdgeInsetsFromString(NSString *string)
{
	CGFloat n[4];
	UIKitNumbers(string, n, 4);
	return UIEdgeInsetsMake(n[0], n[1], n[2], n[3]);
}
