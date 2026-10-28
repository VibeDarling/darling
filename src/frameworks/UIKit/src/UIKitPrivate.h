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
#import <UIKit/UIScrollView.h>
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

/* The status bar UIWindow leaves room for along the top of the screen. */
#define UIKitStatusBarHeight 20.0

/* The color UIKit's string drawing uses (see UIKitAdditions.m). */
void UIKitSetDrawColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);

@interface UIViewController (DarlingPrivate)
- (void)uikitSetParent:(UIViewController *)parent;
/* Sends viewWillAppear:/viewDidAppear: (or the disappear pair) once. */
- (void)uikitAppear:(BOOL)animated;
- (void)uikitDisappear:(BOOL)animated;
@end

@class UIBarButtonItem, UITabBarController, UITabBar;

/* Posted (object: the item) when a bar item's title, image or state changes. */
extern NSString *const UIKitBarItemDidChangeNotification;
/* iOS 7's system blue. */
NSColor *UIKitTintColor(void);
UIView *UIKitViewForBarButtonItem(UIBarButtonItem *item, BOOL bold);
CGFloat UIKitPreferredWidthOfBarView(UIView *view);

@interface UIBarButtonItem (DarlingPrivate)
- (BOOL)uikitIsSpace;
- (void)uikitPerform;
@end

@interface UITabBarController (DarlingPrivate)
- (void)uikitTabBarItemsChanged;
@end

@interface UITabBar (DarlingPrivate)
- (void)uikitSetConcealed:(BOOL)concealed;
@end

@interface UIView (DarlingPrivateWindow)
- (UIWindow *)uiWindow;
@end

@interface UIScrollView (DarlingPrivate)
/* Called after the content offset changes. */
- (void)uikitDidScroll;
/* A press that did not become a drag. */
- (void)uikitTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)uikitTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)uikitTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
@end

/* Alerts and sheets on screen; native web views hide while there are any,
 * since they would draw over them. */
extern NSInteger UIKitOverlayCount;
extern NSString *const UIKitOverlaysDidChangeNotification;

@interface UIWindow (DarlingPrivate)
/* The window UIKit made key last, or the first visible one. */
+ (UIWindow *)uikitKeyWindow;
+ (NSArray *)uikitWindows;
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
