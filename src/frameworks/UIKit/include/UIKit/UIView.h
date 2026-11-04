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
#import <CoreGraphics/CGAffineTransform.h>

@class UIColor, UIWindow;

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
	CGAffineTransform _uiTransform;
	BOOL _uiClipsToBounds;
	NSInteger _uiTag;
}

- (instancetype)initWithFrame:(CGRect)frame;

@property (nonatomic, strong) UIColor *backgroundColor;

/*
 * Members NSView does not have.  center is derived from the frame, alpha maps
 * to NSView's alphaValue, and tag is settable (NSView's is read-only and
 * defaults to -1; UIKit's defaults to 0).  transform and clipsToBounds are
 * stored state: nothing draws with them yet.
 */
@property (nonatomic) CGPoint center;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic) CGFloat alpha;
@property (nonatomic) NSInteger tag;
@property (nonatomic) BOOL clipsToBounds;

- (void)layoutSubviews;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;

@end

#endif /* UIKIT_UIVIEW_H */
