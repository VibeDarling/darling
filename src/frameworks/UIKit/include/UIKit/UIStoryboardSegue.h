/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISTORYBOARDSEGUE_H
#define UIKIT_UISTORYBOARDSEGUE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>

@interface UIStoryboardSegue : NSObject
+ (instancetype)segueWithIdentifier:(NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination performHandler:(void (^)(void))performHandler;
- (instancetype)initWithIdentifier:(NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) __kindof UIViewController *sourceViewController;
@property (nonatomic, readonly) __kindof UIViewController *destinationViewController;
- (void)perform;
@end

@interface UIViewController (UIStoryboardSegue)
- (void)performSegueWithIdentifier:(NSString *)identifier sender:(id)sender;
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender;
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender;
- (void)showViewController:(UIViewController *)controller sender:(id)sender;
- (void)showDetailViewController:(UIViewController *)controller sender:(id)sender;
@end

#endif /* UIKIT_UISTORYBOARDSEGUE_H */
