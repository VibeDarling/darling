/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIWINDOW_H
#define UIKIT_UIWINDOW_H

#import <UIKit/UIView.h>

@class UIViewController;

/*
 * A UIWindow is a UIView so that its view hierarchy is the NSWindow's content
 * view hierarchy, exactly one hosting window per UIKit root.
 */
@interface UIWindow : UIView {
@private
	id _hostWindow;
	UIViewController *_rootViewController;
}

- (instancetype)initWithFrame:(CGRect)frame;

@property (nonatomic, strong) UIViewController *rootViewController;

- (void)makeKeyAndVisible;
- (void)makeKeyWindow;
@property (nonatomic) CGFloat windowLevel;
@property (nonatomic, readonly, getter=isKeyWindow) BOOL keyWindow;
@property (nonatomic, strong) id screen;
- (void)sendEvent:(UIEvent *)event;
/* iPhone OS 2's spellings (private UIKit API). */
- (void)orderFront:(id)sender;
- (void)makeKey:(id)sender;
- (id)firstResponder;

@end

#endif /* UIKIT_UIWINDOW_H */
