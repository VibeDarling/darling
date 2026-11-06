/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIWINDOWSCENE_H
#define UIKIT_UIWINDOWSCENE_H

#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>

NS_ASSUME_NONNULL_BEGIN

@class UIWindow;

/*
 * The superclass is NSObject because UIScene is not implemented.  Nothing in
 * this layer creates scenes from a UISceneConfiguration yet, so an instance
 * comes from alloc/init; a window joins a scene through -[UIWindow
 * setWindowScene:].
 */
@interface UIWindowScene : NSObject {
@package
	NSMutableArray *_uiWindows;
}

/* The windows whose windowScene is this scene, in the order they joined. */
@property (nonatomic, readonly) NSArray<UIWindow *> *windows;

/* The window of this scene whose hosting window is the key window, else nil. */
@property (nonatomic, readonly, nullable) UIWindow *keyWindow;

@end

NS_ASSUME_NONNULL_END

#endif /* UIKIT_UIWINDOWSCENE_H */
