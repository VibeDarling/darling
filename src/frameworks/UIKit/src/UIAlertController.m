/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIAlertController.h>
#import <Foundation/NSException.h>

@implementation UIAlertAction

// Rung 3 (init(title:style:handler:) page): returns a new action with the given title, style and
// handler. Rung 6: a nil title and a nil handler are accepted and the title is copied.
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style
                        handler:(void (^)(UIAlertAction *))handler
{
	UIAlertAction *action = [[self alloc] init];
	action->_uiTitle = [title copy];
	action->_uiStyle = style;
	action->_uiHandler = [handler copy];
	return action;
}

- (NSString *)title { return _uiTitle; }
- (UIAlertActionStyle)style { return _uiStyle; }

@end

@implementation UIAlertController

// Rung 3 (init(title:message:preferredstyle:) page): returns a controller with the given title,
// message and style. Rung 6: nil title or message is accepted.
+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message
                          preferredStyle:(UIAlertControllerStyle)preferredStyle
{
	UIAlertController *controller = [[self alloc] init];
	[controller setTitle:title];
	controller->_uiMessage = [message copy];
	controller->_uiPreferredStyle = preferredStyle;
	return controller;
}

// Rung 6: a plain alloc/init is legal and has no title or message, so the action list must
// exist for it too; preferredStyle is then the zero value.
- (instancetype)init
{
	self = [super init];
	if (self != nil)
		_uiActions = [[NSMutableArray alloc] init];
	return self;
}

- (NSString *)message { return _uiMessage; }
- (void)setMessage:(NSString *)message { _uiMessage = [message copy]; }
- (UIAlertControllerStyle)preferredStyle { return _uiPreferredStyle; }

// Rung 3 (addaction and actions pages): actions keep the order in which they were added.
// Rung 6: nil raises NSInvalidArgumentException, and actions is a copy.
- (void)addAction:(UIAlertAction *)action
{
	if (action == nil)
		[NSException raise:NSInvalidArgumentException format:@"UIAlertController addAction: action must not be nil"];
	[_uiActions addObject:action];
}

- (NSArray *)actions { return [_uiActions copy]; }

@end
