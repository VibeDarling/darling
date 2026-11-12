/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISTORYBOARD_H
#define UIKIT_UISTORYBOARD_H

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>

/* A compiled storyboard (Name.storyboardc): one nib per scene, made into
 * view controllers on request. */
@interface UIStoryboard : NSObject
+ (UIStoryboard *)storyboardWithName:(NSString *)name bundle:(NSBundle *)storyboardBundleOrNil;
- (__kindof UIViewController *)instantiateInitialViewController;
- (__kindof UIViewController *)instantiateViewControllerWithIdentifier:(NSString *)identifier;
@end

@interface UIViewController (UIStoryboard)
@property (nonatomic, readonly, strong) UIStoryboard *storyboard;
@end

#endif /* UIKIT_UISTORYBOARD_H */
