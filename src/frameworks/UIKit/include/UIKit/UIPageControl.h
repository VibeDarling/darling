/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIPAGECONTROL_H
#define UIKIT_UIPAGECONTROL_H

#import <UIKit/UIControl.h>

@class UIColor;

@interface UIPageControl : UIControl
@property (nonatomic) NSInteger numberOfPages;
@property (nonatomic) NSInteger currentPage;
@property (nonatomic) BOOL hidesForSinglePage;
@property (nonatomic) BOOL defersCurrentPageDisplay;
@property (nonatomic, strong) UIColor *pageIndicatorTintColor;
@property (nonatomic, strong) UIColor *currentPageIndicatorTintColor;
- (void)updateCurrentPageDisplay;
- (CGSize)sizeForNumberOfPages:(NSInteger)pageCount;
@end

#endif /* UIKIT_UIPAGECONTROL_H */
