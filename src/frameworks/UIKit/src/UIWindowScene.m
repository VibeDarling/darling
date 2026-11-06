/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIWindowScene.h>
#import <UIKit/UIWindow.h>

@implementation UIWindowScene

- (instancetype)init
{
	self = [super init];
	if (self != nil)
		_uiWindows = [[NSMutableArray alloc] init];
	return self;
}

- (NSArray<UIWindow *> *)windows
{
	return [_uiWindows copy];
}

- (UIWindow *)keyWindow
{
	for (UIWindow *window in _uiWindows) {
		if ([window isKeyWindow])
			return window;
	}
	return nil;
}

@end
