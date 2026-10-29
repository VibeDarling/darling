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
#import <AppKit/NSImage.h>

@implementation UIImageView {
	UIImage *_image;
	UIImage *_highlightedImage;
	BOOL _highlighted;
	BOOL _uikitTemplateByDefault;
	BOOL _uikitDarkened;
	CGFloat _uikitImageAlpha;
}

@synthesize animationImages = _animationImages;
@synthesize animationDuration = _animationDuration;

- (instancetype)initWithImage:(UIImage *)image
{
	CGSize size = image != nil ? [image size] : CGSizeZero;
	if ((self = [self initWithFrame:CGRectMake(0, 0, size.width, size.height)]))
		_image = image;
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
	if ((self = [super initWithFrame:frame])) {
		[self setUserInteractionEnabled:NO];
		_uikitImageAlpha = 1;
	}
	return self;
}

- (UIImage *)image { return _image; }
- (void)setImage:(UIImage *)image { _image = image; [self setNeedsDisplay:YES]; }
- (UIImage *)highlightedImage { return _highlightedImage; }
- (void)setHighlightedImage:(UIImage *)image { _highlightedImage = image; [self setNeedsDisplay:YES]; }
- (BOOL)isHighlighted { return _highlighted; }
- (void)setHighlighted:(BOOL)highlighted { _highlighted = highlighted; [self setNeedsDisplay:YES]; }
- (BOOL)uikitTemplateByDefault { return _uikitTemplateByDefault; }
- (void)setUikitTemplateByDefault:(BOOL)template { _uikitTemplateByDefault = template; [self setNeedsDisplay:YES]; }
- (BOOL)uikitDarkened { return _uikitDarkened; }
- (void)setUikitDarkened:(BOOL)darkened { _uikitDarkened = darkened; [self setNeedsDisplay:YES]; }
- (CGFloat)uikitImageAlpha { return _uikitImageAlpha; }
- (void)setUikitImageAlpha:(CGFloat)alpha { _uikitImageAlpha = alpha; [self setNeedsDisplay:YES]; }

- (void)tintColorDidChange
{
	[super tintColorDidChange];
	[self setNeedsDisplay:YES];
}

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
	UIImageRenderingMode mode = [image renderingMode];
	BOOL template = mode == UIImageRenderingModeAlwaysTemplate || (mode == UIImageRenderingModeAutomatic && _uikitTemplateByDefault);
	NSRect into = NSMakeRect(target.origin.x, target.origin.y, target.size.width, target.size.height);
	if (template) {
		NSImage *tinted = [image uikitImageTintedWith:[[self tintColor] nsColor]];
		[tinted drawInRect:into fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:_uikitImageAlpha respectFlipped:YES hints:nil];
	} else
		[image drawInRect:target blendMode:kCGBlendModeNormal alpha:_uikitImageAlpha];
	if (_uikitDarkened) {
		NSImage *shade = [image uikitImageTintedWith:[NSColor blackColor]];
		[shade drawInRect:into fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.3 * _uikitImageAlpha respectFlipped:YES hints:nil];
	}
}

@end
