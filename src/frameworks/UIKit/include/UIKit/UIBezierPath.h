/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIBEZIERPATH_H
#define UIKIT_UIBEZIERPATH_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_OPTIONS(NSUInteger, UIRectCorner) {
	UIRectCornerTopLeft = 1 << 0,
	UIRectCornerTopRight = 1 << 1,
	UIRectCornerBottomLeft = 1 << 2,
	UIRectCornerBottomRight = 1 << 3,
	UIRectCornerAllCorners = ~0UL,
};

@interface UIBezierPath : NSObject <NSCopying, NSCoding>
+ (instancetype)bezierPath;
+ (instancetype)bezierPathWithRect:(CGRect)rect;
+ (instancetype)bezierPathWithOvalInRect:(CGRect)rect;
+ (instancetype)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)radius;
+ (instancetype)bezierPathWithRoundedRect:(CGRect)rect byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)radii;
+ (instancetype)bezierPathWithArcCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
+ (instancetype)bezierPathWithCGPath:(CGPathRef)path;

@property (nonatomic) CGPathRef CGPath;
@property (nonatomic, readonly) CGPoint currentPoint;
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) CGLineCap lineCapStyle;
@property (nonatomic) CGLineJoin lineJoinStyle;
@property (nonatomic) CGFloat miterLimit;
@property (nonatomic) CGFloat flatness;
@property (nonatomic) BOOL usesEvenOddFillRule;

- (void)moveToPoint:(CGPoint)point;
- (void)addLineToPoint:(CGPoint)point;
- (void)addCurveToPoint:(CGPoint)endPoint controlPoint1:(CGPoint)controlPoint1 controlPoint2:(CGPoint)controlPoint2;
- (void)addQuadCurveToPoint:(CGPoint)endPoint controlPoint:(CGPoint)controlPoint;
- (void)addArcWithCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
- (void)closePath;
- (void)removeAllPoints;
- (void)appendPath:(UIBezierPath *)path;
- (void)applyTransform:(CGAffineTransform)transform;
- (BOOL)containsPoint:(CGPoint)point;
- (void)setLineDash:(const CGFloat *)pattern count:(NSInteger)count phase:(CGFloat)phase;
- (void)getLineDash:(CGFloat *)pattern count:(NSInteger *)count phase:(CGFloat *)phase;
- (void)fill;
- (void)stroke;
- (void)fillWithBlendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
- (void)strokeWithBlendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
- (void)addClip;
@end

#endif /* UIKIT_UIBEZIERPATH_H */
