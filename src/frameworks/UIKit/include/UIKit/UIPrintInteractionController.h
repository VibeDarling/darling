/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIPRINTINTERACTIONCONTROLLER_H
#define UIKIT_UIPRINTINTERACTIONCONTROLLER_H

#import <UIKit/UIView.h>

@class UIPrintInteractionController, UIPrintInfo, UIBarButtonItem;

typedef NS_ENUM(NSInteger, UIPrintInfoOutputType) {
	UIPrintInfoOutputGeneral,
	UIPrintInfoOutputPhoto,
	UIPrintInfoOutputGrayscale,
	UIPrintInfoOutputPhotoGrayscale,
};

typedef NS_ENUM(NSInteger, UIPrintInfoOrientation) {
	UIPrintInfoOrientationPortrait,
	UIPrintInfoOrientationLandscape,
};

typedef NS_ENUM(NSInteger, UIPrintInfoDuplex) {
	UIPrintInfoDuplexNone,
	UIPrintInfoDuplexLongEdge,
	UIPrintInfoDuplexShortEdge,
};

@interface UIPrintInfo : NSObject <NSCopying, NSCoding>
+ (UIPrintInfo *)printInfo;
+ (UIPrintInfo *)printInfoWithDictionary:(NSDictionary *)dictionary;
@property (nonatomic, copy) NSString *printerID;
@property (nonatomic, copy) NSString *jobName;
@property (nonatomic) UIPrintInfoOutputType outputType;
@property (nonatomic) UIPrintInfoOrientation orientation;
@property (nonatomic) UIPrintInfoDuplex duplex;
- (NSDictionary *)dictionaryRepresentation;
@end

typedef void (^UIPrintInteractionCompletionHandler)(UIPrintInteractionController *printInteractionController, BOOL completed, NSError *error);

/* There are no printers. */
@interface UIPrintInteractionController : NSObject
+ (BOOL)isPrintingAvailable;
+ (NSSet<NSString *> *)printableUTIs;
+ (BOOL)canPrintURL:(NSURL *)url;
+ (BOOL)canPrintData:(NSData *)data;
+ (UIPrintInteractionController *)sharedPrintController;
@property (nonatomic, strong) UIPrintInfo *printInfo;
@property (nonatomic, weak) id delegate;
@property (nonatomic) BOOL showsPageRange;
@property (nonatomic) BOOL showsNumberOfCopies;
@property (nonatomic, strong) id printPageRenderer;
@property (nonatomic, strong) id printFormatter;
@property (nonatomic, copy) id printingItem;
@property (nonatomic, copy) NSArray *printingItems;
- (BOOL)presentAnimated:(BOOL)animated completionHandler:(UIPrintInteractionCompletionHandler)completion;
- (BOOL)presentFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated completionHandler:(UIPrintInteractionCompletionHandler)completion;
- (BOOL)presentFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated completionHandler:(UIPrintInteractionCompletionHandler)completion;
- (void)dismissAnimated:(BOOL)animated;
@end

#endif /* UIKIT_UIPRINTINTERACTIONCONTROLLER_H */
