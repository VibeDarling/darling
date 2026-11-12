/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIStepper.h>
#import <UIKit/UITouch.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSGraphicsContext.h>
#import "UIKitPrivate.h"

@implementation UIStepper {
	double _value, _minimum, _maximum, _step;
	BOOL _continuous, _autorepeat, _wraps;
	/* -1 for minus, 1 for plus, 0 for neither: the half being pressed. */
	int _pressed;
	NSTimer *_repeat;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	frame.size = CGSizeMake(94, 32);
	if ((self = [super initWithFrame:frame])) {
		_maximum = 100;
		_step = 1;
		_continuous = YES;
		_autorepeat = YES;
	}
	return self;
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	_maximum = 100;
	_step = 1;
	_continuous = YES;
	_autorepeat = YES;
	if ([coder containsValueForKey:@"UIMinimumValue"])
		_minimum = [coder decodeDoubleForKey:@"UIMinimumValue"];
	if ([coder containsValueForKey:@"UIMaximumValue"])
		_maximum = [coder decodeDoubleForKey:@"UIMaximumValue"];
	if ([coder containsValueForKey:@"UIStepValue"])
		_step = [coder decodeDoubleForKey:@"UIStepValue"];
	if ([coder containsValueForKey:@"UIValue"])
		_value = [coder decodeDoubleForKey:@"UIValue"];
	if ([coder containsValueForKey:@"UIAutorepeat"])
		_autorepeat = [coder decodeBoolForKey:@"UIAutorepeat"];
	if ([coder containsValueForKey:@"UIContinuous"])
		_continuous = [coder decodeBoolForKey:@"UIContinuous"];
	_wraps = [coder decodeBoolForKey:@"UIWraps"];
}

- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(94, 32); }
- (NSSize)intrinsicContentSize { return NSMakeSize(94, 32); }

- (double)value { return _value; }
- (double)minimumValue { return _minimum; }
- (double)maximumValue { return _maximum; }
- (double)stepValue { return _step; }
- (BOOL)isContinuous { return _continuous; }
- (void)setContinuous:(BOOL)continuous { _continuous = continuous; }
- (BOOL)autorepeat { return _autorepeat; }
- (void)setAutorepeat:(BOOL)autorepeat { _autorepeat = autorepeat; }
- (BOOL)wraps { return _wraps; }
- (void)setWraps:(BOOL)wraps { _wraps = wraps; }

- (void)setValue:(double)value
{
	_value = MIN(MAX(value, _minimum), _maximum);
	[self setNeedsDisplay:YES];
}

- (void)setMinimumValue:(double)minimum
{
	if (minimum >= _maximum)
		[NSException raise:NSInvalidArgumentException format:@"UIStepper: minimumValue must be less than maximumValue"];
	_minimum = minimum;
	[self setValue:_value];
}

- (void)setMaximumValue:(double)maximum
{
	if (maximum <= _minimum)
		[NSException raise:NSInvalidArgumentException format:@"UIStepper: maximumValue must be greater than minimumValue"];
	_maximum = maximum;
	[self setValue:_value];
}

- (void)setStepValue:(double)step
{
	if (step <= 0)
		[NSException raise:NSInvalidArgumentException format:@"UIStepper: stepValue must be greater than 0"];
	_step = step;
}

- (void)setIncrementImage:(UIImage *)image forState:(UIControlState)state { }
- (void)setDecrementImage:(UIImage *)image forState:(UIControlState)state { }
- (void)setDividerImage:(UIImage *)image forLeftSegmentState:(UIControlState)leftState rightSegmentState:(UIControlState)rightState { }
- (void)setBackgroundImage:(UIImage *)image forState:(UIControlState)state { }

/* One step, or round to the other end when it wraps. Answers whether the
   value changed. */
- (BOOL)uikitStep:(int)direction
{
	double old = _value;
	double next = _value + direction * _step;
	if (next > _maximum)
		next = _wraps ? _minimum : _maximum;
	else if (next < _minimum)
		next = _wraps ? _maximum : _minimum;
	[self setValue:next];
	if (_value == old)
		return NO;
	if (_continuous || _repeat == nil)
		[self sendActionsForControlEvents:UIControlEventValueChanged];
	return YES;
}

- (void)uikitRepeat:(NSTimer *)timer
{
	if (![self uikitStep:_pressed])
		[self uikitStopRepeating];
	else if ([timer timeInterval] > 0.15) {
		[timer invalidate];
		_repeat = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(uikitRepeat:) userInfo:nil repeats:YES];
	}
}

- (void)uikitStopRepeating
{
	[_repeat invalidate];
	_repeat = nil;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGPoint point = [[touches anyObject] locationInView:self];
	_pressed = point.x < [self bounds].size.width / 2 ? -1 : 1;
	[super touchesBegan:touches withEvent:event];
	if (![self isEnabled])
		return;
	[self uikitStep:_pressed];
	if (_autorepeat)
		_repeat = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(uikitRepeat:) userInfo:nil repeats:YES];
	[self setNeedsDisplay:YES];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	BOOL repeated = _repeat != nil && !_continuous;
	[self uikitStopRepeating];
	_pressed = 0;
	[super touchesEnded:touches withEvent:event];
	if (repeated)
		[self sendActionsForControlEvents:UIControlEventValueChanged];
	[self setNeedsDisplay:YES];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self uikitStopRepeating];
	_pressed = 0;
	[super touchesCancelled:touches withEvent:event];
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = NSInsetRect([self bounds], 0.5, 0.5);
	CGFloat half = bounds.size.width / 2;
	NSColor *tint = [self isEnabled] ? UIKitTintColor() : [NSColor colorWithCalibratedWhite:0.7 alpha:1];
	NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:8 yRadius:8];
	if (_pressed != 0) {
		[NSGraphicsContext saveGraphicsState];
		[outline addClip];
		[[tint colorWithAlphaComponent:0.15] setFill];
		NSRectFill(NSMakeRect(_pressed < 0 ? bounds.origin.x : bounds.origin.x + half, bounds.origin.y, half, bounds.size.height));
		[NSGraphicsContext restoreGraphicsState];
	}
	[tint setStroke];
	[outline setLineWidth:1];
	[outline stroke];
	NSRectFill(NSMakeRect(NSMidX(bounds) - 0.5, bounds.origin.y, 1, bounds.size.height));
	CGFloat midY = NSMidY(bounds);
	/* Minus and plus, dimmed where the value is at that end. */
	BOOL canDecrement = _wraps || _value > _minimum, canIncrement = _wraps || _value < _maximum;
	[(canDecrement ? tint : [tint colorWithAlphaComponent:0.35]) setFill];
	NSRectFill(NSMakeRect(bounds.origin.x + half / 2 - 7, midY - 1, 14, 2));
	[(canIncrement ? tint : [tint colorWithAlphaComponent:0.35]) setFill];
	NSRectFill(NSMakeRect(bounds.origin.x + half * 1.5 - 7, midY - 1, 14, 2));
	NSRectFill(NSMakeRect(bounds.origin.x + half * 1.5 - 1, midY - 7, 2, 14));
}

@end
