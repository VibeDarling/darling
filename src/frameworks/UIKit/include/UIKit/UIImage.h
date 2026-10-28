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

#import <CoreGraphics/CGContext.h>
#import <UIKit/UIGeometry.h>

@class NSData;

/* Backed by an AppKit image, which reads the formats Darling's AppKit can. */
@interface UIImage : NSObject

+ (UIImage *)imageNamed:(NSString *)name;
+ (UIImage *)imageWithContentsOfFile:(NSString *)path;
+ (UIImage *)imageWithData:(NSData *)data;
+ (UIImage *)imageWithData:(NSData *)data scale:(CGFloat)scale;
+ (UIImage *)imageWithCGImage:(CGImageRef)image;
+ (UIImage *)imageWithCGImage:(CGImageRef)image scale:(CGFloat)scale orientation:(NSInteger)orientation;
- (instancetype)initWithContentsOfFile:(NSString *)path;
- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale;
- (instancetype)initWithCGImage:(CGImageRef)image;
- (instancetype)initWithCGImage:(CGImageRef)image scale:(CGFloat)scale orientation:(NSInteger)orientation;

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGImageRef CGImage;
@property (nonatomic, readonly) NSInteger leftCapWidth;
@property (nonatomic, readonly) NSInteger topCapHeight;

/* Cap insets are not honored: the image stretches as a whole. */
- (UIImage *)stretchableImageWithLeftCapWidth:(NSInteger)leftCapWidth topCapHeight:(NSInteger)topCapHeight;
- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)capInsets;

- (void)drawInRect:(CGRect)rect;
- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
- (void)drawAtPoint:(CGPoint)point;
- (void)drawAtPoint:(CGPoint)point blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;

@end

#ifdef __cplusplus
extern "C" {
#endif
NSData *UIImagePNGRepresentation(UIImage *image);
NSData *UIImageJPEGRepresentation(UIImage *image, CGFloat compressionQuality);
#ifdef __cplusplus
}
#endif

#endif /* UIKIT_UIIMAGE_H */
