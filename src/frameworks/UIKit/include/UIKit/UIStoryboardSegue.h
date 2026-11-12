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

NS_ASSUME_NONNULL_BEGIN

@interface UIStoryboardSegue : NSObject
+ (instancetype)segueWithIdentifier:(nullable NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination performHandler:(void (^)(void))performHandler;
- (instancetype)initWithIdentifier:(nullable NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination;
@property (nullable, nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) __kindof UIViewController *sourceViewController;
@property (nonatomic, readonly) __kindof UIViewController *destinationViewController;
- (void)perform;
@end

@interface UIViewController (UIStoryboardSegue)
- (void)performSegueWithIdentifier:(NSString *)identifier sender:(nullable id)sender;
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(nullable id)sender;
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(nullable id)sender;
- (void)showViewController:(UIViewController *)controller sender:(nullable id)sender;
- (void)showDetailViewController:(UIViewController *)controller sender:(nullable id)sender;
@end

NS_ASSUME_NONNULL_END

#endif /* UIKIT_UISTORYBOARDSEGUE_H */
