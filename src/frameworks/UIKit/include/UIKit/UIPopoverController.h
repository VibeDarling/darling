/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIPOPOVERCONTROLLER_H
#define UIKIT_UIPOPOVERCONTROLLER_H

#import <UIKit/UIViewController.h>

@class UIPopoverController, UIBarButtonItem, UIView, UIColor;

typedef NS_OPTIONS(NSUInteger, UIPopoverArrowDirection) {
	UIPopoverArrowDirectionUp = 1 << 0,
	UIPopoverArrowDirectionDown = 1 << 1,
	UIPopoverArrowDirectionLeft = 1 << 2,
	UIPopoverArrowDirectionRight = 1 << 3,
	UIPopoverArrowDirectionAny = 0xf,
	UIPopoverArrowDirectionUnknown = NSUIntegerMax,
};

@protocol UIPopoverControllerDelegate <NSObject>
@optional
- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController;
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController;
@end

/* On a phone screen a popover is presented full screen. */
@interface UIPopoverController : NSObject
- (instancetype)initWithContentViewController:(UIViewController *)viewController;
@property (nonatomic, weak) id<UIPopoverControllerDelegate> delegate;
@property (nonatomic, strong) UIViewController *contentViewController;
@property (nonatomic) CGSize popoverContentSize;
@property (nonatomic, readonly, getter=isPopoverVisible) BOOL popoverVisible;
@property (nonatomic, readonly) UIPopoverArrowDirection popoverArrowDirection;
@property (nonatomic, copy) NSArray *passthroughViews;
@property (nonatomic, strong) UIColor *backgroundColor;
- (void)setContentViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)setPopoverContentSize:(CGSize)size animated:(BOOL)animated;
- (void)presentPopoverFromRect:(CGRect)rect inView:(UIView *)view permittedArrowDirections:(UIPopoverArrowDirection)directions animated:(BOOL)animated;
- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)item permittedArrowDirections:(UIPopoverArrowDirection)directions animated:(BOOL)animated;
- (void)dismissPopoverAnimated:(BOOL)animated;
@end

#endif /* UIKIT_UIPOPOVERCONTROLLER_H */
