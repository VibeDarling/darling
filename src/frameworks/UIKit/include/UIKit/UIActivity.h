/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIACTIVITY_H
#define UIKIT_UIACTIVITY_H

#import <Foundation/Foundation.h>

@class UIImage, UIViewController;

typedef NSString *UIActivityType;

typedef NS_ENUM(NSInteger, UIActivityCategory) {
	UIActivityCategoryAction,
	UIActivityCategoryShare,
};

@interface UIActivity : NSObject
@property (class, nonatomic, readonly) UIActivityCategory activityCategory;
@property (nonatomic, readonly) UIActivityType activityType;
@property (nonatomic, readonly) NSString *activityTitle;
@property (nonatomic, readonly) UIImage *activityImage;
- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems;
- (void)prepareWithActivityItems:(NSArray *)activityItems;
@property (nonatomic, readonly) UIViewController *activityViewController;
- (void)performActivity;
- (void)activityDidFinish:(BOOL)completed;
@end

#endif /* UIKIT_UIACTIVITY_H */
