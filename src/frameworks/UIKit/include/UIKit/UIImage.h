/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIIMAGE_H
#define UIKIT_UIIMAGE_H

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGImage.h>

/* Backed by an AppKit image, which reads the formats Darling's AppKit can. */
@interface UIImage : NSObject

+ (UIImage *)imageNamed:(NSString *)name;
+ (UIImage *)imageWithContentsOfFile:(NSString *)path;
- (instancetype)initWithContentsOfFile:(NSString *)path;

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGImageRef CGImage;

- (void)drawInRect:(CGRect)rect;

@end

#endif /* UIKIT_UIIMAGE_H */
