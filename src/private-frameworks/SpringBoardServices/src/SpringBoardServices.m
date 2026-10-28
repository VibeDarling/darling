/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <SpringBoardServices/SpringBoardServices.h>
#import <FrontBoardServices/FrontBoardServices.h>
#import <Foundation/Foundation.h>
#include <servers/bootstrap.h>
#include <dispatch/dispatch.h>
#include <limits.h>
#include <string.h>

static NSBundle *SBSBundleForIdentifier(NSString *identifier)
{
	if (identifier == nil)
		return nil;
	for (NSBundle *bundle in FBSInstalledApplications())
		if ([[bundle bundleIdentifier] isEqualToString:identifier])
			return bundle;
	NSBundle *system = [NSBundle bundleWithPath:FBSSystemApplicationPath];
	if ([[system bundleIdentifier] isEqualToString:identifier])
		return system;
	return nil;
}

mach_port_t SBSSpringBoardServerPort(void)
{
	mach_port_t port = MACH_PORT_NULL;
	if (bootstrap_look_up(bootstrap_port, "com.apple.springboard.services", &port) != KERN_SUCCESS)
		return MACH_PORT_NULL;
	return port;
}

NSArray *SBSCopyApplicationDisplayIdentifiers(bool onlyActive, bool debuggable)
{
	(void)debuggable;
	NSMutableArray *identifiers = [[NSMutableArray alloc] init];
	/* Darling does not track which apps are running here. */
	if (onlyActive)
		return identifiers;
	@autoreleasepool {
		for (NSBundle *bundle in FBSInstalledApplications())
			[identifiers addObject:[bundle bundleIdentifier]];
	}
	return identifiers;
}

NSString *SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier)
{
	NSString *name = nil;
	@autoreleasepool {
		NSBundle *bundle = SBSBundleForIdentifier(identifier);
		name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
		if (name == nil)
			name = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
		if (name == nil)
			name = [[[bundle bundlePath] lastPathComponent] stringByDeletingPathExtension];
		[name retain];
	}
	return name;
}

/* The largest icon the bundle names, as SpringBoard-lite picks it. */
static NSString *SBSIconPath(NSBundle *bundle)
{
	NSMutableArray *names = [NSMutableArray array];
	NSDictionary *icons = [bundle objectForInfoDictionaryKey:@"CFBundleIcons"];
	NSArray *files = [[icons objectForKey:@"CFBundlePrimaryIcon"] objectForKey:@"CFBundleIconFiles"];
	if ([files isKindOfClass:[NSArray class]])
		[names addObjectsFromArray:files];
	files = [bundle objectForInfoDictionaryKey:@"CFBundleIconFiles"];
	if ([files isKindOfClass:[NSArray class]])
		[names addObjectsFromArray:files];
	NSString *single = [bundle objectForInfoDictionaryKey:@"CFBundleIconFile"];
	if ([single isKindOfClass:[NSString class]])
		[names addObject:single];
	[names addObject:@"Icon"];
	[names addObject:@"icon"];

	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *root = [bundle bundlePath];
	for (NSString *name in [names reverseObjectEnumerator]) {
		NSString *base = [[name pathExtension] length] ? [name stringByDeletingPathExtension] : name;
		for (NSString *suffix in @[ @"@3x.png", @"@2x.png", @".png", @"" ]) {
			NSString *path = [root stringByAppendingPathComponent:[base stringByAppendingString:suffix]];
			if ([suffix length] == 0)
				path = [root stringByAppendingPathComponent:name];
			BOOL directory = NO;
			if ([fm fileExistsAtPath:path isDirectory:&directory] && !directory)
				return path;
		}
	}
	return nil;
}

NSString *SBSCopyIconImagePathForDisplayIdentifier(NSString *identifier)
{
	NSString *path = nil;
	@autoreleasepool {
		path = [SBSIconPath(SBSBundleForIdentifier(identifier)) retain];
	}
	return path;
}

NSData *SBSCopyIconImagePNGDataForDisplayIdentifier(NSString *identifier)
{
	NSData *data = nil;
	@autoreleasepool {
		NSString *path = SBSIconPath(SBSBundleForIdentifier(identifier));
		if (path != nil)
			data = [[NSData alloc] initWithContentsOfFile:path];
	}
	return data;
}

NSString *SBSCopyBundlePathForDisplayIdentifier(NSString *identifier)
{
	NSString *path = nil;
	@autoreleasepool {
		path = [[SBSBundleForIdentifier(identifier) bundlePath] retain];
	}
	return path;
}

NSString *SBSCopyExecutablePathForDisplayIdentifier(NSString *identifier)
{
	NSString *path = nil;
	@autoreleasepool {
		path = [[SBSBundleForIdentifier(identifier) executablePath] retain];
	}
	return path;
}

NSString *SBSCopyFrontmostApplicationDisplayIdentifier(void)
{
	return nil;
}

int SBBundlePathForDisplayIdentifier(mach_port_t port, const char *identifier, char *path)
{
	(void)port;
	if (identifier == NULL || path == NULL)
		return 1;
	int result = 1;
	@autoreleasepool {
		NSString *bundlePath = [SBSBundleForIdentifier([NSString stringWithUTF8String:identifier]) bundlePath];
		if (bundlePath != nil && [bundlePath getFileSystemRepresentation:path maxLength:PATH_MAX])
			result = 0;
	}
	return result;
}

int SBSLaunchApplicationWithIdentifierAndLaunchOptions(CFStringRef identifier, CFDictionaryRef options, Boolean suspended)
{
	if (identifier == NULL)
		return 1;
	__block int result = 0;
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	@autoreleasepool {
		NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)options ?: @{}];
		if (suspended)
			[dictionary setObject:@YES forKey:FBSOpenApplicationOptionKeyActivateSuspended];
		[[FBSSystemService sharedService] openApplication:(NSString *)identifier
		                                         options:[FBSOpenApplicationOptions optionsWithDictionary:dictionary]
		                                      withResult:^(NSError *error) {
			result = error != nil ? (int)[error code] ?: 1 : 0;
			dispatch_semaphore_signal(done);
		}];
	}
	dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
	dispatch_release(done);
	return result;
}

int SBSLaunchApplicationWithIdentifier(CFStringRef identifier, Boolean suspended)
{
	return SBSLaunchApplicationWithIdentifierAndLaunchOptions(identifier, NULL, suspended);
}

bool SBSOpenSensitiveURLAndUnlock(CFURLRef url, bool unlock)
{
	(void)unlock;
	if (url == NULL)
		return false;
	__block bool opened = false;
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	[[FBSSystemService sharedService] openURL:(NSURL *)url application:nil options:nil clientPort:MACH_PORT_NULL withResult:^(NSError *error) {
		opened = error == nil;
		dispatch_semaphore_signal(done);
	}];
	dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
	dispatch_release(done);
	return opened;
}

void SBSSetInterceptsMenuButtonForever(bool intercepts)
{
	(void)intercepts;
}

void SBSSuspendFrontmostApplication(void)
{
}

int SBReboot(mach_port_t port)
{
	(void)port;
	return 1;
}

int SBShutDown(mach_port_t port)
{
	(void)port;
	return 1;
}
