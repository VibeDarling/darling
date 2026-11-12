/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIDOCUMENTINTERACTIONCONTROLLER_H
#define UIKIT_UIDOCUMENTINTERACTIONCONTROLLER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>

@class UIDocumentInteractionController, UIBarButtonItem, UIImage;

@protocol UIDocumentInteractionControllerDelegate <NSObject>
@optional
- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerWillBeginPreview:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller;
@end

/* No other app registers document types with Darling, so there is never
 * anything to open a document in; presenting a menu reports so. */
@interface UIDocumentInteractionController : NSObject
+ (instancetype)interactionControllerWithURL:(NSURL *)url;
@property (nonatomic, weak) id<UIDocumentInteractionControllerDelegate> delegate;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, copy) NSString *UTI;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, readonly) NSArray<UIImage *> *icons;
@property (nonatomic, strong) id annotation;
@property (nonatomic, readonly) NSArray *gestureRecognizers;
- (BOOL)presentPreviewAnimated:(BOOL)animated;
- (BOOL)presentOptionsMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;
- (BOOL)presentOptionsMenuFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;
- (BOOL)presentOpenInMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;
- (BOOL)presentOpenInMenuFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;
- (void)dismissPreviewAnimated:(BOOL)animated;
- (void)dismissMenuAnimated:(BOOL)animated;
@end

#endif /* UIKIT_UIDOCUMENTINTERACTIONCONTROLLER_H */
