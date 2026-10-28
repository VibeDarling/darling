/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIScrollView.h>
#import <UIKit/UITouch.h>
#import <UIKit/UIColor.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSBezierPath.h>
#import "UIKitPrivate.h"

/* Movement before a press becomes a drag, in points. */
static const CGFloat UIKitDragThreshold = 6;

@interface UIKitScrollIndicator : UIView
@end

@implementation UIKitScrollIndicator

- (void)drawRect:(NSRect)rect
{
	[[NSColor colorWithCalibratedWhite:0 alpha:0.35] setFill];
	NSRect bounds = [self bounds];
	CGFloat radius = MIN(bounds.size.width, bounds.size.height) / 2;
	[[NSBezierPath bezierPathWithRoundedRect:bounds xRadius:radius yRadius:radius] fill];
}

- (NSView *)hitTest:(NSPoint)point
{
	return nil;
}

@end

@implementation UIScrollView {
	CGSize _contentSize;
	UIEdgeInsets _contentInset;
	BOOL _scrollEnabled;
	BOOL _tracking;
	BOOL _dragging;
	CGPoint _touchStart;
	CGPoint _offsetStart;
	UIKitScrollIndicator *_indicator;
	NSTimer *_indicatorTimer;
}

@synthesize delegate = _delegate;
@synthesize scrollIndicatorInsets = _scrollIndicatorInsets;
@synthesize pagingEnabled = _pagingEnabled;
@synthesize directionalLockEnabled = _directionalLockEnabled;
@synthesize bounces = _bounces;
@synthesize alwaysBounceVertical = _alwaysBounceVertical;
@synthesize alwaysBounceHorizontal = _alwaysBounceHorizontal;
@synthesize showsVerticalScrollIndicator = _showsVerticalScrollIndicator;
@synthesize showsHorizontalScrollIndicator = _showsHorizontalScrollIndicator;
@synthesize indicatorStyle = _indicatorStyle;
@synthesize decelerationRate = _decelerationRate;
@synthesize scrollsToTop = _scrollsToTop;
@synthesize delaysContentTouches = _delaysContentTouches;
@synthesize canCancelContentTouches = _canCancelContentTouches;
@synthesize zoomScale = _zoomScale;
@synthesize minimumZoomScale = _minimumZoomScale;
@synthesize maximumZoomScale = _maximumZoomScale;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_scrollEnabled = YES;
		_bounces = YES;
		_showsVerticalScrollIndicator = YES;
		_showsHorizontalScrollIndicator = YES;
		_decelerationRate = UIScrollViewDecelerationRateNormal;
		_scrollsToTop = YES;
		_delaysContentTouches = YES;
		_canCancelContentTouches = YES;
		_zoomScale = _minimumZoomScale = _maximumZoomScale = 1;
		_uiClipsToBounds = YES;
	}
	return self;
}

- (CGPoint)contentOffset
{
	NSPoint origin = [self bounds].origin;
	return CGPointMake(origin.x, origin.y);
}

- (CGPoint)clampedOffset:(CGPoint)offset
{
	NSSize size = [self bounds].size;
	CGFloat maxX = MAX(-_contentInset.left, _contentSize.width + _contentInset.right - size.width);
	CGFloat maxY = MAX(-_contentInset.top, _contentSize.height + _contentInset.bottom - size.height);
	offset.x = MAX(-_contentInset.left, MIN(offset.x, maxX));
	offset.y = MAX(-_contentInset.top, MIN(offset.y, maxY));
	return offset;
}

- (void)setContentOffset:(CGPoint)offset
{
	offset.x = round(offset.x);
	offset.y = round(offset.y);
	NSPoint current = [self bounds].origin;
	if (current.x == offset.x && current.y == offset.y)
		return;
	[self setBoundsOrigin:NSMakePoint(offset.x, offset.y)];
	[self setNeedsDisplay:YES];
	[self uikitDidScroll];
	if ([_delegate respondsToSelector:@selector(scrollViewDidScroll:)])
		[_delegate scrollViewDidScroll:self];
}

- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated
{
	[self setContentOffset:offset];
	if (animated && [_delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)])
		[_delegate scrollViewDidEndScrollingAnimation:self];
}

- (void)setOffset:(CGPoint)offset
{
	[self setContentOffset:[self clampedOffset:offset]];
}

/* Subclasses (UITableView) lay out what has come into view. */
- (void)uikitDidScroll
{
	[self updateIndicator];
}

- (CGSize)contentSize { return _contentSize; }

- (void)setContentSize:(CGSize)size
{
	_contentSize = size;
	CGPoint clamped = [self clampedOffset:[self contentOffset]];
	if (!CGPointEqualToPoint(clamped, [self contentOffset]))
		[self setContentOffset:clamped];
	[self updateIndicator];
}

- (UIEdgeInsets)contentInset { return _contentInset; }
- (void)setContentInset:(UIEdgeInsets)inset { _contentInset = inset; }
- (BOOL)isScrollEnabled { return _scrollEnabled; }
- (void)setScrollEnabled:(BOOL)enabled { _scrollEnabled = enabled; }
- (void)setScrollingEnabled:(BOOL)enabled { _scrollEnabled = enabled; }
- (void)setShowBackgroundShadow:(BOOL)show { }
- (BOOL)isTracking { return _tracking; }
- (BOOL)isDragging { return _dragging; }
- (BOOL)isDecelerating { return NO; }
- (void)setZoomScale:(CGFloat)scale animated:(BOOL)animated { _zoomScale = scale; }

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];
	CGPoint clamped = [self clampedOffset:[self contentOffset]];
	if (!CGPointEqualToPoint(clamped, [self contentOffset]))
		[self setContentOffset:clamped];
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated
{
	CGPoint offset = [self contentOffset];
	NSSize size = [self bounds].size;
	if (rect.origin.y < offset.y)
		offset.y = rect.origin.y;
	else if (CGRectGetMaxY(rect) > offset.y + size.height)
		offset.y = CGRectGetMaxY(rect) - size.height;
	if (rect.origin.x < offset.x)
		offset.x = rect.origin.x;
	else if (CGRectGetMaxX(rect) > offset.x + size.width)
		offset.x = CGRectGetMaxX(rect) - size.width;
	[self setContentOffset:[self clampedOffset:offset] animated:animated];
}

#pragma mark Indicator

- (void)updateIndicator
{
	NSRect bounds = [self bounds];
	if (!_showsVerticalScrollIndicator || _contentSize.height <= bounds.size.height + 1 || bounds.size.height <= 0) {
		[_indicator setHidden:YES];
		return;
	}
	if (_indicator == nil) {
		_indicator = [[UIKitScrollIndicator alloc] initWithFrame:CGRectZero];
		[_indicator setHidden:YES];
	}
	if ([_indicator superview] != self || [[self subviews] lastObject] != _indicator) {
		[_indicator removeFromSuperview];
		[super addSubview:_indicator];
	}
	CGFloat visible = bounds.size.height;
	CGFloat height = MAX(36, visible * visible / _contentSize.height);
	CGFloat range = MAX(1, _contentSize.height - visible);
	CGFloat y = bounds.origin.y + (visible - height) * MAX(0, MIN(1, bounds.origin.y / range));
	[_indicator setFrame:NSMakeRect(NSMaxX(bounds) - 6, y + 2, 3, height - 4)];
	[_indicator setHidden:NO];
	[_indicatorTimer invalidate];
	_indicatorTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(hideIndicator:) userInfo:nil repeats:NO];
}

- (void)hideIndicator:(NSTimer *)timer
{
	_indicatorTimer = nil;
	[_indicator setHidden:YES];
}

- (void)flashScrollIndicators
{
	[self updateIndicator];
}

- (void)addSubview:(NSView *)view
{
	[super addSubview:view];
	/* Keep the indicator on top. */
	if (_indicator != nil && view != _indicator && [_indicator superview] == self) {
		[_indicator removeFromSuperview];
		[super addSubview:_indicator];
	}
}

#pragma mark Scrolling input

- (void)scrollWheel:(NSEvent *)event
{
	if (!_scrollEnabled) {
		[super scrollWheel:event];
		return;
	}
	CGPoint offset = [self contentOffset];
	offset.y -= [event deltaY] * 40;
	offset.x -= [event deltaX] * 40;
	CGPoint clamped = [self clampedOffset:offset];
	if (CGPointEqualToPoint(clamped, [self contentOffset])) {
		/* At the end: let an enclosing scroll view have it. */
		[[self nextResponder] scrollWheel:event];
		return;
	}
	[self setContentOffset:clamped];
}

/* The touch in window coordinates, which do not move as the content does. */
static CGPoint UIKitTouchInWindow(NSSet *touches)
{
	return [[touches anyObject] locationInView:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	_tracking = YES;
	_dragging = NO;
	_touchStart = UIKitTouchInWindow(touches);
	_offsetStart = [self contentOffset];
	[self uikitTouchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!_tracking)
		return;
	CGPoint point = UIKitTouchInWindow(touches);
	CGFloat dx = point.x - _touchStart.x, dy = point.y - _touchStart.y;
	if (!_dragging && _scrollEnabled && (fabs(dx) > UIKitDragThreshold || fabs(dy) > UIKitDragThreshold)) {
		_dragging = YES;
		[self uikitTouchesCancelled:touches withEvent:event];
		if ([_delegate respondsToSelector:@selector(scrollViewWillBeginDragging:)])
			[_delegate scrollViewWillBeginDragging:self];
	}
	if (_dragging) {
		CGPoint offset = _offsetStart;
		if (_contentSize.width > [self bounds].size.width)
			offset.x -= dx;
		offset.y -= dy;
		[self setContentOffset:[self clampedOffset:offset]];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	BOOL dragged = _dragging;
	_tracking = NO;
	_dragging = NO;
	if (dragged) {
		if ([_delegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)])
			[_delegate scrollViewDidEndDragging:self willDecelerate:NO];
		return;
	}
	[self uikitTouchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	BOOL dragged = _dragging;
	_tracking = NO;
	_dragging = NO;
	if (!dragged)
		[self uikitTouchesCancelled:touches withEvent:event];
}

/* What a press that does not become a drag does; UITableView selects. */
- (void)uikitTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event { }
- (void)uikitTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { }
- (void)uikitTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event { }

@end
