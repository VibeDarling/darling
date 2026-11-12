/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISLIDER_H
#define UIKIT_UISLIDER_H

#import <UIKit/UIControl.h>

@class UIImage, UIColor;

@interface UISlider : UIControl
@property (nonatomic) float value;
@property (nonatomic) float minimumValue;
@property (nonatomic) float maximumValue;
@property (nonatomic, getter=isContinuous) BOOL continuous;
@property (nonatomic, strong) UIImage *minimumValueImage;
@property (nonatomic, strong) UIImage *maximumValueImage;
@property (nonatomic, strong) UIColor *minimumTrackTintColor;
@property (nonatomic, strong) UIColor *maximumTrackTintColor;
@property (nonatomic, strong) UIColor *thumbTintColor;
@property (nonatomic, readonly) UIImage *currentThumbImage;
@property (nonatomic, readonly) UIImage *currentMinimumTrackImage;
@property (nonatomic, readonly) UIImage *currentMaximumTrackImage;
- (void)setValue:(float)value animated:(BOOL)animated;
- (void)setThumbImage:(UIImage *)image forState:(UIControlState)state;
- (void)setMinimumTrackImage:(UIImage *)image forState:(UIControlState)state;
- (void)setMaximumTrackImage:(UIImage *)image forState:(UIControlState)state;
- (UIImage *)thumbImageForState:(UIControlState)state;
- (UIImage *)minimumTrackImageForState:(UIControlState)state;
- (UIImage *)maximumTrackImageForState:(UIControlState)state;
- (CGRect)minimumValueImageRectForBounds:(CGRect)bounds;
- (CGRect)maximumValueImageRectForBounds:(CGRect)bounds;
- (CGRect)trackRectForBounds:(CGRect)bounds;
- (CGRect)thumbRectForBounds:(CGRect)bounds trackRect:(CGRect)rect value:(float)value;
@end

#endif /* UIKIT_UISLIDER_H */
