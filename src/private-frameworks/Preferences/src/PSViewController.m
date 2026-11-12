/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <Preferences/PSViewController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSConstants.h>
#import <CoreFoundation/CoreFoundation.h>
#include <notify.h>

@implementation PSViewController

@synthesize parentController = _parentController, rootController = _rootController, specifier = _specifier;

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
	[PSRootController setPreferenceValue:value specifier:specifier];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier
{
	return [PSRootController readPreferenceValue:specifier];
}

- (void)pushController:(UIViewController *)controller
{
	[self pushController:controller animate:YES];
}

- (void)pushController:(UIViewController *)controller animate:(BOOL)animate
{
	if (!controller)
		return;
	if ([controller respondsToSelector:@selector(setParentController:)])
		[(id) controller setParentController:self];
	if ([controller respondsToSelector:@selector(setRootController:)])
		[(id) controller setRootController:self.rootController];
	UINavigationController *navigation = self.navigationController ?: (UINavigationController *) self.rootController;
	[navigation pushViewController:controller animated:animate];
}

- (void)showController:(UIViewController *)controller
{
	[self pushController:controller animate:YES];
}

- (void)showController:(UIViewController *)controller animate:(BOOL)animate
{
	[self pushController:controller animate:animate];
}

- (PSRootController *)rootController
{
	PSRootController *root = _rootController;
	if (!root && [self.navigationController isKindOfClass:[PSRootController class]])
		root = (PSRootController *) self.navigationController;
	return root;
}

- (void)suspend {}
- (void)didLock {}
- (void)willResignActive {}
- (void)willBecomeActive {}
- (void)didWake {}
- (void)handleURL:(NSDictionary *)url {}

@end

@implementation PSRootController

- (instancetype)initWithTitle:(NSString *)title identifier:(NSString *)identifier
{
	if ((self = [self initWithNibName:nil bundle:nil])) {
		self.title = title;
		_specifier = [PSSpecifier preferenceSpecifierNamed:title target:nil set:NULL get:NULL detail:Nil cell:PSLinkCell edit:Nil];
		_specifier.identifier = identifier;
	}
	return self;
}

/* A setting lives under its key in the preferences of the domain named by "defaults". */
+ (id)readPreferenceValue:(PSSpecifier *)specifier
{
	NSString *key = [specifier propertyForKey:PSKeyNameKey];
	NSString *domain = [specifier propertyForKey:PSDefaultsKey];
	id value = nil;
	if (key && domain)
		value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef) key, (__bridge CFStringRef) domain));
	else if (key)
		value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
	return value ?: [specifier propertyForKey:PSDefaultValueKey];
}

+ (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
	NSString *key = [specifier propertyForKey:PSKeyNameKey];
	NSString *domain = [specifier propertyForKey:PSDefaultsKey];
	if (key && domain) {
		CFPreferencesSetAppValue((__bridge CFStringRef) key, (__bridge CFPropertyListRef) value, (__bridge CFStringRef) domain);
		CFPreferencesAppSynchronize((__bridge CFStringRef) domain);
	} else if (key) {
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	NSString *notification = [specifier propertyForKey:PSValueChangedNotificationKey];
	if (notification.length) {
		// Observers in this process (CoreFoundation's Darwin center is per process
		// here) and in others (notifyd).
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef) notification, NULL, NULL, true);
		notify_post(notification.UTF8String);
	}
}

+ (void)writePreference:(PSSpecifier *)specifier
{
	NSString *domain = [specifier propertyForKey:PSDefaultsKey];
	if (domain)
		CFPreferencesAppSynchronize((__bridge CFStringRef) domain);
}

@end
