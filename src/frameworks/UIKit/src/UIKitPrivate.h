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
- (BOOL)uikitIsFlexibleSpace;
- (void)uikitPerform;
@end

@interface UINavigationController (DarlingPrivate)
/* The top controller's toolbar items changed. */
- (void)uikitToolbarItemsChanged;
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

@class NSEvent, NSImage;

@interface UIImage (DarlingPrivate)
- (instancetype)initWithNSImage:(NSImage *)image scale:(CGFloat)scale;
- (NSImage *)nsImage;
/* The image's shape filled with color. */
- (NSImage *)uikitImageTintedWith:(NSColor *)color;
@end

@interface UIImageView (DarlingPrivate)
/* Draw images in automatic rendering mode as templates (system buttons). */
@property (nonatomic) BOOL uikitTemplateByDefault;
/* Draw the image darkened, as a highlighted button's. */
@property (nonatomic) BOOL uikitDarkened;
@property (nonatomic) CGFloat uikitImageAlpha;
@end

@interface UITouch ()
@property (nonatomic, readwrite) UITouchPhase phase;
@property (nonatomic, readwrite) NSUInteger tapCount;
@property (nonatomic, readwrite) NSTimeInterval timestamp;
@property (nonatomic, readwrite, strong) UIView *view;
@property (nonatomic, readwrite, strong) UIWindow *window;
/* The dispatcher's bookkeeping: the recognizers that see the touch, and
 * whether its view does (a view without multiple touches gets only the first
 * finger, and an exclusive one shuts out the others). */
@property (nonatomic, strong) NSArray *uikitRecognizers;
@property (nonatomic) BOOL uikitToView;
@property (nonatomic) BOOL uikitViewBegan;
@property (nonatomic) BOOL uikitViewCancelled;
/* Moves the touch to where the pointer event happened. */
- (void)updateWithEvent:(NSEvent *)event phase:(UITouchPhase)phase;
- (void)uikitMoveTo:(NSPoint)location timestamp:(NSTimeInterval)timestamp phase:(UITouchPhase)phase;
/* Where the finger went down. */
- (CGPoint)uikitStartLocationInView:(UIView *)view;
@end

/* Attributes (or an attributed string) with UIKit's fonts and colors made AppKit's. */
NSDictionary *UIKitAppKitAttributes(NSDictionary *attributes);
NSAttributedString *UIKitAppKitAttributedString(NSAttributedString *string);

/* Gives a view or bar item what its classes' appearance proxies were told. */
void UIKitApplyAppearance(id object);

/* Hands a touch to the gesture recognizers, then to its view. */
void UIKitDispatchTouch(UITouch *touch, UITouchPhase phase);

@interface UIEvent ()
/* The one touches event, as on iOS. */
+ (UIEvent *)uikitTouchesEvent;
- (void)uikitAddTouch:(UITouch *)touch;
- (void)uikitRemoveTouch:(UITouch *)touch;
- (void)uikitSetTimestamp:(NSTimeInterval)timestamp;
@end

#endif /* UIKIT_UIKITPRIVATE_H */
