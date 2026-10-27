/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * Internal bridge declarations.  These are deliberately not in include/UIKit:
 * they expose AppKit types and must not appear in the iOS-facing API surface.
 */

#ifndef UIKIT_UIKITPRIVATE_H
#define UIKIT_UIKITPRIVATE_H

#import <UIKit/UIKit.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSWindow.h>

@interface UIColor (DarlingPrivate)
- (NSColor *)nsColor;
@end

@interface UIFont (DarlingPrivate)
- (NSFont *)nsFont;
@end

@interface UIView (DarlingPrivate)
- (void)setWindow:(UIWindow *)window;
- (void)attachToWindow:(UIWindow *)window;
@end

@class NSEvent;

@interface UITouch ()
@property (nonatomic, readwrite) UITouchPhase phase;
@property (nonatomic, readwrite) NSUInteger tapCount;
@property (nonatomic, readwrite) NSTimeInterval timestamp;
@property (nonatomic, readwrite, strong) UIView *view;
@property (nonatomic, readwrite, strong) UIWindow *window;
/* Moves the touch to where the pointer event happened. */
- (void)updateWithEvent:(NSEvent *)event phase:(UITouchPhase)phase;
@end

@interface UIEvent ()
- (instancetype)initWithTouch:(UITouch *)touch;
@end

#endif /* UIKIT_UIKITPRIVATE_H */
