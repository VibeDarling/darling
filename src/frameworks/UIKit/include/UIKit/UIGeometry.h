/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIGEOMETRY_H
#define UIKIT_UIGEOMETRY_H

#import <Foundation/NSObjCRuntime.h>
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGAffineTransform.h>

@class NSString;

typedef struct UIEdgeInsets {
	CGFloat top, left, bottom, right;
} UIEdgeInsets;

static inline UIEdgeInsets UIEdgeInsetsMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right)
{
	UIEdgeInsets insets = { top, left, bottom, right };
	return insets;
}

static inline CGRect UIEdgeInsetsInsetRect(CGRect rect, UIEdgeInsets insets)
{
	rect.origin.x += insets.left;
	rect.origin.y += insets.top;
	rect.size.width -= insets.left + insets.right;
	rect.size.height -= insets.top + insets.bottom;
	return rect;
}

extern const UIEdgeInsets UIEdgeInsetsZero;

typedef struct UIOffset {
	CGFloat horizontal, vertical;
} UIOffset;

static inline UIOffset UIOffsetMake(CGFloat horizontal, CGFloat vertical)
{
	UIOffset offset = { horizontal, vertical };
	return offset;
}

static inline BOOL UIOffsetEqualToOffset(UIOffset a, UIOffset b)
{
	return a.horizontal == b.horizontal && a.vertical == b.vertical;
}

extern const UIOffset UIOffsetZero;

static inline BOOL UIEdgeInsetsEqualToEdgeInsets(UIEdgeInsets a, UIEdgeInsets b)
{
	return a.top == b.top && a.left == b.left && a.bottom == b.bottom && a.right == b.right;
}

/* As on iOS: "{x, y}", "{{x, y}, {w, h}}", "{top, left, bottom, right}". */
#ifdef __cplusplus
extern "C" {
#endif
NSString *NSStringFromCGPoint(CGPoint point);
NSString *NSStringFromCGSize(CGSize size);
NSString *NSStringFromCGRect(CGRect rect);
NSString *NSStringFromCGAffineTransform(CGAffineTransform transform);
NSString *NSStringFromUIEdgeInsets(UIEdgeInsets insets);
CGPoint CGPointFromString(NSString *string);
CGSize CGSizeFromString(NSString *string);
CGRect CGRectFromString(NSString *string);
CGAffineTransform CGAffineTransformFromString(NSString *string);
UIEdgeInsets UIEdgeInsetsFromString(NSString *string);
#ifdef __cplusplus
}
#endif

typedef NS_ENUM(NSInteger, UIInterfaceOrientation) {
	UIInterfaceOrientationUnknown = 0,
	UIInterfaceOrientationPortrait = 1,
	UIInterfaceOrientationPortraitUpsideDown = 2,
	UIInterfaceOrientationLandscapeRight = 3,
	UIInterfaceOrientationLandscapeLeft = 4,
};

#define UIInterfaceOrientationIsPortrait(orientation) ((orientation) == UIInterfaceOrientationPortrait || (orientation) == UIInterfaceOrientationPortraitUpsideDown)
#define UIInterfaceOrientationIsLandscape(orientation) ((orientation) == UIInterfaceOrientationLandscapeLeft || (orientation) == UIInterfaceOrientationLandscapeRight)

#endif /* UIKIT_UIGEOMETRY_H */
