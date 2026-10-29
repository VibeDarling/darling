/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIScreen.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSScreen.h>
#import "UIKitPrivate.h"
#include <stdio.h>
#include <stdlib.h>

/*
 * On a phone the host shell says what screen apps are shown on, rather
 * than the desktop's: DARLING_UISCREEN="390x844@3" (points, then the
 * scale), and DARLING_UISAFEAREA="47,0,34,0" (the points a notch or a home
 * indicator covers at the top, left, bottom and right).
 */
static BOOL sHostScreenRead;
static CGSize sHostScreenSize;
static CGFloat sHostScreenScale;
static UIEdgeInsets sHostSafeArea;

static void UIKitReadHostScreen(void)
{
	if (sHostScreenRead)
		return;
	sHostScreenRead = YES;
	const char *screen = getenv("DARLING_UISCREEN");
	double width = 0, height = 0, scale = 0;
	if (screen != NULL && sscanf(screen, "%lfx%lf@%lf", &width, &height, &scale) >= 2 && width > 0 && height > 0) {
		sHostScreenSize = CGSizeMake(width, height);
		sHostScreenScale = scale > 0 ? scale : 1;
	}
	const char *safeArea = getenv("DARLING_UISAFEAREA");
	double top = 0, left = 0, bottom = 0, right = 0;
	if (safeArea != NULL && sscanf(safeArea, "%lf,%lf,%lf,%lf", &top, &left, &bottom, &right) == 4)
		sHostSafeArea = UIEdgeInsetsMake(MAX(top, 0), MAX(left, 0), MAX(bottom, 0), MAX(right, 0));
}

UIEdgeInsets UIKitHostSafeAreaInsets(void)
{
	UIKitReadHostScreen();
	return sHostSafeArea;
}

/* A notch's height, where there is one; else the 20 points iOS 7 gave it. */
CGFloat UIKitHostStatusBarHeight(void)
{
	UIKitReadHostScreen();
	return sHostSafeArea.top > 0 ? sHostSafeArea.top : 20.0;
}

@implementation UIScreen

+ (UIScreen *)mainScreen
{
	static UIScreen *screen;
	if (screen == nil)
		screen = [[UIScreen alloc] init];
	return screen;
}

- (CGRect)bounds
{
	UIKitReadHostScreen();
	if (sHostScreenSize.width > 0)
		return CGRectMake(0, 0, sHostScreenSize.width, sHostScreenSize.height);
	NSScreen *screen = [NSScreen mainScreen];
	NSRect frame = screen != nil ? [screen frame] : NSMakeRect(0, 0, 1024, 768);
	return CGRectMake(0, 0, frame.size.width, frame.size.height);
}

- (CGFloat)scale
{
	UIKitReadHostScreen();
	if (sHostScreenScale > 0)
		return sHostScreenScale;
	NSScreen *screen = [NSScreen mainScreen];
	CGFloat scale = screen != nil ? [screen backingScaleFactor] : 1.0;
	return scale > 0 ? scale : 1.0;
}

- (CGFloat)nativeScale
{
	return [self scale];
}

- (CGRect)nativeBounds
{
	CGRect points = [self bounds];
	CGFloat scale = [self scale];
	return CGRectMake(0, 0, points.size.width * scale, points.size.height * scale);
}

@end
