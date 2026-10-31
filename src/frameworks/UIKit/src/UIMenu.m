/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIMenu.h>
#import <UIKit/UIAlertView.h>
#import <UIKit/UIGestureRecognizer.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIApplicationDelegate.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UITabBarController.h>
#import <UIKit/UITextInput.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSText.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "UIKitPrivate.h"

NSString *const UIKeyInputUpArrow = @"UIKeyInputUpArrow";
NSString *const UIKeyInputDownArrow = @"UIKeyInputDownArrow";
NSString *const UIKeyInputLeftArrow = @"UIKeyInputLeftArrow";
NSString *const UIKeyInputRightArrow = @"UIKeyInputRightArrow";
NSString *const UIKeyInputEscape = @"\x1B";
NSString *const UIKeyInputPageUp = @"UIKeyInputPageUp";
NSString *const UIKeyInputPageDown = @"UIKeyInputPageDown";
NSString *const UIKeyInputHome = @"UIKeyInputHome";
NSString *const UIKeyInputEnd = @"UIKeyInputEnd";
NSString *const UIKeyInputDelete = @"UIKeyInputDelete";

#pragma mark - Elements

@implementation UIMenuElement {
@protected
	NSString *_title;
	NSString *_subtitle;
	UIImage *_image;
}

+ (BOOL)supportsSecureCoding { return YES; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (void)encodeWithCoder:(NSCoder *)coder { }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (NSString *)title { return _title; }
- (NSString *)subtitle { return _subtitle; }
- (void)setSubtitle:(NSString *)subtitle { _subtitle = [subtitle copy]; }
- (UIImage *)image { return _image; }

@end

@implementation UIAction {
	UIActionHandler _handler;
	UIActionIdentifier _identifier;
	NSString *_discoverabilityTitle;
	UIMenuElementAttributes _attributes;
	UIMenuElementState _state;
	__weak id _sender;
}

+ (instancetype)actionWithHandler:(UIActionHandler)handler
{
	return [self actionWithTitle:@"" image:nil identifier:nil handler:handler];
}

+ (instancetype)actionWithTitle:(NSString *)title image:(UIImage *)image identifier:(UIActionIdentifier)identifier handler:(UIActionHandler)handler
{
	UIAction *action = [[self alloc] init];
	action->_title = [title copy] ?: @"";
	action->_image = image;
	action->_identifier = [identifier copy] ?: [[NSUUID UUID] UUIDString];
	action->_handler = [handler copy];
	return action;
}

- (void)setTitle:(NSString *)title { _title = [title copy] ?: @""; }
- (void)setImage:(UIImage *)image { _image = image; }
- (NSString *)discoverabilityTitle { return _discoverabilityTitle; }
- (void)setDiscoverabilityTitle:(NSString *)title { _discoverabilityTitle = [title copy]; }
- (UIActionIdentifier)identifier { return _identifier; }
- (UIMenuElementAttributes)attributes { return _attributes; }
- (void)setAttributes:(UIMenuElementAttributes)attributes { _attributes = attributes; }
- (UIMenuElementState)state { return _state; }
- (void)setState:(UIMenuElementState)state { _state = state; }
- (id)sender { return _sender; }

- (void)uikitPerformWithSender:(id)sender
{
	_sender = sender;
	if (_handler != nil)
		_handler(self);
}

@end

@implementation UIMenu {
	UIMenuIdentifier _identifier;
	UIMenuOptions _options;
	NSArray<UIMenuElement *> *_children;
}

+ (UIMenu *)menuWithChildren:(NSArray<UIMenuElement *> *)children
{
	return [self menuWithTitle:@"" image:nil identifier:nil options:0 children:children];
}

+ (UIMenu *)menuWithTitle:(NSString *)title children:(NSArray<UIMenuElement *> *)children
{
	return [self menuWithTitle:title image:nil identifier:nil options:0 children:children];
}

+ (UIMenu *)menuWithTitle:(NSString *)title image:(UIImage *)image identifier:(UIMenuIdentifier)identifier options:(UIMenuOptions)options children:(NSArray<UIMenuElement *> *)children
{
	UIMenu *menu = [[self alloc] init];
	menu->_title = [title copy] ?: @"";
	menu->_image = image;
	menu->_identifier = [identifier copy] ?: [[NSUUID UUID] UUIDString];
	menu->_options = options;
	menu->_children = [children copy] ?: @[];
	return menu;
}

- (UIMenuIdentifier)identifier { return _identifier; }
- (UIMenuOptions)options { return _options; }
- (NSArray<UIMenuElement *> *)children { return _children; }

- (NSArray<UIMenuElement *> *)selectedElements
{
	NSMutableArray *selected = [NSMutableArray array];
	for (UIMenuElement *element in _children)
		if ([element respondsToSelector:@selector(state)] && [(UIAction *)element state] == UIMenuElementStateOn)
			[selected addObject:element];
	return selected;
}

- (UIMenu *)menuByReplacingChildren:(NSArray<UIMenuElement *> *)children
{
	return [UIMenu menuWithTitle:_title image:_image identifier:_identifier options:_options children:children];
}

@end

@implementation UIDeferredMenuElement {
	void (^_provider)(void (^)(NSArray<UIMenuElement *> *));
	NSArray<UIMenuElement *> *_cached;
	BOOL _uncached;
}

+ (instancetype)elementWithProvider:(void (^)(void (^completion)(NSArray<UIMenuElement *> *elements)))provider
{
	UIDeferredMenuElement *element = [[self alloc] init];
	element->_provider = [provider copy];
	return element;
}

+ (instancetype)elementWithUncachedProvider:(void (^)(void (^completion)(NSArray<UIMenuElement *> *elements)))provider
{
	UIDeferredMenuElement *element = [self elementWithProvider:provider];
	element->_uncached = YES;
	return element;
}

/* What the provider gives at once; a provider that answers later is
   too late for a menu shown now. */
- (NSArray<UIMenuElement *> *)uikitElements
{
	if (_cached != nil)
		return _cached;
	__block NSArray *elements = nil;
	if (_provider != nil)
		_provider(^(NSArray<UIMenuElement *> *provided) {
			elements = [provided copy];
		});
	if (!_uncached)
		_cached = elements;
	return elements ?: @[];
}

@end

@implementation UICommand {
@protected
	SEL _action;
	id _propertyList;
	NSString *_discoverabilityTitle;
	UIMenuElementAttributes _attributes;
	UIMenuElementState _state;
}

+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action propertyList:(id)propertyList
{
	UICommand *command = [[self alloc] init];
	command->_title = [title copy] ?: @"";
	command->_image = image;
	command->_action = action;
	command->_propertyList = propertyList;
	return command;
}

- (void)setTitle:(NSString *)title { _title = [title copy] ?: @""; }
- (void)setImage:(UIImage *)image { _image = image; }
- (NSString *)discoverabilityTitle { return _discoverabilityTitle; }
- (void)setDiscoverabilityTitle:(NSString *)title { _discoverabilityTitle = [title copy]; }
- (SEL)action { return _action; }
- (id)propertyList { return _propertyList; }
- (UIMenuElementAttributes)attributes { return _attributes; }
- (void)setAttributes:(UIMenuElementAttributes)attributes { _attributes = attributes; }
- (UIMenuElementState)state { return _state; }
- (void)setState:(UIMenuElementState)state { _state = state; }

@end

@implementation UIKeyCommand {
	NSString *_input;
	UIKeyModifierFlags _modifierFlags;
}

@synthesize wantsPriorityOverSystemBehavior = _wantsPriorityOverSystemBehavior;

+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action
{
	return [self commandWithTitle:@"" image:nil action:action input:input modifierFlags:modifierFlags propertyList:nil];
}

+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle
{
	UIKeyCommand *command = [self keyCommandWithInput:input modifierFlags:modifierFlags action:action];
	[command setDiscoverabilityTitle:discoverabilityTitle];
	return command;
}

+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action input:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags propertyList:(id)propertyList
{
	UIKeyCommand *command = [self commandWithTitle:title image:image action:action propertyList:propertyList];
	command->_input = [input copy];
	command->_modifierFlags = modifierFlags;
	return command;
}

- (NSString *)input { return _input; }
- (UIKeyModifierFlags)modifierFlags { return _modifierFlags; }

@end

#pragma mark - Key commands

@implementation UIResponder (UIKeyCommands)
- (NSArray<UIKeyCommand *> *)keyCommands { return nil; }
@end

@implementation UIView (UIKeyCommands)
- (NSArray<UIKeyCommand *> *)keyCommands { return nil; }
@end

static char UIKitKeyCommandsKey;

@implementation UIViewController (UIKeyCommands)

- (NSArray<UIKeyCommand *> *)keyCommands
{
	return [objc_getAssociatedObject(self, &UIKitKeyCommandsKey) copy];
}

- (void)addKeyCommand:(UIKeyCommand *)keyCommand
{
	NSMutableArray *commands = objc_getAssociatedObject(self, &UIKitKeyCommandsKey);
	if (commands == nil) {
		commands = [NSMutableArray array];
		objc_setAssociatedObject(self, &UIKitKeyCommandsKey, commands, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	if (keyCommand != nil)
		[commands addObject:keyCommand];
}

- (void)removeKeyCommand:(UIKeyCommand *)keyCommand
{
	[objc_getAssociatedObject(self, &UIKitKeyCommandsKey) removeObject:keyCommand];
}

@end

/* The controllers on screen, the most specific first. */
static void UIKitAddShownControllers(UIViewController *controller, NSMutableArray *chain)
{
	if (controller == nil)
		return;
	UIViewController *presented = [controller presentedViewController];
	if (presented != nil)
		UIKitAddShownControllers(presented, chain);
	if ([controller isKindOfClass:[UINavigationController class]])
		UIKitAddShownControllers([(UINavigationController *)controller topViewController], chain);
	else if ([controller isKindOfClass:[UITabBarController class]])
		UIKitAddShownControllers([(UITabBarController *)controller selectedViewController], chain);
	else
		for (UIViewController *child in [[controller childViewControllers] reverseObjectEnumerator])
			UIKitAddShownControllers(child, chain);
	if (![chain containsObject:controller])
		[chain addObject:controller];
}

/* The responders an action looks for a target in: the key window's first
   responder and the views above it, then the controllers, the application
   and its delegate. */
static NSArray *UIKitResponderChain(void)
{
	NSMutableArray *chain = [NSMutableArray array];
	UIWindow *window = [UIWindow uikitKeyWindow];
	NSWindow *host = [window window];
	for (NSResponder *responder = [host firstResponder]; responder != nil; responder = [responder nextResponder])
		if (![chain containsObject:responder])
			[chain addObject:responder];
	UIKitAddShownControllers([window rootViewController], chain);
	UIApplication *application = [UIApplication sharedApplication];
	if (application != nil)
		[chain addObject:application];
	id delegate = [application delegate];
	if (delegate != nil && ![chain containsObject:delegate])
		[chain addObject:delegate];
	return chain;
}

static void UIKitSendUpChain(SEL action, id sender, NSArray *chain, NSUInteger from)
{
	for (NSUInteger i = from; i < [chain count]; i++) {
		id responder = [chain objectAtIndex:i];
		if ([responder respondsToSelector:action]) {
			((void (*)(id, SEL, id))objc_msgSend)(responder, action, sender);
			return;
		}
	}
}

static NSString *UIKitKeyInput(NSEvent *event)
{
	NSString *characters = [event charactersIgnoringModifiers];
	if ([characters length] == 0)
		return nil;
	switch ([characters characterAtIndex:0]) {
	case NSUpArrowFunctionKey: return UIKeyInputUpArrow;
	case NSDownArrowFunctionKey: return UIKeyInputDownArrow;
	case NSLeftArrowFunctionKey: return UIKeyInputLeftArrow;
	case NSRightArrowFunctionKey: return UIKeyInputRightArrow;
	case NSPageUpFunctionKey: return UIKeyInputPageUp;
	case NSPageDownFunctionKey: return UIKeyInputPageDown;
	case NSHomeFunctionKey: return UIKeyInputHome;
	case NSEndFunctionKey: return UIKeyInputEnd;
	case NSDeleteFunctionKey: return UIKeyInputDelete;
	default: return [characters lowercaseString];
	}
}

BOOL UIKitPerformKeyCommand(NSEvent *event)
{
	if ([event type] != NSKeyDown)
		return NO;
	NSString *input = UIKitKeyInput(event);
	if (input == nil)
		return NO;
	const NSUInteger mask = UIKeyModifierShift | UIKeyModifierControl | UIKeyModifierAlternate | UIKeyModifierCommand;
	NSUInteger modifiers = [event modifierFlags] & mask;
	NSArray *chain = UIKitResponderChain();
	/* Typing goes to text first, unless a command or control key is held. */
	id first = [chain firstObject];
	BOOL typing = [first isKindOfClass:[NSText class]] || [first conformsToProtocol:@protocol(UIKeyInput)];
	BOOL shortcut = (modifiers & (UIKeyModifierControl | UIKeyModifierCommand)) != 0;
	for (NSUInteger i = 0; i < [chain count]; i++) {
		id responder = [chain objectAtIndex:i];
		if (![responder respondsToSelector:@selector(keyCommands)])
			continue;
		for (UIKeyCommand *command in [responder keyCommands]) {
			if (![command isKindOfClass:[UIKeyCommand class]] || ([command modifierFlags] & mask) != modifiers)
				continue;
			NSString *wanted = [command input];
			if (![wanted isEqualToString:input] && ![[wanted lowercaseString] isEqualToString:input])
				continue;
			if (typing && !shortcut && ![command wantsPriorityOverSystemBehavior])
				return NO;
			if ([command attributes] & UIMenuElementAttributesDisabled)
				return NO;
			UIKitSendUpChain([command action], command, chain, i);
			return YES;
		}
	}
	return NO;
}

#pragma mark - Showing a menu

/* Shown as an action sheet; it keeps itself while shown. */
@interface UIKitMenuSheet : NSObject <UIActionSheetDelegate>
@end

@implementation UIKitMenuSheet {
	NSArray<UIMenuElement *> *_rows;
	__weak UIView *_source;
	id _sender;
	UIKitMenuSheet *_selfWhileShown;
}

static void UIKitCollectMenuRows(UIMenu *menu, NSMutableArray *rows)
{
	for (UIMenuElement *element in [menu children]) {
		if ([element isKindOfClass:[UIDeferredMenuElement class]]) {
			UIMenu *provided = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline
			                                children:[(UIDeferredMenuElement *)element uikitElements]];
			UIKitCollectMenuRows(provided, rows);
		} else if ([element isKindOfClass:[UIMenu class]] && ([(UIMenu *)element options] & UIMenuOptionsDisplayInline)) {
			UIKitCollectMenuRows((UIMenu *)element, rows);
		} else if ([element respondsToSelector:@selector(attributes)]
		           && ([(UIAction *)element attributes] & UIMenuElementAttributesHidden)) {
			continue;
		} else {
			[rows addObject:element];
		}
	}
}

- (void)showMenu:(UIMenu *)menu from:(UIView *)source sender:(id)sender
{
	NSMutableArray<UIMenuElement *> *rows = [NSMutableArray array];
	UIKitCollectMenuRows(menu, rows);
	_rows = rows;
	_source = source;
	_sender = sender;
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[[menu title] length] > 0 ? [menu title] : nil
	                                                   delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
	for (UIMenuElement *row in rows) {
		NSString *title = [row title] ?: @"";
		if ([row isKindOfClass:[UIMenu class]])
			title = [title stringByAppendingString:@" ›"];
		else if ([row respondsToSelector:@selector(state)] && [(UIAction *)row state] == UIMenuElementStateOn)
			title = [@"✓ " stringByAppendingString:title];
		NSInteger index = [sheet addButtonWithTitle:title];
		if ([row respondsToSelector:@selector(attributes)]) {
			UIMenuElementAttributes attributes = [(UIAction *)row attributes];
			if ((attributes & UIMenuElementAttributesDestructive) && [sheet destructiveButtonIndex] < 0)
				[sheet setDestructiveButtonIndex:index];
			if (attributes & UIMenuElementAttributesDisabled)
				[sheet uikitSetButtonAtIndex:index enabled:NO];
		}
	}
	[sheet setCancelButtonIndex:[sheet addButtonWithTitle:@"Cancel"]];
	_selfWhileShown = self;
	[sheet showInView:source];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)index
{
	UIMenuElement *row = index >= 0 && index < (NSInteger)[_rows count] ? [_rows objectAtIndex:index] : nil;
	if ([row isKindOfClass:[UIMenu class]])
		[[[UIKitMenuSheet alloc] init] showMenu:(UIMenu *)row from:_source sender:_sender];
	else if ([row isKindOfClass:[UIAction class]])
		[(UIAction *)row uikitPerformWithSender:_sender];
	else if ([row isKindOfClass:[UICommand class]] && [(UICommand *)row action] != NULL)
		UIKitSendUpChain([(UICommand *)row action], row, UIKitResponderChain(), 0);
	dispatch_async(dispatch_get_main_queue(), ^{
		self->_selfWhileShown = nil;
	});
}

@end

static void UIKitShowMenuFrom(UIMenu *menu, UIView *source, id sender)
{
	if (menu == nil)
		return;
	[[[UIKitMenuSheet alloc] init] showMenu:menu from:source sender:sender];
}

void UIKitShowMenu(UIMenu *menu, UIView *source)
{
	UIKitShowMenuFrom(menu, source, source);
}

#pragma mark - Interactions

static char UIKitInteractionsKey;

@implementation UIView (UIInteractions)

- (NSArray<id<UIInteraction>> *)interactions
{
	return [objc_getAssociatedObject(self, &UIKitInteractionsKey) copy] ?: @[];
}

- (void)setInteractions:(NSArray<id<UIInteraction>> *)interactions
{
	for (id<UIInteraction> interaction in [self interactions])
		[self removeInteraction:interaction];
	for (id<UIInteraction> interaction in interactions)
		[self addInteraction:interaction];
}

- (void)addInteraction:(id<UIInteraction>)interaction
{
	if (interaction == nil)
		return;
	NSMutableArray *interactions = objc_getAssociatedObject(self, &UIKitInteractionsKey);
	if (interactions == nil) {
		interactions = [NSMutableArray array];
		objc_setAssociatedObject(self, &UIKitInteractionsKey, interactions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	if ([interactions containsObject:interaction])
		return;
	[[interaction view] removeInteraction:interaction];
	[interaction willMoveToView:self];
	[interactions addObject:interaction];
	[interaction didMoveToView:self];
}

- (void)removeInteraction:(id<UIInteraction>)interaction
{
	NSMutableArray *interactions = objc_getAssociatedObject(self, &UIKitInteractionsKey);
	if (![interactions containsObject:interaction])
		return;
	[interaction willMoveToView:nil];
	[interactions removeObject:interaction];
	[interaction didMoveToView:nil];
}

@end

@implementation UIContextMenuConfiguration {
	id<NSCopying> _identifier;
	UIContextMenuActionProvider _actionProvider;
}

+ (instancetype)configurationWithIdentifier:(id<NSCopying>)identifier previewProvider:(UIContextMenuContentPreviewProvider)previewProvider actionProvider:(UIContextMenuActionProvider)actionProvider
{
	UIContextMenuConfiguration *configuration = [[self alloc] init];
	configuration->_identifier = identifier ?: (id<NSCopying>)[[NSUUID UUID] UUIDString];
	configuration->_actionProvider = [actionProvider copy];
	return configuration;
}

- (id<NSCopying>)identifier { return _identifier; }

- (UIMenu *)uikitMenu
{
	return _actionProvider != nil ? _actionProvider(@[]) : nil;
}

@end

@implementation UIContextMenuInteraction {
	__weak id<UIContextMenuInteractionDelegate> _delegate;
	__weak UIView *_view;
	UILongPressGestureRecognizer *_press;
	CGPoint _location;
	UIContextMenuConfiguration *_shown;
}

- (instancetype)initWithDelegate:(id<UIContextMenuInteractionDelegate>)delegate
{
	if ((self = [super init]))
		_delegate = delegate;
	return self;
}

- (id<UIContextMenuInteractionDelegate>)delegate { return _delegate; }
- (UIView *)view { return _view; }

- (void)willMoveToView:(UIView *)view
{
	if (_press != nil)
		[_view removeGestureRecognizer:_press];
	_press = nil;
}

- (void)didMoveToView:(UIView *)view
{
	_view = view;
	if (view == nil)
		return;
	_press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pressed:)];
	[view addGestureRecognizer:_press];
}

- (CGPoint)locationInView:(UIView *)view
{
	if (view == nil || view == _view)
		return _location;
	NSPoint point = [view convertPoint:NSMakePoint(_location.x, _location.y) fromView:_view];
	return CGPointMake(point.x, point.y);
}

- (void)pressed:(UILongPressGestureRecognizer *)press
{
	if ([press state] != UIGestureRecognizerStateBegan)
		return;
	_location = [press locationInView:_view];
	id<UIContextMenuInteractionDelegate> delegate = _delegate;
	UIContextMenuConfiguration *configuration = [delegate contextMenuInteraction:self configurationForMenuAtLocation:_location];
	UIMenu *menu = [configuration uikitMenu];
	if ([[menu children] count] == 0)
		return;
	_shown = configuration;
	if ([delegate respondsToSelector:@selector(contextMenuInteraction:willDisplayMenuForConfiguration:animator:)])
		[delegate contextMenuInteraction:self willDisplayMenuForConfiguration:configuration animator:nil];
	UIKitShowMenuFrom(menu, _view, _view);
}

- (void)dismissMenu
{
	_shown = nil;
}

@end

#pragma mark - Controls

/* A UIAction added to a control: its target, kept by the control. */
@interface UIKitActionTarget : NSObject {
@public
	UIAction *action;
	UIControlEvents events;
}
- (void)uikitFire:(id)sender;
@end

@implementation UIKitActionTarget
- (void)uikitFire:(id)sender { [action uikitPerformWithSender:sender]; }
@end

static char UIKitActionTargetsKey, UIKitShowsMenuKey, UIKitContextMenuEnabledKey, UIKitMenuKey, UIKitMenuPressKey, UIKitSelectionKey;

static NSMutableArray<UIKitActionTarget *> *UIKitActionTargets(UIControl *control)
{
	NSMutableArray *targets = objc_getAssociatedObject(control, &UIKitActionTargetsKey);
	if (targets == nil) {
		targets = [NSMutableArray array];
		objc_setAssociatedObject(control, &UIKitActionTargetsKey, targets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return targets;
}

@implementation UIControl (UIActions)

- (instancetype)initWithFrame:(CGRect)frame primaryAction:(UIAction *)primaryAction
{
	if ((self = [self initWithFrame:frame]) && primaryAction != nil)
		[self addAction:primaryAction forControlEvents:[self isKindOfClass:[UIButton class]] ? UIControlEventTouchUpInside : UIControlEventValueChanged];
	return self;
}

- (void)addAction:(UIAction *)action forControlEvents:(UIControlEvents)events
{
	if (action == nil)
		return;
	for (UIKitActionTarget *target in UIKitActionTargets(self))
		if ([target->action isEqual:action] || [[target->action identifier] isEqualToString:[action identifier]]) {
			target->action = action;
			target->events |= events;
			[self addTarget:target action:@selector(uikitFire:) forControlEvents:events];
			return;
		}
	UIKitActionTarget *target = [[UIKitActionTarget alloc] init];
	target->action = action;
	target->events = events;
	[UIKitActionTargets(self) addObject:target];
	[self addTarget:target action:@selector(uikitFire:) forControlEvents:events];
}

- (void)uikitRemoveActionsMatching:(BOOL (^)(UIAction *action))matches forControlEvents:(UIControlEvents)events
{
	NSMutableArray *targets = UIKitActionTargets(self);
	for (UIKitActionTarget *target in [targets copy]) {
		if (!matches(target->action))
			continue;
		[self removeTarget:target action:@selector(uikitFire:) forControlEvents:events];
		target->events &= ~events;
		if (target->events == 0)
			[targets removeObject:target];
	}
}

- (void)removeAction:(UIAction *)action forControlEvents:(UIControlEvents)events
{
	[self uikitRemoveActionsMatching:^BOOL(UIAction *candidate) {
		return candidate == action || [[candidate identifier] isEqualToString:[action identifier]];
	} forControlEvents:events];
}

- (void)removeActionForIdentifier:(UIActionIdentifier)identifier forControlEvents:(UIControlEvents)events
{
	[self uikitRemoveActionsMatching:^BOOL(UIAction *candidate) {
		return [[candidate identifier] isEqualToString:identifier];
	} forControlEvents:events];
}

- (void)enumerateEventHandlers:(void (^)(UIAction *actionHandler, id target, SEL action, UIControlEvents controlEvents, BOOL *stop))iterator
{
	if (iterator == nil)
		return;
	BOOL stop = NO;
	for (id target in [self allTargets]) {
		if ([target isKindOfClass:[UIKitActionTarget class]]) {
			UIKitActionTarget *entry = target;
			iterator(entry->action, nil, NULL, entry->events, &stop);
		} else {
			for (NSUInteger bit = 0; bit < 32 && !stop; bit++)
				for (NSString *action in [self actionsForTarget:target forControlEvent:(UIControlEvents)1 << bit])
					if (!stop)
						iterator(nil, target, NSSelectorFromString(action), (UIControlEvents)1 << bit, &stop);
		}
		if (stop)
			return;
	}
}

- (BOOL)showsMenuAsPrimaryAction { return [objc_getAssociatedObject(self, &UIKitShowsMenuKey) boolValue]; }
- (void)setShowsMenuAsPrimaryAction:(BOOL)shows { objc_setAssociatedObject(self, &UIKitShowsMenuKey, @(shows), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

- (BOOL)isContextMenuInteractionEnabled
{
	NSNumber *enabled = objc_getAssociatedObject(self, &UIKitContextMenuEnabledKey);
	return enabled != nil ? [enabled boolValue] : [self respondsToSelector:@selector(menu)] && [(UIButton *)self menu] != nil;
}

- (void)setContextMenuInteractionEnabled:(BOOL)enabled
{
	objc_setAssociatedObject(self, &UIKitContextMenuEnabledKey, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

/* A button's menu: tapped when it is the primary action, else pressed. */
@interface UIKitButtonMenuTrigger : NSObject
@end

@implementation UIKitButtonMenuTrigger

- (void)tapped:(UIButton *)button
{
	if ([button showsMenuAsPrimaryAction])
		UIKitShowMenuFrom([button menu], button, button);
}

- (void)pressed:(UILongPressGestureRecognizer *)press
{
	UIButton *button = (UIButton *)[press view];
	if ([press state] == UIGestureRecognizerStateBegan && ![button showsMenuAsPrimaryAction] && [button isContextMenuInteractionEnabled])
		UIKitShowMenuFrom([button menu], button, button);
}

@end

@implementation UIButton (UIMenus)

+ (instancetype)buttonWithType:(UIButtonType)buttonType primaryAction:(UIAction *)primaryAction
{
	UIButton *button = [self buttonWithType:buttonType];
	if (primaryAction != nil) {
		if ([[primaryAction title] length] > 0)
			[button setTitle:[primaryAction title] forState:UIControlStateNormal];
		if ([primaryAction image] != nil)
			[button setImage:[primaryAction image] forState:UIControlStateNormal];
		[button addAction:primaryAction forControlEvents:UIControlEventTouchUpInside];
	}
	return button;
}

+ (instancetype)systemButtonWithPrimaryAction:(UIAction *)primaryAction
{
	return [self buttonWithType:UIButtonTypeSystem primaryAction:primaryAction];
}

- (UIMenu *)menu
{
	return objc_getAssociatedObject(self, &UIKitMenuKey);
}

- (void)setMenu:(UIMenu *)menu
{
	objc_setAssociatedObject(self, &UIKitMenuKey, menu, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	if (menu == nil || objc_getAssociatedObject(self, &UIKitMenuPressKey) != nil)
		return;
	UIKitButtonMenuTrigger *trigger = [[UIKitButtonMenuTrigger alloc] init];
	objc_setAssociatedObject(self, &UIKitMenuPressKey, trigger, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self addTarget:trigger action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
	UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:trigger action:@selector(pressed:)];
	[self addGestureRecognizer:press];
}

- (BOOL)changesSelectionAsPrimaryAction { return [objc_getAssociatedObject(self, &UIKitSelectionKey) boolValue]; }

- (void)setChangesSelectionAsPrimaryAction:(BOOL)changes
{
	objc_setAssociatedObject(self, &UIKitSelectionKey, @(changes), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	if (changes)
		[self addTarget:self action:@selector(uikitToggleSelected) forControlEvents:UIControlEventTouchUpInside];
	else
		[self removeTarget:self action:@selector(uikitToggleSelected) forControlEvents:UIControlEventTouchUpInside];
}

- (void)uikitToggleSelected
{
	[self setSelected:![self isSelected]];
}

@end

#pragma mark - Bar button items

static char UIKitPrimaryActionKey, UIKitBarMenuKey;

@implementation UIBarButtonItem (UIMenus)

- (instancetype)initWithPrimaryAction:(UIAction *)primaryAction
{
	return [self initWithTitle:[primaryAction title] image:[primaryAction image] primaryAction:primaryAction menu:nil];
}

- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem primaryAction:(UIAction *)primaryAction
{
	if ((self = [self initWithBarButtonSystemItem:systemItem target:nil action:NULL]))
		[self setPrimaryAction:primaryAction];
	return self;
}

- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem menu:(UIMenu *)menu
{
	if ((self = [self initWithBarButtonSystemItem:systemItem target:nil action:NULL]))
		[self setMenu:menu];
	return self;
}

- (instancetype)initWithTitle:(NSString *)title menu:(UIMenu *)menu
{
	return [self initWithTitle:title image:nil primaryAction:nil menu:menu];
}

- (instancetype)initWithImage:(UIImage *)image menu:(UIMenu *)menu
{
	return [self initWithTitle:nil image:image primaryAction:nil menu:menu];
}

- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image primaryAction:(UIAction *)primaryAction menu:(UIMenu *)menu
{
	if (image != nil && [title length] == 0)
		self = [self initWithImage:image style:UIBarButtonItemStylePlain target:nil action:NULL];
	else
		self = [self initWithTitle:title style:UIBarButtonItemStylePlain target:nil action:NULL];
	if (self != nil) {
		[self setPrimaryAction:primaryAction];
		[self setMenu:menu];
	}
	return self;
}

- (UIAction *)primaryAction { return objc_getAssociatedObject(self, &UIKitPrimaryActionKey); }
- (void)setPrimaryAction:(UIAction *)action { objc_setAssociatedObject(self, &UIKitPrimaryActionKey, action, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UIMenu *)menu { return objc_getAssociatedObject(self, &UIKitBarMenuKey); }
- (void)setMenu:(UIMenu *)menu { objc_setAssociatedObject(self, &UIKitBarMenuKey, menu, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

/* A tap runs the primary action, or shows the menu when there is none
   and no target-action. */
- (BOOL)uikitPerformMenuOrPrimaryAction
{
	UIAction *primary = [self primaryAction];
	if (primary != nil) {
		[primary uikitPerformWithSender:self];
		return YES;
	}
	if ([self menu] != nil && [self action] == NULL) {
		UIKitShowMenuFrom([self menu], nil, self);
		return YES;
	}
	return NO;
}

@end
