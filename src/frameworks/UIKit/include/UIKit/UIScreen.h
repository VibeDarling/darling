/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISCREEN_H
#define UIKIT_UISCREEN_H

#import <Foundation/NSObject.h>
#import <CoreGraphics/CGGeometry.h>

#import <Foundation/NSArray.h>

/* A screen's size in pixels; the host's screen has the one. */
@interface UIScreenMode : NSObject
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat pixelAspectRatio;
@end

@interface UIScreen : NSObject

+ (UIScreen *)mainScreen;
/* The host's screen is the only one. */
+ (NSArray<UIScreen *> *)screens;

@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGRect nativeBounds;
@property (nonatomic, readonly) CGFloat nativeScale;
/* The screen less the status bar. */
@property (nonatomic, readonly) CGRect applicationFrame;
@property (nonatomic) CGFloat brightness;
@property (nonatomic, readonly) NSArray<UIScreenMode *> *availableModes;
@property (nonatomic, readonly) UIScreenMode *preferredMode;
@property (nonatomic, strong) UIScreenMode *currentMode;
@property (nonatomic, readonly) NSInteger maximumFramesPerSecond;
@property (nonatomic, readonly) UIScreen *mirroredScreen;

@end

#endif /* UIKIT_UISCREEN_H */
