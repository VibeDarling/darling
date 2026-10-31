/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef PREFERENCES_PSVIEWCONTROLLER_H
#define PREFERENCES_PSVIEWCONTROLLER_H

#import <UIKit/UIKit.h>

@class PSSpecifier, PSRootController;

/* What a settings page's controllers share: the specifier that opened the page. */
@protocol PSController <NSObject>
- (void)setParentController:(id)controller;
- (id)parentController;
- (void)setRootController:(id)controller;
- (id)rootController;
- (void)setSpecifier:(PSSpecifier *)specifier;
- (PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
@end

@interface PSViewController : UIViewController <PSController> {
@protected
	__weak UIViewController *_parentController;
	__weak PSRootController *_rootController;
	PSSpecifier *_specifier;
}
@property (nonatomic, weak) UIViewController *parentController;
@property (nonatomic, weak) PSRootController *rootController;
@property (nonatomic, strong) PSSpecifier *specifier;
- (void)pushController:(UIViewController *)controller;
- (void)pushController:(UIViewController *)controller animate:(BOOL)animate;
- (void)showController:(UIViewController *)controller;
- (void)showController:(UIViewController *)controller animate:(BOOL)animate;
- (void)suspend;
- (void)didLock;
- (void)willResignActive;
- (void)willBecomeActive;
- (void)didWake;
- (void)handleURL:(NSDictionary *)url;
@end

/* The navigation controller a settings app's pages live in. */
@interface PSRootController : UINavigationController
- (instancetype)initWithTitle:(NSString *)title identifier:(NSString *)identifier;
@property (nonatomic, strong) PSSpecifier *specifier;
+ (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
+ (id)readPreferenceValue:(PSSpecifier *)specifier;
+ (void)writePreference:(PSSpecifier *)specifier;
@end

#endif /* PREFERENCES_PSVIEWCONTROLLER_H */
