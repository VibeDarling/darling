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

/* The status bar along the top of the screen: 20 points, or the notch's
 * height the host gives (UIScreen.m). */
CGFloat UIKitHostStatusBarHeight(void);
#define UIKitStatusBarHeight UIKitHostStatusBarHeight()
/* What the host's screen covers at its edges (a notch, a home indicator). */
UIEdgeInsets UIKitHostSafeAreaInsets(void);
/* Updates the safe area guides of views that moved (UIAutoLayout.m). */
void UIKitUpdateSafeAreas(void);

/* The color UIKit's string drawing uses (see UIKitAdditions.m). */
void UIKitSetDrawColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);
/* The image or color NAME of BUNDLE's asset catalog (Assets.car), or nil. */
@class UIImage, UIColor, NSBundle;
UIImage *UIKitAssetImage(NSString *name, NSBundle *bundle);
UIColor *UIKitAssetColor(NSString *name, NSBundle *bundle);
/* The view controller whose root view VIEW is, as the responder chain needs it. */
@class UIViewController, UIView;
void UIKitSetViewController(UIView *view, UIViewController *controller);
UIViewController *UIKitViewControllerForView(UIView *view);

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
/* UIMenu.m: the item's UIAction or menu, when it has one. */
- (BOOL)uikitPerformMenuOrPrimaryAction;
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

/* Nib loading (UINib.m). Each UIKit class reads its own archived keys in
 * -uikitDecodeNib:, after calling super's. */
@interface NSObject (UIKitNibDecoding)
- (void)uikitDecodeNib:(NSCoder *)coder;
@end

@interface UIView (UIKitNibDecoding)
/* Initializes a view being decoded, before -uikitDecodeNib:. */
- (instancetype)uikitInitForCoder:(NSCoder *)coder __attribute__((objc_method_family(init)));
@end

/* A decoded view's frame (nibs keep its bounds and center). */
CGRect UIKitArchivedFrame(NSCoder *coder);

/* iOS 7's top and bottom layout guides, as nibs archive them. */
@interface _UILayoutGuide : UIView
- (NSString *)uikitIdentifier;
- (void)uikitSetIdentifier:(NSString *)identifier;
- (CGFloat)length;
- (void)uikitPinInView:(UIView *)view length:(CGFloat)length;
@end

@interface _UILayoutSupportConstraint : NSLayoutConstraint
@end

/* The bundle the nib being decoded came from. */
NSBundle *UIKitNibBundle(NSCoder *coder);
/* The method as the nearest UIKit class among cls and its superclasses
 * implements it: what a nib's objects are initialized with, so that an
 * app's own overrides (-initWithFrame:) are not run, as on iOS. */
IMP UIKitOwnImplementation(Class cls, SEL selector);

@interface UIViewController (UIKitStoryboardPrivate)
- (void)uikitSetStoryboardIdentifier:(NSString *)identifier;
- (void)uikitSetSegueTemplates:(NSArray *)templates;
- (void)uikitSetViewExternalObjects:(NSDictionary *)objects;
/* Runs the relationship segues (before the view loads) or the embed ones. */
- (void)uikitPerformSeguesOnLoad:(BOOL)viewLoaded;
/* Loads the view from the view controller's nib, if it has one. */
- (BOOL)uikitLoadViewFromNib;
@end

/* The Info.plist's main storyboard or nib, then its window shown. */
void UIKitLoadMainInterface(UIApplication *application);
void UIKitShowMainInterface(UIApplication *application);

/* Hands a touch to the gesture recognizers, then to its view. */
void UIKitDispatchTouch(UITouch *touch, UITouchPhase phase);

@interface UIEvent ()
/* The one touches event, as on iOS. */
+ (UIEvent *)uikitTouchesEvent;
- (void)uikitAddTouch:(UITouch *)touch;
- (void)uikitRemoveTouch:(UITouch *)touch;
- (void)uikitSetTimestamp:(NSTimeInterval)timestamp;
@end

@class UITextField, UIMenu, UISearchController, UIWindowScene;

@interface UIAlertView (DarlingAlertController)
- (void)uikitSetTextFields:(NSArray<UITextField *> *)fields;
- (void)uikitSetDestructiveButtonIndex:(NSInteger)index;
- (void)uikitSetPreferredButtonIndex:(NSInteger)index;
- (void)uikitSetButtonAtIndex:(NSInteger)index enabled:(BOOL)enabled;
@end

@interface UIActionSheet (DarlingAlertController)
- (void)uikitSetButtonAtIndex:(NSInteger)index enabled:(BOOL)enabled;
@end

/* A presented controller that shows itself (an alert) instead of having
 * its view put over its presenter's. */
@interface UIViewController (DarlingSelfPresenting)
- (BOOL)uikitPresentsItself;
- (void)uikitShowPresented;
- (void)uikitHidePresented;
@end

/* iOS 13's scenes: whether the Info.plist asks for them, the one window
 * scene connected at launch, and the app's state passed on to it. */
BOOL UIKitUsesScenes(void);
void UIKitConnectMainScene(UIApplication *application);
void UIKitScenesEnterForeground(void);
void UIKitScenesBecomeActive(void);
void UIKitScenesResignActive(void);
void UIKitScenesEnterBackground(void);
void UIKitScenesDisconnect(void);
UIWindowScene *UIKitMainWindowScene(void);

/* Shows a menu's actions as an action sheet, over source's window. */
void UIKitShowMenu(UIMenu *menu, UIView *source);
/* Sends a key press to the first matching UIKeyCommand. */
BOOL UIKitPerformKeyCommand(NSEvent *event);

@interface UISearchBar (DarlingSearchController)
@property (nonatomic, weak) UISearchController *uikitSearchController;
@end

@interface UISearchController (DarlingPrivate)
- (void)uikitSearchBarDidBeginEditing;
- (void)uikitSearchBarTextDidChange;
- (void)uikitSearchBarCancelled;
@end

/* UILocalNotification's application:didReceiveLocalNotification:, from
 * UserNotifications, for apps that use only the old API. */
void UIKitForwardLocalNotifications(UIApplication *application);

#endif /* UIKIT_UIKITPRIVATE_H */
