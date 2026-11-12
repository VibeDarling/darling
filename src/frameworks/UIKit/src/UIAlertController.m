/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIAlertController.h>
#import <UIKit/UIAlertView.h>
#import <UIKit/UITextField.h>
#import <UIKit/UIFont.h>
#import "UIKitPrivate.h"

@class UIAlertController;

@interface UIAlertAction ()
@property (nonatomic, weak) UIAlertController *uikitController;
- (void)uikitPerform;
@end

@interface UIAlertController () <UIAlertViewDelegate, UIActionSheetDelegate>
- (void)uikitActionEnabledChanged:(UIAlertAction *)action;
@end

@implementation UIAlertAction {
	NSString *_title;
	UIAlertActionStyle _style;
	void (^_handler)(UIAlertAction *);
	BOOL _enabled;
}

+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler
{
	UIAlertAction *action = [[self alloc] init];
	action->_title = [title copy];
	action->_style = style;
	action->_handler = [handler copy];
	return action;
}

- (instancetype)init
{
	if ((self = [super init]))
		_enabled = YES;
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	UIAlertAction *copy = [[self class] actionWithTitle:_title style:_style handler:_handler];
	copy->_enabled = _enabled;
	return copy;
}

- (NSString *)title { return _title; }
- (UIAlertActionStyle)style { return _style; }
- (BOOL)isEnabled { return _enabled; }

- (void)setEnabled:(BOOL)enabled
{
	_enabled = enabled;
	[_uikitController uikitActionEnabledChanged:self];
}

- (void)uikitPerform
{
	if (_handler != nil)
		_handler(self);
}

@end

@implementation UIAlertController {
	NSString *_message;
	UIAlertControllerStyle _preferredStyle;
	NSMutableArray<UIAlertAction *> *_actions;
	NSMutableArray<UITextField *> *_textFields;
	UIAlertAction *_preferredAction;
	/* What shows it, and which of its buttons is which action. */
	UIView *_shown;
	NSMutableArray<UIAlertAction *> *_buttonActions;
	UIAlertAction *_chosen;
	BOOL _hiding;
}

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle
{
	UIAlertController *controller = [[self alloc] initWithNibName:nil bundle:nil];
	[controller setTitle:title];
	controller->_message = [message copy];
	controller->_preferredStyle = preferredStyle;
	return controller;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
	if ((self = [super initWithNibName:nibName bundle:bundle])) {
		_actions = [NSMutableArray array];
		_textFields = [NSMutableArray array];
		_preferredStyle = UIAlertControllerStyleAlert;
	}
	return self;
}

- (NSString *)message { return _message; }
- (void)setMessage:(NSString *)message { _message = [message copy]; }
- (UIAlertControllerStyle)preferredStyle { return _preferredStyle; }
- (NSArray *)actions { return [_actions copy]; }
- (NSArray *)textFields { return [_textFields count] > 0 ? [_textFields copy] : nil; }
- (UIAlertAction *)preferredAction { return _preferredAction; }

- (void)setPreferredAction:(UIAlertAction *)action
{
	if (action != nil && ![_actions containsObject:action])
		[NSException raise:NSInvalidArgumentException format:@"The preferred action must be one of the alert's actions"];
	_preferredAction = action;
}

- (void)addAction:(UIAlertAction *)action
{
	if (action == nil)
		return;
	if ([action style] == UIAlertActionStyleCancel)
		for (UIAlertAction *other in _actions)
			if ([other style] == UIAlertActionStyleCancel)
				[NSException raise:NSInternalInconsistencyException format:@"UIAlertController can only have one action with a style of UIAlertActionStyleCancel"];
	[action setUikitController:self];
	[_actions addObject:action];
}

- (void)addTextFieldWithConfigurationHandler:(void (^)(UITextField *textField))configurationHandler
{
	if (_preferredStyle != UIAlertControllerStyleAlert)
		[NSException raise:NSInternalInconsistencyException format:@"Text fields can only be added to an alert controller of style UIAlertControllerStyleAlert"];
	UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
	[field setBorderStyle:UITextBorderStyleRoundedRect];
	[field setFont:[UIFont systemFontOfSize:14]];
	[_textFields addObject:field];
	if (configurationHandler != nil)
		configurationHandler(field);
}

#pragma mark Presentation

- (BOOL)uikitPresentsItself { return YES; }

/* The cancel action first, as UIAlertView puts its cancel button: on the
 * left of two, at the bottom of more. */
- (void)uikitShowPresented
{
	_chosen = nil;
	_hiding = NO;
	_buttonActions = [NSMutableArray array];
	UIAlertAction *cancel = nil;
	for (UIAlertAction *action in _actions)
		if ([action style] == UIAlertActionStyleCancel)
			cancel = action;

	if (_preferredStyle == UIAlertControllerStyleAlert) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[self title] message:_message delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
		if (cancel != nil) {
			[alert setCancelButtonIndex:[alert addButtonWithTitle:[cancel title]]];
			[_buttonActions addObject:cancel];
		}
		for (UIAlertAction *action in _actions) {
			if (action == cancel)
				continue;
			NSInteger index = [alert addButtonWithTitle:[action title]];
			[_buttonActions addObject:action];
			if ([action style] == UIAlertActionStyleDestructive)
				[alert uikitSetDestructiveButtonIndex:index];
		}
		if (_preferredAction != nil)
			[alert uikitSetPreferredButtonIndex:[_buttonActions indexOfObject:_preferredAction]];
		[alert uikitSetTextFields:_textFields];
		_shown = alert;
	} else {
		NSString *title = [self title];
		if ([_message length] > 0)
			title = [title length] > 0 ? [NSString stringWithFormat:@"%@\n%@", title, _message] : _message;
		UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		for (UIAlertAction *action in _actions) {
			if (action == cancel)
				continue;
			NSInteger index = [sheet addButtonWithTitle:[action title]];
			[_buttonActions addObject:action];
			if ([action style] == UIAlertActionStyleDestructive)
				[sheet setDestructiveButtonIndex:index];
		}
		if (cancel != nil) {
			[sheet setCancelButtonIndex:[sheet addButtonWithTitle:[cancel title]]];
			[_buttonActions addObject:cancel];
		}
		_shown = sheet;
	}
	for (NSUInteger i = 0; i < [_buttonActions count]; i++)
		if (![[_buttonActions objectAtIndex:i] isEnabled])
			[(id)_shown uikitSetButtonAtIndex:i enabled:NO];

	[self uikitAppear:NO];
	if ([_shown isKindOfClass:[UIAlertView class]])
		[(UIAlertView *)_shown show];
	else
		[(UIActionSheet *)_shown showInView:nil];
}

/* Dismissed by the app, not by a button. */
- (void)uikitHidePresented
{
	if (_shown == nil)
		return;
	_hiding = YES;
	UIView *shown = _shown;
	_shown = nil;
	[(id)shown dismissWithClickedButtonIndex:-1 animated:NO];
	[self uikitDisappear:NO];
}

- (void)uikitActionEnabledChanged:(UIAlertAction *)action
{
	NSUInteger index = [_buttonActions indexOfObject:action];
	if (_shown != nil && index != NSNotFound)
		[(id)_shown uikitSetButtonAtIndex:index enabled:[action isEnabled]];
}

- (void)uikitChoseButton:(NSInteger)index
{
	if (index >= 0 && index < (NSInteger)[_buttonActions count])
		_chosen = [_buttonActions objectAtIndex:index];
}

/* The handler runs once the alert is gone, as on iOS. */
- (void)uikitButtonDismissed
{
	if (_hiding)
		return;
	_shown = nil;
	[self uikitDisappear:NO];
	UIAlertAction *chosen = _chosen;
	_chosen = nil;
	[self dismissViewControllerAnimated:YES completion:^{
		[chosen uikitPerform];
	}];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex { [self uikitChoseButton:buttonIndex]; }
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex { [self uikitButtonDismissed]; }
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex { [self uikitChoseButton:buttonIndex]; }
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex { [self uikitButtonDismissed]; }

@end
