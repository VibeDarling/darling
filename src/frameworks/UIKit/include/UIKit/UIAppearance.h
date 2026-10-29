/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIAPPEARANCE_H
#define UIKIT_UIAPPEARANCE_H

#import <Foundation/Foundation.h>

@protocol UIAppearanceContainer <NSObject>
@end

@protocol UIAppearance <NSObject>
+ (instancetype)appearance;
+ (instancetype)appearanceWhenContainedIn:(Class<UIAppearanceContainer>)containerClass, ... NS_REQUIRES_NIL_TERMINATION;
+ (instancetype)appearanceWhenContainedInInstancesOfClasses:(NSArray<Class<UIAppearanceContainer>> *)containerTypes;
+ (instancetype)appearanceForTraitCollection:(id)trait;
+ (instancetype)appearanceForTraitCollection:(id)trait whenContainedIn:(Class<UIAppearanceContainer>)containerClass, ... NS_REQUIRES_NIL_TERMINATION;
+ (instancetype)appearanceForTraitCollection:(id)trait whenContainedInInstancesOfClasses:(NSArray<Class<UIAppearanceContainer>> *)containerTypes;
@end

#import <UIKit/UIView.h>
#import <UIKit/UIBarButtonItem.h>

@interface UIView (UIAppearance) <UIAppearance>
@end

@interface UIBarItem (UIAppearance) <UIAppearance>
@end

#endif /* UIKIT_UIAPPEARANCE_H */
