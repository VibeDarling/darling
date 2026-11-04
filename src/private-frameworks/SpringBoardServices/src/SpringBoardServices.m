/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <SpringBoardServices/SpringBoardServices.h>
#import <DarlingBoard/DarlingBoard.h>
#import <Foundation/Foundation.h>
#include <limits.h>
#include <string.h>

static NSBundle *SBSBundleForIdentifier(NSString *identifier)
{
	if (identifier == nil)
		return nil;
	for (NSBundle *bundle in DBInstalledApplications())
		if ([[bundle bundleIdentifier] isEqualToString:identifier])
			return bundle;
	NSBundle *system = [NSBundle bundleWithPath:DBSystemApplicationPath];
	if ([[system bundleIdentifier] isEqualToString:identifier])
		return system;
	return nil;
}

mach_port_t SBSSpringBoardServerPort(void)
{
	return MACH_PORT_NULL;
}

NSArray *SBSCopyApplicationDisplayIdentifiers(bool active, bool debuggable)
{
	(void)debuggable;
	NSMutableArray *identifiers = [[NSMutableArray alloc] init];
	/* Darling does not track which apps are running here. */
	if (active)
		return identifiers;
	@autoreleasepool {
		for (NSBundle *bundle in DBInstalledApplications())
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

void SBSSetInterceptsMenuButtonForever(bool intercepts)
{
	(void)intercepts;
}

void SBReboot(mach_port_t port)
{
	(void)port;
}

