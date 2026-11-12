/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * Settings (com.apple.Preferences): its pages are Preferences.framework list
 * controllers. Tweaks add theirs the way PreferenceLoader lets them on iOS,
 * with a plist in /Library/PreferenceLoader/Preferences whose "entry" is the
 * row, linking either to a bundle in /Library/PreferenceBundles or to the
 * plist's own "items". Rootless installs (/var/jb) are looked in too.
 */

#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#include <sys/utsname.h>
#include <sys/sysctl.h>

static NSArray *loaderDirectories(void)
{
	return @[ @"/Library/PreferenceLoader/Preferences", @"/var/jb/Library/PreferenceLoader/Preferences" ];
}

/* A row icon: a rounded square in the color, with the symbol on it. */
static UIImage *rowIcon(UIColor *color, NSString *symbol)
{
	CGRect bounds = CGRectMake(0, 0, 29, 29);
	UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0);
	[color setFill];
	[[UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:6.5] fill];
	NSDictionary *attributes = @{ NSFontAttributeName: [UIFont boldSystemFontOfSize:17], NSForegroundColorAttributeName: [UIColor whiteColor] };
	CGSize size = [symbol sizeWithAttributes:attributes];
	[symbol drawAtPoint:CGPointMake(floor((29 - size.width) / 2), floor((29 - size.height) / 2)) withAttributes:attributes];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static UIImage *scaledIcon(UIImage *image)
{
	if (!image || (image.size.width <= 29 && image.size.height <= 29))
		return image;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(29, 29), NO, 0);
	[image drawInRect:CGRectMake(0, 0, 29, 29)];
	UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return scaled;
}

static PSSpecifier *linkTo(NSString *name, Class detail, UIImage *icon, NSString *identifier)
{
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name target:nil set:NULL get:NULL detail:detail cell:PSLinkCell edit:Nil];
	specifier.identifier = identifier;
	if (icon)
		[specifier setProperty:icon forKey:PSIconImageKey];
	return specifier;
}

static PSSpecifier *titleValue(NSString *name, NSString *value, id target)
{
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name target:target set:NULL get:@selector(staticValue:) detail:Nil cell:PSTitleValueCell edit:Nil];
	[specifier setProperty:value ?: @"" forKey:PSValueKey];
	specifier.identifier = name;
	return specifier;
}

/* A PreferenceLoader plist's own items, as a page. */
@interface PLCustomListController : PSListController
@end

@implementation PLCustomListController

- (NSArray *)specifiers
{
	if (!_specifiers) {
		NSString *path = [self.specifier propertyForKey:@"plist"];
		NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
		NSString *title = nil;
		NSBundle *bundle = [NSBundle bundleWithPath:[path stringByDeletingLastPathComponent]];
		_specifiers = [SpecifiersFromPlist(plist, self.specifier, self, [[path lastPathComponent] stringByDeletingPathExtension],
			bundle, &title, NULL, self, NULL) mutableCopy];
		if (title)
			self.title = title;
	}
	return _specifiers;
}

@end

@interface SettingsAboutController : PSListController
@end

@implementation SettingsAboutController

- (id)staticValue:(PSSpecifier *)specifier
{
	return [specifier propertyForKey:PSValueKey];
}

- (NSArray *)specifiers
{
	if (!_specifiers) {
		UIDevice *device = [UIDevice currentDevice];
		struct utsname name;
		uname(&name);
		NSMutableArray *specifiers = [NSMutableArray array];
		[specifiers addObject:[PSSpecifier emptyGroupSpecifier]];
		[specifiers addObject:titleValue(@"Name", device.name, self)];
		[specifiers addObject:titleValue(@"Software Version", device.systemVersion, self)];
		[specifiers addObject:titleValue(@"Model Name", device.model, self)];
		[specifiers addObject:titleValue(@"Kernel", [NSString stringWithFormat:@"%s %s", name.sysname, name.release], self)];
		[specifiers addObject:titleValue(@"Architecture", @(name.machine), self)];
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:NULL];
		if (attributes) {
			NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
			[specifiers addObject:titleValue(@"Capacity", [formatter stringFromByteCount:[attributes[NSFileSystemSize] longLongValue]], self)];
			[specifiers addObject:titleValue(@"Available", [formatter stringFromByteCount:[attributes[NSFileSystemFreeSize] longLongValue]], self)];
		}
		PSSpecifier *footer = [PSSpecifier groupSpecifierWithHeader:nil footer:@"Darling Pocket runs iOS apps on Darling."];
		[specifiers addObject:footer];
		_specifiers = specifiers;
		self.title = @"About";
	}
	return _specifiers;
}

@end

@interface SettingsGeneralController : PSListController
@end

@implementation SettingsGeneralController

- (NSArray *)specifiers
{
	if (!_specifiers) {
		_specifiers = [@[
			[PSSpecifier emptyGroupSpecifier],
			linkTo(@"About", [SettingsAboutController class], nil, @"ABOUT"),
		] mutableCopy];
		self.title = @"General";
	}
	return _specifiers;
}

@end

/* PreferenceLoader's pl_filter: an entry for some iOS versions only, by
   CoreFoundationVersion, [min] or [min, max). Tweaks ship one entry per era
   (WinterBoard's for iOS 7 and later, and before). */
static BOOL entryPassesFilter(NSDictionary *entry)
{
	NSDictionary *filter = entry[@"pl_filter"];
	if (![filter isKindOfClass:[NSDictionary class]])
		return YES;
	NSArray *range = filter[@"CoreFoundationVersion"];
	if ([range isKindOfClass:[NSArray class]] && range.count > 0) {
		if (kCFCoreFoundationVersionNumber < [range[0] doubleValue])
			return NO;
		if (range.count > 1 && kCFCoreFoundationVersionNumber >= [range[1] doubleValue])
			return NO;
	}
	return YES;
}

@interface SettingsRootController : PSListController
@end

@implementation SettingsRootController

/* The rows tweaks add, sorted by label. */
- (NSArray *)loaderSpecifiers
{
	NSMutableArray *rows = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	for (NSString *directory in loaderDirectories()) {
		for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL]) {
			if (![file.pathExtension isEqual:@"plist"] || [seen containsObject:file])
				continue;
			NSString *path = [directory stringByAppendingPathComponent:file];
			NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
			NSDictionary *entry = plist[@"entry"];
			if (![entry isKindOfClass:[NSDictionary class]] || !entryPassesFilter(entry))
				continue;
			NSMutableDictionary *item = [entry mutableCopy];
			if (!item[@"cell"])
				item[@"cell"] = @"PSLinkCell";
			NSBundle *bundle = [NSBundle bundleWithPath:directory];
			NSArray *specifiers = SpecifiersFromPlist(@{ @"items": @[ item ] }, nil, self, file.stringByDeletingPathExtension, bundle, NULL, NULL, self, NULL);
			PSSpecifier *specifier = specifiers.firstObject;
			if (!specifier)
				continue;
			if (!item[@"bundle"] && plist[@"items"]) {
				specifier.detailControllerClass = [PLCustomListController class];
				[specifier setProperty:path forKey:@"plist"];
			}
			if (![specifier propertyForKey:PSIconImageKey]) {
				NSString *icon = entry[@"icon"];
				NSString *iconPath = icon ? [directory stringByAppendingPathComponent:icon] : nil;
				UIImage *image = iconPath ? [UIImage imageWithContentsOfFile:iconPath] : nil;
				[specifier setProperty:image ?: rowIcon([UIColor colorWithWhite:0.55 alpha:1], [specifier.name.length ? specifier.name : @"?" substringToIndex:1])
					forKey:PSIconImageKey];
			} else {
				[specifier setProperty:scaledIcon([specifier propertyForKey:PSIconImageKey]) forKey:PSIconImageKey];
			}
			if (!specifier.identifier || [specifier.identifier isEqual:specifier.name])
				specifier.identifier = file.stringByDeletingPathExtension;
			[seen addObject:file];
			[rows addObject:specifier];
		}
	}
	[rows sortUsingComparator:^NSComparisonResult(PSSpecifier *a, PSSpecifier *b) {
		return [a.name localizedCaseInsensitiveCompare:b.name];
	}];
	return rows;
}

- (NSArray *)specifiers
{
	if (!_specifiers) {
		NSMutableArray *specifiers = [NSMutableArray array];
		[specifiers addObject:[PSSpecifier emptyGroupSpecifier]];
		[specifiers addObject:linkTo(@"General", [SettingsGeneralController class],
			rowIcon([UIColor colorWithRed:0.56 green:0.56 blue:0.58 alpha:1], @"⚙"), @"General")];
		NSArray *tweaks = [self loaderSpecifiers];
		if (tweaks.count) {
			[specifiers addObject:[PSSpecifier groupSpecifierWithID:@"TWEAKS" name:@"Tweaks"]];
			[specifiers addObjectsFromArray:tweaks];
		}
		_specifiers = specifiers;
		self.title = @"Settings";
	}
	return _specifiers;
}

@end

@interface SettingsAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SettingsAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	PSRootController *root = [[PSRootController alloc] initWithTitle:@"Settings" identifier:@"com.apple.Preferences"];
	SettingsRootController *list = [[SettingsRootController alloc] init];
	list.rootController = root;
	[root pushViewController:list animated:NO];
	self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	self.window.rootViewController = root;
	[self.window makeKeyAndVisible];
	return YES;
}

@end

int main(int argc, char *argv[])
{
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([SettingsAppDelegate class]));
	}
}
