/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIScreen.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSScreen.h>

@implementation UIScreen

+ (UIScreen *)mainScreen
{
	static UIScreen *screen;
	if (screen == nil)
		screen = [[UIScreen alloc] init];
	return screen;
}

+ (NSArray<UIScreen *> *)screens
{
	static NSMutableArray<UIScreen *> *others;
	UIScreen *main = [self mainScreen];
	NSScreen *mainNative = [NSScreen mainScreen];
	NSMutableArray<UIScreen *> *result = [NSMutableArray arrayWithObject:main];

	@synchronized(self) {
		NSMutableArray<UIScreen *> *current = [NSMutableArray array];
		for (NSScreen *native in [NSScreen screens]) {
			if (native == mainNative)
				continue;
			UIScreen *known = nil;
			for (UIScreen *candidate in others) {
				if (candidate->_uiNativeScreen == native) {
					known = candidate;
					break;
				}
			}
			if (known == nil) {
				known = [[UIScreen alloc] init];
				known->_uiNativeScreen = native;
			}
			[current addObject:known];
		}
		others = current;
		[result addObjectsFromArray:current];
	}
	return result;
}

- (NSScreen *)nativeScreen
{
	return _uiNativeScreen != nil ? _uiNativeScreen : [NSScreen mainScreen];
}

- (CGRect)bounds
{
	NSScreen *screen = [self nativeScreen];
	NSRect frame = screen != nil ? [screen frame] : NSMakeRect(0, 0, 1024, 768);
	return CGRectMake(0, 0, frame.size.width, frame.size.height);
}

- (CGFloat)scale
{
	NSScreen *screen = [self nativeScreen];
	CGFloat scale = screen != nil ? [screen backingScaleFactor] : 1.0;
	return scale > 0 ? scale : 1.0;
}

- (CGRect)nativeBounds
{
	CGRect points = [self bounds];
	CGFloat scale = [self scale];
	return CGRectMake(0, 0, points.size.width * scale, points.size.height * scale);
}

@end
