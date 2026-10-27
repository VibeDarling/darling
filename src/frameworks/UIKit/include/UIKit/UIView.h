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

@class UIColor, UIWindow, UIEvent, UITouch;
#import <Foundation/NSSet.h>

/*
 * The values are UIKit's.  They equal AppKit's NSAutoresizingMaskOptions bit for
 * bit, and because every UIView is flipped, AppKit's "min Y" margin is the top
 * one, as UIKit's FlexibleTopMargin is.  NSView's -autoresizingMask therefore
 * serves both.
 */
typedef NS_OPTIONS(NSUInteger, UIViewAutoresizing) {
	UIViewAutoresizingNone                 = 0,
	UIViewAutoresizingFlexibleLeftMargin   = 1 << 0,
	UIViewAutoresizingFlexibleWidth        = 1 << 1,
	UIViewAutoresizingFlexibleRightMargin  = 1 << 2,
	UIViewAutoresizingFlexibleTopMargin    = 1 << 3,
	UIViewAutoresizingFlexibleHeight       = 1 << 4,
	UIViewAutoresizingFlexibleBottomMargin = 1 << 5
};

/*
 * UIView is an AppKit view: Darling has no separate compositor, so the UIKit
 * tree *is* the window's content view tree.  Its coordinate system is flipped
 * to match UIKit (origin top-left).
 *
 * Deviation from iOS: NSView already declares -window (NSWindow *) and its own
 * ivars, so the UIKit hosting window is exposed internally as -uiWindow rather
 * than shadowing -window with an incompatible type.
 */
@interface UIView : NSView {
@package
	UIColor *_uiBackgroundColor;
	UIWindow *_uiWindow;
	BOOL _uiNeedsLayout;
	BOOL _uiUserInteractionDisabled;
}

- (instancetype)initWithFrame:(CGRect)frame;

@property (nonatomic, strong) UIColor *backgroundColor;

- (void)layoutSubviews;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;

/*
 * Touches come from the pointer (see UITouch.h).  The view under the pointer
 * gets them; by default a view passes them on to its superview, which is
 * UIKit's responder chain for views.
 */
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;

@end

#endif /* UIKIT_UIVIEW_H */
