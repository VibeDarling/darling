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

static const UIEdgeInsets UIEdgeInsetsZero = { 0, 0, 0, 0 };

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
