/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIPROGRESSVIEW_H
#define UIKIT_UIPROGRESSVIEW_H

#import <UIKit/UIView.h>

@class UIImage, UIColor;

typedef NS_ENUM(NSInteger, UIProgressViewStyle) {
	UIProgressViewStyleDefault,
	UIProgressViewStyleBar,
};

@interface UIProgressView : UIView
- (instancetype)initWithProgressViewStyle:(UIProgressViewStyle)style;
@property (nonatomic) UIProgressViewStyle progressViewStyle;
@property (nonatomic) float progress;
@property (nonatomic, strong) UIColor *progressTintColor;
@property (nonatomic, strong) UIColor *trackTintColor;
@property (nonatomic, strong) UIImage *progressImage;
@property (nonatomic, strong) UIImage *trackImage;
@property (nonatomic, strong) NSProgress *observedProgress;
- (void)setProgress:(float)progress animated:(BOOL)animated;
@end

#endif /* UIKIT_UIPROGRESSVIEW_H */
