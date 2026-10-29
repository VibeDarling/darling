/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UISlider.h>
#import <UIKit/UIProgressView.h>
#import <UIKit/UIPageControl.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIImage.h>
#import <UIKit/UITouch.h>
#import "UIKitPrivate.h"
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSGraphics.h>

#pragma mark - UISlider

#define UIKitSliderThumbSize 28.0

@implementation UISlider {
	float _value;
	float _minimumValue;
	float _maximumValue;
	BOOL _discrete;
	NSMutableDictionary<NSNumber *, UIImage *> *_thumbImages;
	NSMutableDictionary<NSNumber *, UIImage *> *_minimumTrackImages;
	NSMutableDictionary<NSNumber *, UIImage *> *_maximumTrackImages;
}

@synthesize minimumValueImage = _minimumValueImage;
@synthesize maximumValueImage = _maximumValueImage;
@synthesize minimumTrackTintColor = _minimumTrackTintColor;
@synthesize maximumTrackTintColor = _maximumTrackTintColor;
@synthesize thumbTintColor = _thumbTintColor;

- (instancetype)initWithFrame:(CGRect)frame
{
	if (frame.size.height == 0)
		frame.size.height = 31;
	if ((self = [super initWithFrame:frame]) == nil)
		return nil;
	_maximumValue = 1;
	_thumbImages = [NSMutableDictionary dictionary];
	_minimumTrackImages = [NSMutableDictionary dictionary];
	_maximumTrackImages = [NSMutableDictionary dictionary];
	return self;
}

- (float)value { return _value; }

- (void)setValue:(float)value
{
	_value = MIN(MAX(value, _minimumValue), _maximumValue);
	[self setNeedsDisplay:YES];
}

- (void)setValue:(float)value animated:(BOOL)animated { [self setValue:value]; }
- (float)minimumValue { return _minimumValue; }
- (void)setMinimumValue:(float)value { _minimumValue = value; _maximumValue = MAX(_maximumValue, value); [self setValue:_value]; }
- (float)maximumValue { return _maximumValue; }
- (void)setMaximumValue:(float)value { _maximumValue = value; _minimumValue = MIN(_minimumValue, value); [self setValue:_value]; }
- (BOOL)isContinuous { return !_discrete; }
- (void)setContinuous:(BOOL)continuous { _discrete = !continuous; }

static void UIKitSetImageForState(NSMutableDictionary *images, UIImage *image, UIControlState state)
{
	if (image != nil)
		[images setObject:image forKey:@(state)];
	else
		[images removeObjectForKey:@(state)];
}

static UIImage *UIKitImageForState(NSDictionary *images, UIControlState state)
{
	return [images objectForKey:@(state)] ?: [images objectForKey:@(UIControlStateNormal)];
}

- (void)setThumbImage:(UIImage *)image forState:(UIControlState)state { UIKitSetImageForState(_thumbImages, image, state); [self setNeedsDisplay:YES]; }
- (void)setMinimumTrackImage:(UIImage *)image forState:(UIControlState)state { UIKitSetImageForState(_minimumTrackImages, image, state); [self setNeedsDisplay:YES]; }
- (void)setMaximumTrackImage:(UIImage *)image forState:(UIControlState)state { UIKitSetImageForState(_maximumTrackImages, image, state); [self setNeedsDisplay:YES]; }
- (UIImage *)thumbImageForState:(UIControlState)state { return [_thumbImages objectForKey:@(state)]; }
- (UIImage *)minimumTrackImageForState:(UIControlState)state { return [_minimumTrackImages objectForKey:@(state)]; }
- (UIImage *)maximumTrackImageForState:(UIControlState)state { return [_maximumTrackImages objectForKey:@(state)]; }
- (UIImage *)currentThumbImage { return UIKitImageForState(_thumbImages, [self state]); }
- (UIImage *)currentMinimumTrackImage { return UIKitImageForState(_minimumTrackImages, [self state]); }
- (UIImage *)currentMaximumTrackImage { return UIKitImageForState(_maximumTrackImages, [self state]); }

- (CGRect)minimumValueImageRectForBounds:(CGRect)bounds
{
	if (_minimumValueImage == nil)
		return CGRectZero;
	CGSize size = [_minimumValueImage size];
	return CGRectMake(0, floor((bounds.size.height - size.height) / 2), size.width, size.height);
}

- (CGRect)maximumValueImageRectForBounds:(CGRect)bounds
{
	if (_maximumValueImage == nil)
		return CGRectZero;
	CGSize size = [_maximumValueImage size];
	return CGRectMake(bounds.size.width - size.width, floor((bounds.size.height - size.height) / 2), size.width, size.height);
}

- (CGRect)trackRectForBounds:(CGRect)bounds
{
	CGFloat left = _minimumValueImage != nil ? [self minimumValueImageRectForBounds:bounds].size.width + 8 : 0;
	CGFloat right = _maximumValueImage != nil ? [self maximumValueImageRectForBounds:bounds].size.width + 8 : 0;
	return CGRectMake(left, floor(bounds.size.height / 2) - 1, MAX(0, bounds.size.width - left - right), 2);
}

- (CGSize)uikitThumbSize
{
	UIImage *image = [self currentThumbImage];
	return image != nil ? [image size] : CGSizeMake(UIKitSliderThumbSize, UIKitSliderThumbSize);
}

- (CGRect)thumbRectForBounds:(CGRect)bounds trackRect:(CGRect)rect value:(float)value
{
	CGSize thumb = [self uikitThumbSize];
	float range = _maximumValue - _minimumValue;
	CGFloat fraction = range > 0 ? (value - _minimumValue) / range : 0;
	CGFloat x = rect.origin.x + fraction * MAX(0, rect.size.width - thumb.width);
	return CGRectMake(round(x), round(CGRectGetMidY(rect) - thumb.height / 2), thumb.width, thumb.height);
}

- (CGSize)sizeThatFits:(CGSize)size
{
	return CGSizeMake(MAX(size.width, 118), 31);
}

- (void)uikitTrack:(NSSet *)touches
{
	CGRect bounds = NSRectToCGRect([self bounds]);
	CGRect track = [self trackRectForBounds:bounds];
	CGFloat thumb = [self uikitThumbSize].width;
	CGFloat x = [[touches anyObject] locationInView:self].x;
	CGFloat span = track.size.width - thumb;
	CGFloat fraction = span > 0 ? (x - track.origin.x - thumb / 2) / span : 0;
	fraction = MIN(MAX(fraction, 0), 1);
	float value = _minimumValue + fraction * (_maximumValue - _minimumValue);
	if (value == _value)
		return;
	[self setValue:value];
	if (!_discrete)
		[self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
	if ([self isTracking])
		[self uikitTrack:touches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self isTracking])
		[self uikitTrack:touches];
	[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self isTracking]) {
		[self uikitTrack:touches];
		if (_discrete)
			[self sendActionsForControlEvents:UIControlEventValueChanged];
	}
	[super touchesEnded:touches withEvent:event];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	CGRect bounds = NSRectToCGRect([self bounds]);
	CGRect track = [self trackRectForBounds:bounds];
	CGRect thumb = [self thumbRectForBounds:bounds trackRect:track value:_value];
	if (_minimumValueImage != nil)
		[_minimumValueImage drawInRect:[self minimumValueImageRectForBounds:bounds]];
	if (_maximumValueImage != nil)
		[_maximumValueImage drawInRect:[self maximumValueImageRectForBounds:bounds]];

	CGFloat split = CGRectGetMidX(thumb);
	NSRect minimum = NSMakeRect(track.origin.x, track.origin.y, split - track.origin.x, track.size.height);
	NSRect maximum = NSMakeRect(split, track.origin.y, CGRectGetMaxX(track) - split, track.size.height);
	UIImage *minimumImage = [self currentMinimumTrackImage], *maximumImage = [self currentMaximumTrackImage];
	if (minimumImage != nil) {
		[minimumImage drawInRect:NSRectToCGRect(minimum)];
	} else {
		[(_minimumTrackTintColor != nil ? [_minimumTrackTintColor nsColor] : [[self tintColor] nsColor]) setFill];
		[[NSBezierPath bezierPathWithRoundedRect:minimum xRadius:1 yRadius:1] fill];
	}
	if (maximumImage != nil) {
		[maximumImage drawInRect:NSRectToCGRect(maximum)];
	} else {
		[(_maximumTrackTintColor != nil ? [_maximumTrackTintColor nsColor] : [NSColor colorWithCalibratedRed:0.72 green:0.72 blue:0.74 alpha:1]) setFill];
		[[NSBezierPath bezierPathWithRoundedRect:maximum xRadius:1 yRadius:1] fill];
	}

	UIImage *thumbImage = [self currentThumbImage];
	if (thumbImage != nil) {
		[thumbImage drawInRect:thumb];
	} else {
		NSBezierPath *knob = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(NSRectFromCGRect(thumb), 0.5, 0.5)];
		[(_thumbTintColor != nil ? [_thumbTintColor nsColor] : [NSColor whiteColor]) setFill];
		[knob fill];
		[[NSColor colorWithCalibratedWhite:0.75 alpha:1] setStroke];
		[knob stroke];
	}
	if (![self isEnabled]) {
		[[NSColor colorWithCalibratedWhite:1 alpha:0.5] setFill];
		NSRectFillUsingOperation([self bounds], NSCompositeSourceOver);
	}
}

@end

#pragma mark - UIProgressView

@implementation UIProgressView {
	float _progress;
}

@synthesize progressViewStyle = _progressViewStyle;
@synthesize progressTintColor = _progressTintColor;
@synthesize trackTintColor = _trackTintColor;
@synthesize progressImage = _progressImage;
@synthesize trackImage = _trackImage;
@synthesize observedProgress = _observedProgress;

- (instancetype)initWithProgressViewStyle:(UIProgressViewStyle)style
{
	if ((self = [self initWithFrame:CGRectMake(0, 0, 150, 2)]))
		_progressViewStyle = style;
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if (frame.size.height == 0)
		frame.size.height = 2;
	if ((self = [super initWithFrame:frame]))
		[self setOpaque:NO];
	return self;
}

- (float)progress
{
	if (_observedProgress != nil)
		return (float)[_observedProgress fractionCompleted];
	return _progress;
}

- (void)setProgress:(float)progress
{
	_progress = MIN(MAX(progress, 0), 1);
	[self setNeedsDisplay:YES];
}

- (void)setProgress:(float)progress animated:(BOOL)animated { [self setProgress:progress]; }

- (CGSize)sizeThatFits:(CGSize)size
{
	return CGSizeMake(size.width, 2);
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	NSRect done = NSMakeRect(0, 0, round(bounds.size.width * [self progress]), bounds.size.height);
	NSRect rest = NSMakeRect(NSMaxX(done), 0, bounds.size.width - done.size.width, bounds.size.height);
	if (_trackImage != nil) {
		[_trackImage drawInRect:NSRectToCGRect(bounds)];
	} else {
		NSColor *track = _trackTintColor != nil ? [_trackTintColor nsColor]
			: _progressViewStyle == UIProgressViewStyleBar ? [NSColor clearColor]
			: [NSColor colorWithCalibratedRed:0.72 green:0.72 blue:0.74 alpha:1];
		[track setFill];
		NSRectFillUsingOperation(rest, NSCompositeSourceOver);
	}
	if (_progressImage != nil) {
		[_progressImage drawInRect:NSRectToCGRect(done)];
	} else {
		[(_progressTintColor != nil ? [_progressTintColor nsColor] : [[self tintColor] nsColor]) setFill];
		NSRectFill(done);
	}
}

@end

#pragma mark - UIPageControl

#define UIKitPageDotSize 7.0
#define UIKitPageDotSpacing 9.0

@implementation UIPageControl {
	NSInteger _numberOfPages;
	NSInteger _currentPage;
	NSInteger _displayedPage;
}

@synthesize hidesForSinglePage = _hidesForSinglePage;
@synthesize defersCurrentPageDisplay = _defersCurrentPageDisplay;
@synthesize pageIndicatorTintColor = _pageIndicatorTintColor;
@synthesize currentPageIndicatorTintColor = _currentPageIndicatorTintColor;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
		[self setOpaque:NO];
	return self;
}

- (NSInteger)numberOfPages { return _numberOfPages; }

- (void)setNumberOfPages:(NSInteger)pages
{
	_numberOfPages = MAX(0, pages);
	[self setCurrentPage:_currentPage];
}

- (NSInteger)currentPage { return _currentPage; }

- (void)setCurrentPage:(NSInteger)page
{
	_currentPage = MIN(MAX(page, 0), MAX(_numberOfPages - 1, 0));
	_displayedPage = _currentPage;
	[self setNeedsDisplay:YES];
}

- (void)updateCurrentPageDisplay
{
	_displayedPage = _currentPage;
	[self setNeedsDisplay:YES];
}

- (CGSize)sizeForNumberOfPages:(NSInteger)count
{
	return CGSizeMake(MAX(0, count) * (UIKitPageDotSize + UIKitPageDotSpacing) + UIKitPageDotSpacing, 37);
}

- (CGSize)sizeThatFits:(CGSize)size
{
	return [self sizeForNumberOfPages:_numberOfPages];
}

/* A tap on either side of the current dot moves one page that way. */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self isTracking] && [self uikitInside:touches]) {
		CGFloat x = [[touches anyObject] locationInView:self].x;
		NSInteger page = _currentPage + (x < [self uikitDotX:_displayedPage] ? -1 : 1);
		if (page >= 0 && page < _numberOfPages) {
			_currentPage = page;
			if (!_defersCurrentPageDisplay)
				_displayedPage = page;
			[self setNeedsDisplay:YES];
			[self sendActionsForControlEvents:UIControlEventValueChanged];
		}
	}
	[super touchesEnded:touches withEvent:event];
}

- (BOOL)uikitInside:(NSSet *)touches
{
	CGPoint point = [[touches anyObject] locationInView:self];
	return NSPointInRect(NSMakePoint(point.x, point.y), [self bounds]);
}

- (CGFloat)uikitDotX:(NSInteger)index
{
	CGFloat width = _numberOfPages * UIKitPageDotSize + (_numberOfPages - 1) * UIKitPageDotSpacing;
	CGFloat start = floor(([self bounds].size.width - width) / 2);
	return start + index * (UIKitPageDotSize + UIKitPageDotSpacing) + UIKitPageDotSize / 2;
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	if (_numberOfPages == 0 || (_hidesForSinglePage && _numberOfPages == 1))
		return;
	CGFloat y = floor(([self bounds].size.height - UIKitPageDotSize) / 2);
	NSColor *other = _pageIndicatorTintColor != nil ? [_pageIndicatorTintColor nsColor] : [NSColor colorWithCalibratedWhite:1 alpha:0.2];
	NSColor *current = _currentPageIndicatorTintColor != nil ? [_currentPageIndicatorTintColor nsColor] : [NSColor whiteColor];
	for (NSInteger i = 0; i < _numberOfPages; i++) {
		[(i == _displayedPage ? current : other) setFill];
		CGFloat x = [self uikitDotX:i] - UIKitPageDotSize / 2;
		[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x, y, UIKitPageDotSize, UIKitPageDotSize)] fill];
	}
}

@end
