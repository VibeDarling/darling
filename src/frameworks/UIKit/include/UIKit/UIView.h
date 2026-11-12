/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIVIEW_H
#define UIKIT_UIVIEW_H

#import <AppKit/NSView.h>
#import <CoreGraphics/CGGeometry.h>

@class UIColor, UIWindow;

/*
 * UIView is an AppKit view: Darling has no separate compositor, so the UIKit
 * tree *is* the window's content view tree.  Its coordinate system is flipped
 * to match UIKit (origin top-left).
 *
 * -window answers the UIWindow, as on iOS; the AppKit window hosting it is
 * NSView's -_appKitWindow. iOS code sees neither NSView's -window nor its ivars.
 */
@interface UIView : NSView {
@package
	UIColor *_uiBackgroundColor;
	UIWindow *_uiWindow;
	BOOL _uiNeedsLayout;
}

- (instancetype)initWithFrame:(CGRect)frame;

@property (nonatomic, strong) UIColor *backgroundColor;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-property-type"
@property (nonatomic, readonly) UIWindow *window;
#pragma clang diagnostic pop

- (void)layoutSubviews;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;

@end

#endif /* UIKIT_UIVIEW_H */
