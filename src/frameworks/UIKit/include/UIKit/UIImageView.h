/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIIMAGEVIEW_H
#define UIKIT_UIIMAGEVIEW_H

#import <UIKit/UIView.h>

@class UIImage;

@interface UIImageView : UIView
- (instancetype)initWithImage:(UIImage *)image;
- (instancetype)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIImage *highlightedImage;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, copy) NSArray *animationImages;
@property (nonatomic) NSTimeInterval animationDuration;
- (void)startAnimating;
- (void)stopAnimating;
- (BOOL)isAnimating;
@end

#endif /* UIKIT_UIIMAGEVIEW_H */
