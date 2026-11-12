/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIBezierPath.h>
#import <UIKit/UIGraphics.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

@implementation UIBezierPath {
	CGMutablePathRef _path;
	CGFloat *_dash;
	NSInteger _dashCount;
	CGFloat _dashPhase;
}

@synthesize lineWidth = _lineWidth;
@synthesize lineCapStyle = _lineCapStyle;
@synthesize lineJoinStyle = _lineJoinStyle;
@synthesize miterLimit = _miterLimit;
@synthesize flatness = _flatness;
@synthesize usesEvenOddFillRule = _usesEvenOddFillRule;

- (instancetype)init
{
	if ((self = [super init]) == nil)
		return nil;
	_path = CGPathCreateMutable();
	_lineWidth = 1;
	_miterLimit = 10;
	_flatness = 0.6;
	return self;
}

- (void)dealloc
{
	CGPathRelease(_path);
	free(_dash);
}

+ (instancetype)bezierPath
{
	return [[self alloc] init];
}

+ (instancetype)bezierPathWithRect:(CGRect)rect
{
	UIBezierPath *path = [self bezierPath];
	CGPathAddRect(path->_path, NULL, rect);
	return path;
}

+ (instancetype)bezierPathWithOvalInRect:(CGRect)rect
{
	UIBezierPath *path = [self bezierPath];
	CGPathAddEllipseInRect(path->_path, NULL, rect);
	return path;
}

+ (instancetype)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)radius
{
	return [self bezierPathWithRoundedRect:rect byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(radius, radius)];
}

+ (instancetype)bezierPathWithRoundedRect:(CGRect)rect byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)radii
{
	UIBezierPath *path = [self bezierPath];
	CGFloat radius = MIN(MIN(radii.width, radii.height), MIN(rect.size.width, rect.size.height) / 2);
	if (radius <= 0) {
		CGPathAddRect(path->_path, NULL, rect);
		return path;
	}
	CGFloat minX = CGRectGetMinX(rect), maxX = CGRectGetMaxX(rect), minY = CGRectGetMinY(rect), maxY = CGRectGetMaxY(rect);
	CGFloat topLeft = (corners & UIRectCornerTopLeft) ? radius : 0;
	CGFloat topRight = (corners & UIRectCornerTopRight) ? radius : 0;
	CGFloat bottomLeft = (corners & UIRectCornerBottomLeft) ? radius : 0;
	CGFloat bottomRight = (corners & UIRectCornerBottomRight) ? radius : 0;
	/* UIKit's y grows downwards: the top is minY. */
	CGPathMoveToPoint(path->_path, NULL, minX + topLeft, minY);
	CGPathAddLineToPoint(path->_path, NULL, maxX - topRight, minY);
	if (topRight > 0)
		CGPathAddArc(path->_path, NULL, maxX - topRight, minY + topRight, topRight, -M_PI_2, 0, NO);
	CGPathAddLineToPoint(path->_path, NULL, maxX, maxY - bottomRight);
	if (bottomRight > 0)
		CGPathAddArc(path->_path, NULL, maxX - bottomRight, maxY - bottomRight, bottomRight, 0, M_PI_2, NO);
	CGPathAddLineToPoint(path->_path, NULL, minX + bottomLeft, maxY);
	if (bottomLeft > 0)
		CGPathAddArc(path->_path, NULL, minX + bottomLeft, maxY - bottomLeft, bottomLeft, M_PI_2, M_PI, NO);
	CGPathAddLineToPoint(path->_path, NULL, minX, minY + topLeft);
	if (topLeft > 0)
		CGPathAddArc(path->_path, NULL, minX + topLeft, minY + topLeft, topLeft, M_PI, 3 * M_PI_2, NO);
	CGPathCloseSubpath(path->_path);
	return path;
}

+ (instancetype)bezierPathWithArcCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise
{
	UIBezierPath *path = [self bezierPath];
	[path addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:clockwise];
	return path;
}

+ (instancetype)bezierPathWithCGPath:(CGPathRef)cgPath
{
	UIBezierPath *path = [self bezierPath];
	[path setCGPath:cgPath];
	return path;
}

- (id)copyWithZone:(NSZone *)zone
{
	UIBezierPath *copy = [[[self class] alloc] init];
	[copy setCGPath:_path];
	copy->_lineWidth = _lineWidth;
	copy->_lineCapStyle = _lineCapStyle;
	copy->_lineJoinStyle = _lineJoinStyle;
	copy->_miterLimit = _miterLimit;
	copy->_flatness = _flatness;
	copy->_usesEvenOddFillRule = _usesEvenOddFillRule;
	[copy setLineDash:_dash count:_dashCount phase:_dashPhase];
	return copy;
}

/* Archived as its drawing settings; the path itself is not kept. */
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeDouble:_lineWidth forKey:@"UIBezierPathLineWidth"];
	[coder encodeDouble:_miterLimit forKey:@"UIBezierPathMiterLimit"];
	[coder encodeDouble:_flatness forKey:@"UIBezierPathFlatness"];
	[coder encodeInteger:_lineCapStyle forKey:@"UIBezierPathLineCapStyle"];
	[coder encodeInteger:_lineJoinStyle forKey:@"UIBezierPathLineJoinStyle"];
	[coder encodeBool:_usesEvenOddFillRule forKey:@"UIBezierPathUsesEvenOddFillRule"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [self init]) == nil)
		return nil;
	if ([coder containsValueForKey:@"UIBezierPathLineWidth"])
		_lineWidth = [coder decodeDoubleForKey:@"UIBezierPathLineWidth"];
	if ([coder containsValueForKey:@"UIBezierPathMiterLimit"])
		_miterLimit = [coder decodeDoubleForKey:@"UIBezierPathMiterLimit"];
	if ([coder containsValueForKey:@"UIBezierPathFlatness"])
		_flatness = [coder decodeDoubleForKey:@"UIBezierPathFlatness"];
	_lineCapStyle = (CGLineCap)[coder decodeIntegerForKey:@"UIBezierPathLineCapStyle"];
	_lineJoinStyle = (CGLineJoin)[coder decodeIntegerForKey:@"UIBezierPathLineJoinStyle"];
	_usesEvenOddFillRule = [coder decodeBoolForKey:@"UIBezierPathUsesEvenOddFillRule"];
	return self;
}

- (CGPathRef)CGPath { return _path; }

- (void)setCGPath:(CGPathRef)path
{
	CGMutablePathRef copy = path != NULL ? CGPathCreateMutableCopy(path) : CGPathCreateMutable();
	CGPathRelease(_path);
	_path = copy;
}

- (CGPoint)currentPoint { return CGPathGetCurrentPoint(_path); }
- (BOOL)isEmpty { return CGPathIsEmpty(_path); }
- (CGRect)bounds { return CGPathGetBoundingBox(_path); }

- (void)moveToPoint:(CGPoint)point { CGPathMoveToPoint(_path, NULL, point.x, point.y); }
- (void)addLineToPoint:(CGPoint)point { CGPathAddLineToPoint(_path, NULL, point.x, point.y); }

- (void)addCurveToPoint:(CGPoint)endPoint controlPoint1:(CGPoint)c1 controlPoint2:(CGPoint)c2
{
	CGPathAddCurveToPoint(_path, NULL, c1.x, c1.y, c2.x, c2.y, endPoint.x, endPoint.y);
}

- (void)addQuadCurveToPoint:(CGPoint)endPoint controlPoint:(CGPoint)c
{
	CGPathAddQuadCurveToPoint(_path, NULL, c.x, c.y, endPoint.x, endPoint.y);
}

/* UIKit's clockwise is on screen, where y grows downwards; Core Graphics'
 * is in its own y-up space, so the flag is the other way round. */
- (void)addArcWithCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise
{
	CGPathAddArc(_path, NULL, center.x, center.y, radius, startAngle, endAngle, !clockwise);
}

- (void)closePath { CGPathCloseSubpath(_path); }

- (void)removeAllPoints
{
	CGPathRelease(_path);
	_path = CGPathCreateMutable();
}

- (void)appendPath:(UIBezierPath *)path
{
	if (path != nil)
		CGPathAddPath(_path, NULL, [path CGPath]);
}

- (void)applyTransform:(CGAffineTransform)transform
{
	CGMutablePathRef transformed = CGPathCreateMutable();
	CGPathAddPath(transformed, &transform, _path);
	CGPathRelease(_path);
	_path = transformed;
}

- (BOOL)containsPoint:(CGPoint)point
{
	return CGPathContainsPoint(_path, NULL, point, _usesEvenOddFillRule);
}

- (void)setLineDash:(const CGFloat *)pattern count:(NSInteger)count phase:(CGFloat)phase
{
	free(_dash);
	_dash = NULL;
	_dashCount = 0;
	_dashPhase = phase;
	if (pattern != NULL && count > 0) {
		_dash = malloc(count * sizeof(CGFloat));
		memcpy(_dash, pattern, count * sizeof(CGFloat));
		_dashCount = count;
	}
}

- (void)getLineDash:(CGFloat *)pattern count:(NSInteger *)count phase:(CGFloat *)phase
{
	if (pattern != NULL && _dash != NULL)
		memcpy(pattern, _dash, _dashCount * sizeof(CGFloat));
	if (count != NULL)
		*count = _dashCount;
	if (phase != NULL)
		*phase = _dashPhase;
}

- (void)uikitApplyStroke:(CGContextRef)context
{
	CGContextSetLineWidth(context, _lineWidth);
	CGContextSetLineCap(context, _lineCapStyle);
	CGContextSetLineJoin(context, _lineJoinStyle);
	CGContextSetMiterLimit(context, _miterLimit);
	CGContextSetFlatness(context, _flatness);
	CGContextSetLineDash(context, _dashPhase, _dash, _dashCount);
}

/* Whether all that painting path, outset by outset, would touch is clipped
 * away: a view drawn again for a strip of it draws all its shapes, and
 * Onyx2D strokes and fills a whole path before clipping it. */
static BOOL uikitClippedAway(CGContextRef context, CGPathRef path, CGFloat outset)
{
	CGRect clip = CGContextGetClipBoundingBox(context);
	CGRect box = CGRectInset(CGPathGetBoundingBox(path), -outset, -outset);
	return !CGRectIntersectsRect(clip, box);
}

- (void)fillWithBlendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (context == NULL || uikitClippedAway(context, _path, 1))
		return;
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, blendMode);
	CGContextSetAlpha(context, alpha);
	CGContextAddPath(context, _path);
	if (_usesEvenOddFillRule)
		CGContextEOFillPath(context);
	else
		CGContextFillPath(context);
	CGContextRestoreGState(context);
}

- (void)strokeWithBlendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGFloat outset = _lineWidth / 2 * (_lineJoinStyle == kCGLineJoinMiter ? MAX(_miterLimit, 1) : 1) + 1;
	if (context == NULL || uikitClippedAway(context, _path, outset))
		return;
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, blendMode);
	CGContextSetAlpha(context, alpha);
	[self uikitApplyStroke:context];
	CGContextAddPath(context, _path);
	CGContextStrokePath(context);
	CGContextRestoreGState(context);
}

- (void)fill { [self fillWithBlendMode:kCGBlendModeNormal alpha:1]; }
- (void)stroke { [self strokeWithBlendMode:kCGBlendModeNormal alpha:1]; }

- (void)addClip
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (context == NULL)
		return;
	CGContextAddPath(context, _path);
	if (_usesEvenOddFillRule)
		CGContextEOClip(context);
	else
		CGContextClip(context);
}

@end
