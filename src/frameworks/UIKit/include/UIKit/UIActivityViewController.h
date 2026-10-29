/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIACTIVITYVIEWCONTROLLER_H
#define UIKIT_UIACTIVITYVIEWCONTROLLER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIActivity.h>

typedef void (^UIActivityViewControllerCompletionHandler)(UIActivityType activityType, BOOL completed);
typedef void (^UIActivityViewControllerCompletionWithItemsHandler)(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError);

/* Lists the application's activities that can handle the items, and Copy. */
@interface UIActivityViewController : UIViewController
- (instancetype)initWithActivityItems:(NSArray *)activityItems applicationActivities:(NSArray<UIActivity *> *)applicationActivities;
@property (nonatomic, copy) UIActivityViewControllerCompletionHandler completionHandler;
@property (nonatomic, copy) UIActivityViewControllerCompletionWithItemsHandler completionWithItemsHandler;
@property (nonatomic, copy) NSArray<UIActivityType> *excludedActivityTypes;
@end

#endif /* UIKIT_UIACTIVITYVIEWCONTROLLER_H */
