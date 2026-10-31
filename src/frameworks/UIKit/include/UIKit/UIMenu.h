/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIMENU_H
#define UIKIT_UIMENU_H

#import <UIKit/UIView.h>
#import <UIKit/UIControl.h>
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UIResponder.h>
#import <UIKit/UIViewController.h>

@class UIImage, UIMenu, UIAction, UIKeyCommand, UIContextMenuInteraction, UIContextMenuConfiguration;

typedef NS_OPTIONS(NSUInteger, UIMenuElementAttributes) {
	UIMenuElementAttributesDisabled = 1 << 0,
	UIMenuElementAttributesDestructive = 1 << 1,
	UIMenuElementAttributesHidden = 1 << 2,
	UIMenuElementAttributesKeepsMenuPresented = 1 << 3,
};

typedef NS_ENUM(NSInteger, UIMenuElementState) {
	UIMenuElementStateOff,
	UIMenuElementStateOn,
	UIMenuElementStateMixed,
};

typedef NS_OPTIONS(NSUInteger, UIMenuOptions) {
	UIMenuOptionsDisplayInline = 1 << 0,
	UIMenuOptionsDestructive = 1 << 1,
	UIMenuOptionsSingleSelection = 1 << 5,
	UIMenuOptionsDisplayAsPalette = 1 << 7,
};

typedef NSString *UIMenuIdentifier;
typedef NSString *UIActionIdentifier;

@interface UIMenuElement : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, readonly) UIImage *image;
@end

typedef void (^UIActionHandler)(UIAction *action);

@interface UIAction : UIMenuElement
+ (instancetype)actionWithHandler:(UIActionHandler)handler;
+ (instancetype)actionWithTitle:(NSString *)title image:(UIImage *)image identifier:(UIActionIdentifier)identifier handler:(UIActionHandler)handler;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) UIImage *image;
@property (nonatomic, copy) NSString *discoverabilityTitle;
@property (nonatomic, readonly) UIActionIdentifier identifier;
@property (nonatomic) UIMenuElementAttributes attributes;
@property (nonatomic) UIMenuElementState state;
/* The control or bar item it was sent from. */
@property (nonatomic, readonly) id sender;
@end

@interface UIMenu : UIMenuElement
+ (UIMenu *)menuWithChildren:(NSArray<UIMenuElement *> *)children;
+ (UIMenu *)menuWithTitle:(NSString *)title children:(NSArray<UIMenuElement *> *)children;
+ (UIMenu *)menuWithTitle:(NSString *)title image:(UIImage *)image identifier:(UIMenuIdentifier)identifier options:(UIMenuOptions)options children:(NSArray<UIMenuElement *> *)children;
@property (nonatomic, readonly) UIMenuIdentifier identifier;
@property (nonatomic, readonly) UIMenuOptions options;
@property (nonatomic, readonly) NSArray<UIMenuElement *> *children;
@property (nonatomic, readonly) NSArray<UIMenuElement *> *selectedElements;
- (UIMenu *)menuByReplacingChildren:(NSArray<UIMenuElement *> *)newChildren;
@end

/* Elements made when the menu is shown. */
@interface UIDeferredMenuElement : UIMenuElement
+ (instancetype)elementWithProvider:(void (^)(void (^completion)(NSArray<UIMenuElement *> *elements)))elementProvider;
+ (instancetype)elementWithUncachedProvider:(void (^)(void (^completion)(NSArray<UIMenuElement *> *elements)))elementProvider;
@end

@interface UICommand : UIMenuElement
+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action propertyList:(id)propertyList;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) UIImage *image;
@property (nonatomic, copy) NSString *discoverabilityTitle;
@property (nonatomic, readonly) SEL action;
@property (nonatomic, readonly) id propertyList;
@property (nonatomic) UIMenuElementAttributes attributes;
@property (nonatomic) UIMenuElementState state;
@end

typedef NS_OPTIONS(NSInteger, UIKeyModifierFlags) {
	UIKeyModifierAlphaShift = 1 << 16,
	UIKeyModifierShift = 1 << 17,
	UIKeyModifierControl = 1 << 18,
	UIKeyModifierAlternate = 1 << 19,
	UIKeyModifierCommand = 1 << 20,
	UIKeyModifierNumericPad = 1 << 21,
};

extern NSString *const UIKeyInputUpArrow;
extern NSString *const UIKeyInputDownArrow;
extern NSString *const UIKeyInputLeftArrow;
extern NSString *const UIKeyInputRightArrow;
extern NSString *const UIKeyInputEscape;
extern NSString *const UIKeyInputPageUp;
extern NSString *const UIKeyInputPageDown;
extern NSString *const UIKeyInputHome;
extern NSString *const UIKeyInputEnd;
extern NSString *const UIKeyInputDelete;

/*
 * A hardware key's command: when a key is pressed, the first command of
 * the responders in front (the first responder and the views above it,
 * then the view controllers shown, the application and its delegate)
 * with that key and modifiers is sent its action, up the chain.
 */
@interface UIKeyCommand : UICommand
+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action;
+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle;
+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action input:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags propertyList:(id)propertyList;
@property (nonatomic, readonly) NSString *input;
@property (nonatomic, readonly) UIKeyModifierFlags modifierFlags;
@property (nonatomic) BOOL wantsPriorityOverSystemBehavior;
@end

@interface UIResponder (UIKeyCommands)
@property (nonatomic, readonly) NSArray<UIKeyCommand *> *keyCommands;
@end

@interface UIView (UIKeyCommands)
@property (nonatomic, readonly) NSArray<UIKeyCommand *> *keyCommands;
@end

@interface UIViewController (UIKeyCommands)
- (void)addKeyCommand:(UIKeyCommand *)keyCommand;
- (void)removeKeyCommand:(UIKeyCommand *)keyCommand;
@end

#pragma mark - Interactions

@protocol UIInteraction <NSObject>
@property (nonatomic, readonly, weak) UIView *view;
- (void)willMoveToView:(UIView *)view;
- (void)didMoveToView:(UIView *)view;
@end

@interface UIView (UIInteractions)
- (void)addInteraction:(id<UIInteraction>)interaction;
- (void)removeInteraction:(id<UIInteraction>)interaction;
@property (nonatomic, copy) NSArray<id<UIInteraction>> *interactions;
@end

typedef UIMenu *(^UIContextMenuActionProvider)(NSArray<UIMenuElement *> *suggestedActions);
typedef UIViewController *(^UIContextMenuContentPreviewProvider)(void);

@interface UIContextMenuConfiguration : NSObject
+ (instancetype)configurationWithIdentifier:(id<NSCopying>)identifier previewProvider:(UIContextMenuContentPreviewProvider)previewProvider actionProvider:(UIContextMenuActionProvider)actionProvider;
@property (nonatomic, readonly) id<NSCopying> identifier;
@end

@protocol UIContextMenuInteractionDelegate <NSObject>
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location;
@optional
- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id)animator;
- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id)animator;
@end

/* A long press on its view shows the delegate's menu, as an action sheet;
   there is no preview. */
@interface UIContextMenuInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(id<UIContextMenuInteractionDelegate>)delegate;
@property (nonatomic, readonly, weak) id<UIContextMenuInteractionDelegate> delegate;
- (CGPoint)locationInView:(UIView *)view;
- (void)dismissMenu;
@end

#pragma mark - Controls and bar items

@interface UIControl (UIActions)
- (instancetype)initWithFrame:(CGRect)frame primaryAction:(UIAction *)primaryAction;
- (void)addAction:(UIAction *)action forControlEvents:(UIControlEvents)controlEvents;
- (void)removeAction:(UIAction *)action forControlEvents:(UIControlEvents)controlEvents;
- (void)removeActionForIdentifier:(UIActionIdentifier)actionIdentifier forControlEvents:(UIControlEvents)controlEvents;
- (void)enumerateEventHandlers:(void (^)(UIAction *actionHandler, id target, SEL action, UIControlEvents controlEvents, BOOL *stop))iterator;
@property (nonatomic, getter=isContextMenuInteractionEnabled) BOOL contextMenuInteractionEnabled;
@property (nonatomic) BOOL showsMenuAsPrimaryAction;
@end

/* A button's menu shows when it is tapped (showsMenuAsPrimaryAction) or
   long-pressed. */
@interface UIButton (UIMenus)
+ (instancetype)buttonWithType:(UIButtonType)buttonType primaryAction:(UIAction *)primaryAction;
+ (instancetype)systemButtonWithPrimaryAction:(UIAction *)primaryAction;
@property (nonatomic, copy) UIMenu *menu;
@property (nonatomic) BOOL changesSelectionAsPrimaryAction;
@end

@interface UIBarButtonItem (UIMenus)
- (instancetype)initWithPrimaryAction:(UIAction *)primaryAction;
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem primaryAction:(UIAction *)primaryAction;
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem menu:(UIMenu *)menu;
- (instancetype)initWithTitle:(NSString *)title menu:(UIMenu *)menu;
- (instancetype)initWithImage:(UIImage *)image menu:(UIMenu *)menu;
- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image primaryAction:(UIAction *)primaryAction menu:(UIMenu *)menu;
@property (nonatomic, copy) UIAction *primaryAction;
@property (nonatomic, copy) UIMenu *menu;
@end

#endif /* UIKIT_UIMENU_H */
