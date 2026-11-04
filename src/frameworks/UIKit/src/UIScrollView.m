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
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSWindow.h>
#import "UIKitPrivate.h"
#include <stdlib.h>
#include <string.h>

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
	/* While a scroll that copied lays out: what it invalidates, kept apart. */
	NSMutableArray *_scrollRedraw;
}

@synthesize delegate = _delegate;
@synthesize scrollIndicatorInsets = _scrollIndicatorInsets;
@synthesize contentInsetAdjustmentBehavior = _contentInsetAdjustmentBehavior;

/* Nothing (no status or navigation bar overlap) adds to the content inset here. */
- (UIEdgeInsets)adjustedContentInset { return [self contentInset]; }
- (void)adjustedContentInsetDidChange { }
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

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	_contentSize = [coder decodeCGSizeForKey:@"UIContentSize"];
	_contentInset = [coder decodeUIEdgeInsetsForKey:@"UIContentInset"];
	_scrollIndicatorInsets = [coder decodeUIEdgeInsetsForKey:@"UIScrollIndicatorInsets"];
	_scrollEnabled = ![coder decodeBoolForKey:@"UIScrollDisabled"];
	_pagingEnabled = [coder decodeBoolForKey:@"UIPagingEnabled"];
	_directionalLockEnabled = [coder decodeBoolForKey:@"UIDirectionalLockEnabled"];
	_bounces = ![coder decodeBoolForKey:@"UIBounceDisabled"];
	_alwaysBounceVertical = [coder decodeBoolForKey:@"UIAlwaysBounceVertical"];
	_alwaysBounceHorizontal = [coder decodeBoolForKey:@"UIAlwaysBounceHorizontal"];
	if ([coder containsValueForKey:@"UIShowsVerticalScrollIndicator"])
		_showsVerticalScrollIndicator = [coder decodeBoolForKey:@"UIShowsVerticalScrollIndicator"];
	if ([coder containsValueForKey:@"UIShowsHorizontalScrollIndicator"])
		_showsHorizontalScrollIndicator = [coder decodeBoolForKey:@"UIShowsHorizontalScrollIndicator"];
	if ([coder decodeBoolForKey:@"UIVerticalScrollIndicatorDisabled"])
		_showsVerticalScrollIndicator = NO;
	if ([coder decodeBoolForKey:@"UIHorizontalScrollIndicatorDisabled"])
		_showsHorizontalScrollIndicator = NO;
	if ([coder containsValueForKey:@"UIMinimumZoomScale"])
		_minimumZoomScale = [coder decodeDoubleForKey:@"UIMinimumZoomScale"];
	if ([coder containsValueForKey:@"UIMaximumZoomScale"])
		_maximumZoomScale = [coder decodeDoubleForKey:@"UIMaximumZoomScale"];
	_contentInsetAdjustmentBehavior = [coder decodeIntegerForKey:@"UIScrollViewContentInsetAdjustmentBehavior"];
	if ([coder containsValueForKey:@"UIDelaysContentTouches"])
		_delaysContentTouches = [coder decodeBoolForKey:@"UIDelaysContentTouches"];
	if ([coder containsValueForKey:@"UICanCancelContentTouches"])
		_canCancelContentTouches = [coder decodeBoolForKey:@"UICanCancelContentTouches"];
	if ([coder containsValueForKey:@"UIDelegate"])
		_delegate = [coder decodeObjectForKey:@"UIDelegate"];
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

/* Whether view draws one opaque colour over all of rect (in its coordinates)
 * and nothing else: as a list's background does. */
static BOOL solidOver(NSView *view, NSRect rect)
{
	if (![view isKindOfClass:[UIView class]] || ![(UIView *)view uikitDrawsOnlyBackground] || [view alphaValue] < 1)
		return NO;
	UIColor *background = [(UIView *)view backgroundColor];
	if (background == nil || [background alphaComponent] < 1 || !NSContainsRect([view bounds], rect))
		return NO;
	for (NSView *subview in [view subviews])
		if (![subview isHidden] && !NSIsEmptyRect(NSIntersectionRect([subview convertRect:[subview bounds] toView:view], rect)))
			return NO;
	return YES;
}

/*
 * Whether what is behind the scroll view, inside it, is one colour: the
 * views from it up to an opaque one draw only their background, and of
 * their other subviews behind it, the nearest that reaches into it is one
 * colour all over it (and hides the rest). Then the pixels of the window
 * there move with the content.
 */
static BOOL uniformBehind(UIScrollView *scrollView, NSRect visible)
{
	NSView *view = scrollView;
	for (;;) {
		BOOL drawsWithContent = view == scrollView && [scrollView uikitDrawingScrollsWithContent];
		if (![view isKindOfClass:[UIView class]] || (!drawsWithContent && ![(UIView *)view uikitDrawsOnlyBackground]))
			return NO;
		UIColor *background = [(UIView *)view backgroundColor];
		if (background != nil && [background alphaComponent] >= 1)
			return YES;
		NSView *superview = [view superview];
		if (superview == nil)
			return YES;
		NSArray *siblings = [superview subviews];
		NSUInteger index = [siblings indexOfObjectIdenticalTo:view];
		for (NSUInteger i = index; index != NSNotFound && i-- > 0;) {
			NSView *sibling = [siblings objectAtIndex:i];
			if ([sibling isHidden])
				continue;
			NSRect rect = [scrollView convertRect:visible toView:sibling];
			if (!NSIsEmptyRect(NSIntersectionRect(rect, [sibling bounds])))
				return solidOver(sibling, rect);
		}
		view = superview;
	}
}

/* The views drawn in front of the scroll view that cover part of rect (in
 * its coordinates), as rects in its coordinates. */
static NSArray *viewsInFront(UIScrollView *scrollView, NSRect rect)
{
	NSMutableArray *covered = [NSMutableArray array];
	NSView *view = scrollView;
	for (NSView *superview = [view superview]; superview != nil; view = superview, superview = [view superview]) {
		NSArray *siblings = [superview subviews];
		NSUInteger index = [siblings indexOfObjectIdenticalTo:view];
		for (NSUInteger i = index + 1; index != NSNotFound && i < [siblings count]; i++) {
			NSView *sibling = [siblings objectAtIndex:i];
			if ([sibling isHidden])
				continue;
			NSRect overlap = NSIntersectionRect([sibling convertRect:[sibling bounds] toView:scrollView], rect);
			if (!NSIsEmptyRect(overlap))
				[covered addObject:[NSValue valueWithRect:overlap]];
		}
	}
	return covered;
}

/*
 * Scrolling by delta: rather than draw all the content again, move what the
 * window shows of it and draw only what comes into view, as AppKit's clip
 * views copy on scroll. The views in front of the scroll view, moved along
 * with it, are drawn again where they are and where they were moved to.
 */
- (BOOL)uikitScrollByCopying:(NSSize)delta redraw:(NSMutableArray *)redraw
{
	static int enabled = -1;
	if (enabled < 0) {
		const char *setting = getenv("DARLING_UIKIT_SCROLL_COPY");
		enabled = setting == NULL || strcmp(setting, "0") != 0;
	}
	NSWindow *window = [self window];
	if (!enabled || window == nil || ![window isVisible] || (delta.width != 0 && delta.height != 0))
		return NO;
	NSRect visible = [self visibleRect];
	CGFloat distance = fabs(delta.width + delta.height);
	CGFloat extent = delta.width != 0 ? visible.size.width : visible.size.height;
	if (NSIsEmptyRect(visible) || distance >= extent || !uniformBehind(self, visible))
		return NO;
	/* Views in front are drawn again where they were and where they are:
	 * when they cover most of it (a sheet over a list), drawing it all is
	 * less. */
	NSArray *front = viewsInFront(self, visible);
	CGFloat coveredArea = 0;
	for (NSValue *value in front)
		coveredArea += [value rectValue].size.width * [value rectValue].size.height;
	if (coveredArea * 2 >= visible.size.width * visible.size.height)
		return NO;

	CGContextRef context = (CGContextRef)[[window graphicsContext] graphicsPort];
	uint8_t *pixels = context != NULL ? CGBitmapContextGetData(context) : NULL;
	if (pixels == NULL)
		return NO;
	size_t stride = CGBitmapContextGetBytesPerRow(context);
	size_t width = CGBitmapContextGetWidth(context);
	size_t height = CGBitmapContextGetHeight(context);
	NSRect content = [[window contentView] frame];
	CGFloat scale = content.size.width > 0 ? width / content.size.width : 0;
	if (scale <= 0 || CGBitmapContextGetBitsPerPixel(context) != 32)
		return NO;

	/* The window's rows run top down; its coordinates, bottom up. */
	NSRect area = [self convertRect:visible toView:nil];
	long left = lround(NSMinX(area) * scale), right = lround(NSMaxX(area) * scale);
	long top = lround((content.size.height - NSMaxY(area)) * scale);
	long bottom = lround((content.size.height - NSMinY(area)) * scale);
	left = MAX(left, 0);
	top = MAX(top, 0);
	right = MIN(right, (long)width);
	bottom = MIN(bottom, (long)height);
	long dx = lround(delta.width * scale), dy = lround(delta.height * scale);
	long rows = bottom - top - labs(dy), columns = right - left - labs(dx);
	if (rows <= 0 || columns <= 0)
		return NO;
	/* The new pixel at p is the old one at p + delta. */
	long from = dy > 0 ? top + dy : top, to = dy > 0 ? top : top - dy;
	long fromX = dx > 0 ? left + dx : left, toX = dx > 0 ? left : left - dx;
	if (dy > 0)
		for (long row = 0; row < rows; row++)
			memmove(pixels + (to + row) * stride + toX * 4, pixels + (from + row) * stride + fromX * 4, columns * 4);
	else
		for (long row = rows - 1; row >= 0; row--)
			memmove(pixels + (to + row) * stride + toX * 4, pixels + (from + row) * stride + fromX * 4, columns * 4);

	/* What came into view, a point wider for the rounding at its edge. */
	NSRect exposed = visible;
	if (delta.height > 0) {
		exposed.origin.y = NSMaxY(visible) - delta.height - 1;
		exposed.size.height = delta.height + 1;
	} else if (delta.height < 0) {
		exposed.size.height = -delta.height + 1;
	} else if (delta.width > 0) {
		exposed.origin.x = NSMaxX(visible) - delta.width - 1;
		exposed.size.width = delta.width + 1;
	} else {
		exposed.size.width = -delta.width + 1;
	}
	/* Drawn one by one rather than marked: AppKit keeps one dirty rect per
	 * view, and the union of these with the scroll indicator's is most of
	 * the scroll view. */
	[redraw addObject:[NSValue valueWithRect:exposed]];
	for (NSValue *value in front) {
		NSRect covered = [value rectValue];
		[redraw addObject:value];
		[redraw addObject:[NSValue valueWithRect:NSOffsetRect(covered, -delta.width, -delta.height)]];
	}
	return YES;
}

- (void)setContentOffset:(CGPoint)offset
{
	offset.x = round(offset.x);
	offset.y = round(offset.y);
	NSPoint current = [self bounds].origin;
	if (current.x == offset.x && current.y == offset.y)
		return;
	/* What the window shows has to be current before it is moved. */
	NSWindow *window = [self window];
	if ([window viewsNeedDisplay]) {
		[window disableFlushWindow];
		[window displayIfNeeded];
		[window enableFlushWindow];
	}
	[self setBoundsOrigin:NSMakePoint(offset.x, offset.y)];
	NSMutableArray *redraw = [NSMutableArray array];
	BOOL copied = [self uikitScrollByCopying:NSMakeSize(offset.x - current.x, offset.y - current.y) redraw:redraw];
	if (!copied)
		[self setNeedsDisplay:YES];
	/* A pinned header and the indicator each move a little: drawn with these
	 * (-uikitMoveSubview:toFrame:). */
	NSMutableArray *outer = _scrollRedraw;
	if (copied)
		_scrollRedraw = redraw;
	[self uikitDidScroll];
	if ([_delegate respondsToSelector:@selector(scrollViewDidScroll:)])
		[_delegate scrollViewDidScroll:self];
	_scrollRedraw = outer;
	if ([redraw count] > 0) {
		/* After the delegate and subclasses have laid out what came into
		 * view; the rest that changed (the indicator) goes with it, in one
		 * flush. */
		[window disableFlushWindow];
		/* Each rect is drawn from the opaque ancestor down: one that meets
		 * another (the edge of a bar in front, inside the strip that came
		 * into view) goes with it. */
		NSMutableArray *rects = [NSMutableArray array];
		for (NSValue *value in redraw) {
			NSRect rect = NSIntersectionRect([value rectValue], [self visibleRect]);
			if (NSIsEmptyRect(rect))
				continue;
			for (NSUInteger i = 0; i < [rects count];) {
				NSRect other = [[rects objectAtIndex:i] rectValue];
				NSRect both = NSUnionRect(rect, other);
				if (NSIntersectsRect(NSInsetRect(rect, -1, -1), other) &&
				    both.size.width * both.size.height <= rect.size.width * rect.size.height + other.size.width * other.size.height + both.size.width + both.size.height) {
					rect = both;
					[rects removeObjectAtIndex:i];
					i = 0;
				} else
					i++;
			}
			[rects addObject:[NSValue valueWithRect:rect]];
		}
		for (NSValue *value in rects)
			[self displayRect:[value rectValue]];
		[window displayIfNeeded];
		[window enableFlushWindow];
		[window flushWindow];
	}
}

/* Redraws rect: while a scroll that copied is being laid out, with the rects it draws, on
 * its own (as one invalid rect, AppKit's way, a pinned header and the indicator would span the
 * rows between them). Whole points: the indicator sits at a fraction. */
- (void)uikitRedrawRect:(NSRect)rect
{
	if (NSIsEmptyRect(rect))
		return;
	if (_scrollRedraw != nil)
		[_scrollRedraw addObject:[NSValue valueWithRect:NSIntegralRect(rect)]];
	else
		[self setNeedsDisplayInRect:rect];
}

- (void)uikitMoveSubview:(UIView *)view toFrame:(NSRect)frame
{
	NSRect old = [view frame];
	if (NSEqualRects(old, frame))
		return;
	[view uikitSetFrameQuietly:frame];
	if ([view superview] == self && ![view isHidden] && [self window] != nil) {
		[self uikitRedrawRect:old];
		[self uikitRedrawRect:frame];
	}
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
- (BOOL)uikitDrawingScrollsWithContent
{
	return NO;
}

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
	[self uikitMoveSubview:_indicator toFrame:NSMakeRect(NSMaxX(bounds) - 6, y + 2, 3, height - 4)];
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

/* UIScroller tuning that has no effect here. */
- (void)setFixedBackgroundPattern:(BOOL)fixed {}
- (void)setScrollerIndicatorStyle:(UIScrollViewIndicatorStyle)style { [self setIndicatorStyle:style]; }
- (void)setDirectionalScrolling:(BOOL)directional { [self setDirectionalLockEnabled:directional]; }
- (void)setScrollDecelerationFactor:(CGFloat)factor {}
- (void)setScrollHysteresis:(CGFloat)hysteresis {}
- (void)setThumbDetectionEnabled:(BOOL)enabled {}
- (void)setEventMode:(int)mode {}

@end
