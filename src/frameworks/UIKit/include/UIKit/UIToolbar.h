/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UITOOLBAR_H
#define UIKIT_UITOOLBAR_H

#import <UIKit/UIView.h>
#import <UIKit/UIBarButtonItem.h>

@class UIImage, UIColor, UIToolbar;

typedef NS_ENUM(NSInteger, UIBarPosition) {
	UIBarPositionAny = 0,
	UIBarPositionBottom = 1,
	UIBarPositionTop = 2,
	UIBarPositionTopAttached = 3,
};
typedef UIBarPosition UIToolbarPosition;
#define UIToolbarPositionAny UIBarPositionAny
#define UIToolbarPositionBottom UIBarPositionBottom
#define UIToolbarPositionTop UIBarPositionTop

typedef NS_ENUM(NSInteger, UIBarMetrics) {
	UIBarMetricsDefault,
	UIBarMetricsCompact,
	UIBarMetricsDefaultPrompt = 101,
	UIBarMetricsCompactPrompt,
	UIBarMetricsLandscapePhone = UIBarMetricsCompact,
};

@protocol UIToolbarDelegate <NSObject>
@optional
- (UIBarPosition)positionForBar:(id)bar;
@end

@interface UIToolbar : UIView
@property (nonatomic) UIBarStyle barStyle;
@property (nonatomic, copy) NSArray<UIBarButtonItem *> *items;
@property (nonatomic, getter=isTranslucent) BOOL translucent;
@property (nonatomic, strong) UIColor *barTintColor;
@property (nonatomic, weak) id<UIToolbarDelegate> delegate;
- (void)setItems:(NSArray<UIBarButtonItem *> *)items animated:(BOOL)animated;
- (void)setBackgroundImage:(UIImage *)image forToolbarPosition:(UIBarPosition)position barMetrics:(UIBarMetrics)metrics;
- (UIImage *)backgroundImageForToolbarPosition:(UIBarPosition)position barMetrics:(UIBarMetrics)metrics;
- (void)setShadowImage:(UIImage *)image forToolbarPosition:(UIBarPosition)position;
- (UIImage *)shadowImageForToolbarPosition:(UIBarPosition)position;
@end

#endif /* UIKIT_UITOOLBAR_H */
