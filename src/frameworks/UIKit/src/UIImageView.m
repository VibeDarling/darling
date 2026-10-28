/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIImageView.h>
#import <UIKit/UIImage.h>
#import "UIKitPrivate.h"

@implementation UIImageView {
	UIImage *_image;
	UIImage *_highlightedImage;
	BOOL _highlighted;
}

@synthesize animationImages = _animationImages;
@synthesize animationDuration = _animationDuration;

- (instancetype)initWithImage:(UIImage *)image
{
	CGSize size = image != nil ? [image size] : CGSizeZero;
	if ((self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)])) {
		_image = image;
		[self setUserInteractionEnabled:NO];
	}
	return self;
}

- (instancetype)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage
{
	if ((self = [self initWithImage:image]))
		_highlightedImage = highlightedImage;
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
		[self setUserInteractionEnabled:NO];
	return self;
}

- (UIImage *)image { return _image; }
- (void)setImage:(UIImage *)image { _image = image; [self setNeedsDisplay:YES]; }
- (UIImage *)highlightedImage { return _highlightedImage; }
- (void)setHighlightedImage:(UIImage *)image { _highlightedImage = image; [self setNeedsDisplay:YES]; }
- (BOOL)isHighlighted { return _highlighted; }
- (void)setHighlighted:(BOOL)highlighted { _highlighted = highlighted; [self setNeedsDisplay:YES]; }
- (void)startAnimating { }
- (void)stopAnimating { }
- (BOOL)isAnimating { return NO; }

- (CGSize)sizeThatFits:(CGSize)size
{
	return _image != nil ? [_image size] : CGSizeZero;
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	UIImage *image = _highlighted && _highlightedImage != nil ? _highlightedImage : _image;
	if (image == nil)
		return;
	NSRect bounds = [self bounds];
	CGSize size = [image size];
	CGRect target = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
	switch ([self contentMode]) {
	case UIViewContentModeScaleToFill:
	case UIViewContentModeRedraw:
		break;
	case UIViewContentModeScaleAspectFit:
	case UIViewContentModeScaleAspectFill: {
		CGFloat sx = bounds.size.width / MAX(1, size.width), sy = bounds.size.height / MAX(1, size.height);
		CGFloat scale = [self contentMode] == UIViewContentModeScaleAspectFit ? MIN(sx, sy) : MAX(sx, sy);
		target.size = CGSizeMake(size.width * scale, size.height * scale);
		target.origin = CGPointMake(NSMidX(bounds) - target.size.width / 2, NSMidY(bounds) - target.size.height / 2);
		break;
	}
	default:
		target.size = size;
		target.origin = CGPointMake(floor(NSMidX(bounds) - size.width / 2), floor(NSMidY(bounds) - size.height / 2));
		break;
	}
	[image drawInRect:target];
}

@end
