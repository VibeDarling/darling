/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIControl.h>
#import <UIKit/UITextField.h>
#import <UIKit/UILabel.h>
#import <UIKit/UIImageView.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIImage.h>
#import <UIKit/UITouch.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSTextFieldCell.h>
#import <AppKit/NSSecureTextField.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSText.h>
#import <objc/message.h>
#import "UIKitPrivate.h"

#pragma mark - UIControl

@interface UIKitControlTarget : NSObject {
@public
	__weak id target;
	SEL action;
	UIControlEvents events;
}
@end

@implementation UIKitControlTarget
@end

@implementation UIControl {
	NSMutableArray<UIKitControlTarget *> *_targets;
	BOOL _disabled;
	BOOL _selected;
	BOOL _highlighted;
	BOOL _tracking;
	BOOL _touchInside;
}

@synthesize contentHorizontalAlignment = _contentHorizontalAlignment;
@synthesize contentVerticalAlignment = _contentVerticalAlignment;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
		_targets = [NSMutableArray array];
	return self;
}

- (BOOL)isEnabled { return !_disabled; }
- (void)setEnabled:(BOOL)enabled { _disabled = !enabled; [self setNeedsDisplay:YES]; }
- (BOOL)isSelected { return _selected; }
- (void)setSelected:(BOOL)selected { _selected = selected; [self setNeedsDisplay:YES]; }
- (BOOL)isHighlighted { return _highlighted; }
- (void)setHighlighted:(BOOL)highlighted { _highlighted = highlighted; [self setNeedsDisplay:YES]; }
- (BOOL)isTracking { return _tracking; }
- (BOOL)isTouchInside { return _touchInside; }

- (UIControlState)state
{
	UIControlState state = UIControlStateNormal;
	if (_highlighted)
		state |= UIControlStateHighlighted;
	if (_disabled)
		state |= UIControlStateDisabled;
	if (_selected)
		state |= UIControlStateSelected;
	return state;
}

- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)events
{
	if (action == NULL)
		return;
	UIKitControlTarget *entry = [[UIKitControlTarget alloc] init];
	entry->target = target;
	entry->action = action;
	entry->events = events;
	[_targets addObject:entry];
}

- (void)addTarget:(id)target action:(SEL)action forEvents:(NSInteger)events
{
	/* iPhone OS 2's mouse-up event is touch up inside. */
	UIControlEvents mapped = (UIControlEvents)events;
	if (events & 64)
		mapped |= UIControlEventTouchUpInside;
	[self addTarget:target action:action forControlEvents:mapped];
}

- (void)removeTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)events
{
	for (UIKitControlTarget *entry in [_targets copy]) {
		if ((target == nil || entry->target == target) && (action == NULL || entry->action == action)) {
			entry->events &= ~events;
			if (entry->events == 0)
				[_targets removeObject:entry];
		}
	}
}

- (NSSet *)allTargets
{
	NSMutableSet *targets = [NSMutableSet set];
	for (UIKitControlTarget *entry in _targets)
		if (entry->target != nil)
			[targets addObject:entry->target];
	return targets;
}

- (UIControlEvents)allControlEvents
{
	UIControlEvents events = 0;
	for (UIKitControlTarget *entry in _targets)
		events |= entry->events;
	return events;
}

- (NSArray *)actionsForTarget:(id)target forControlEvent:(UIControlEvents)event
{
	NSMutableArray *actions = [NSMutableArray array];
	for (UIKitControlTarget *entry in _targets)
		if (entry->target == target && (entry->events & event))
			[actions addObject:NSStringFromSelector(entry->action)];
	return [actions count] > 0 ? actions : nil;
}

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event
{
	if (target == nil || ![target respondsToSelector:action])
		return;
	NSMethodSignature *signature = [target methodSignatureForSelector:action];
	if ([signature numberOfArguments] <= 2)
		((void (*)(id, SEL))objc_msgSend)(target, action);
	else if ([signature numberOfArguments] == 3)
		((void (*)(id, SEL, id))objc_msgSend)(target, action, self);
	else
		((void (*)(id, SEL, id, id))objc_msgSend)(target, action, self, event);
}

- (void)sendActionsForControlEvents:(UIControlEvents)events
{
	for (UIKitControlTarget *entry in [_targets copy])
		if (entry->events & events)
			[self sendAction:entry->action to:entry->target forEvent:nil];
}

- (BOOL)uikitTouchIsInside:(NSSet *)touches
{
	CGPoint point = [[touches anyObject] locationInView:self];
	return NSPointInRect(NSMakePoint(point.x, point.y), NSInsetRect([self bounds], -30, -30));
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (_disabled)
		return;
	_tracking = YES;
	_touchInside = YES;
	[self setHighlighted:YES];
	[self sendActionsForControlEvents:UIControlEventTouchDown];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!_tracking)
		return;
	BOOL inside = [self uikitTouchIsInside:touches];
	if (inside != _touchInside) {
		_touchInside = inside;
		[self setHighlighted:inside];
		[self sendActionsForControlEvents:inside ? UIControlEventTouchDragEnter : UIControlEventTouchDragExit];
	}
	[self sendActionsForControlEvents:inside ? UIControlEventTouchDragInside : UIControlEventTouchDragOutside];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!_tracking)
		return;
	_tracking = NO;
	BOOL inside = [self uikitTouchIsInside:touches];
	[self setHighlighted:NO];
	if (inside)
		[self uikitTapped];
	[self sendActionsForControlEvents:inside ? UIControlEventTouchUpInside : UIControlEventTouchUpOutside];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	_tracking = NO;
	[self setHighlighted:NO];
	[self sendActionsForControlEvents:UIControlEventTouchCancel];
}

/* What a tap changes before the actions are sent (switches toggle). */
- (void)uikitTapped
{
}

@end

#pragma mark - UIButton

@implementation UIButton {
	UIButtonType _buttonType;
	UILabel *_titleLabel;
	UIImageView *_imageView;
	NSMutableDictionary<NSNumber *, NSString *> *_titles;
	NSMutableDictionary<NSNumber *, UIColor *> *_titleColors;
	NSMutableDictionary<NSNumber *, UIImage *> *_images;
	NSMutableDictionary<NSNumber *, UIImage *> *_backgroundImages;
}

@synthesize contentEdgeInsets = _contentEdgeInsets;
@synthesize titleEdgeInsets = _titleEdgeInsets;
@synthesize imageEdgeInsets = _imageEdgeInsets;
@synthesize showsTouchWhenHighlighted = _showsTouchWhenHighlighted;
@synthesize adjustsImageWhenHighlighted = _adjustsImageWhenHighlighted;

+ (instancetype)buttonWithType:(UIButtonType)buttonType
{
	UIButton *button = [[self alloc] initWithFrame:CGRectZero];
	button->_buttonType = buttonType;
	if (buttonType != UIButtonTypeCustom)
		[button setTitleColor:[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1] forState:UIControlStateNormal];
	if (buttonType == UIButtonTypeContactAdd)
		[button setTitle:@"+" forState:UIControlStateNormal];
	else if (buttonType == UIButtonTypeInfoLight || buttonType == UIButtonTypeInfoDark || buttonType == UIButtonTypeDetailDisclosure)
		[button setTitle:@"ⓘ" forState:UIControlStateNormal];
	if (buttonType != UIButtonTypeCustom && buttonType != UIButtonTypeRoundedRect)
		[button setFrame:NSMakeRect(0, 0, 22, 22)];
	return button;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_titles = [NSMutableDictionary dictionary];
		_titleColors = [NSMutableDictionary dictionary];
		_images = [NSMutableDictionary dictionary];
		_backgroundImages = [NSMutableDictionary dictionary];
		_adjustsImageWhenHighlighted = YES;
		_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_titleLabel setTextAlignment:NSTextAlignmentCenter];
		[_titleLabel setFont:[UIFont systemFontOfSize:15]];
		[_titleLabel setTextColor:[UIColor whiteColor]];
		[self addSubview:_titleLabel];
		_imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
		[self addSubview:_imageView];
	}
	return self;
}

- (UIButtonType)buttonType { return _buttonType; }
- (UILabel *)titleLabel { return _titleLabel; }
- (UIImageView *)imageView { return _imageView; }
- (UIFont *)font { return [_titleLabel font]; }
- (void)setFont:(UIFont *)font { [_titleLabel setFont:font]; }

static id UIKitValueForState(NSDictionary *values, UIControlState state)
{
	return [values objectForKey:@(state)] ?: [values objectForKey:@(state & UIControlStateSelected)] ?: [values objectForKey:@(UIControlStateNormal)];
}

- (NSString *)titleForState:(UIControlState)state { return UIKitValueForState(_titles, state); }
- (UIColor *)titleColorForState:(UIControlState)state { return UIKitValueForState(_titleColors, state); }
- (UIImage *)imageForState:(UIControlState)state { return UIKitValueForState(_images, state); }
- (UIImage *)backgroundImageForState:(UIControlState)state { return UIKitValueForState(_backgroundImages, state); }
- (NSString *)currentTitle { return [self titleForState:[self state]]; }
- (UIColor *)currentTitleColor { return [self titleColorForState:[self state]]; }
- (UIImage *)currentImage { return [self imageForState:[self state]]; }
- (UIImage *)currentBackgroundImage { return [self backgroundImageForState:[self state]]; }

static void UIKitSetForState(NSMutableDictionary *values, id value, UIControlState state)
{
	if (value != nil)
		[values setObject:value forKey:@(state)];
	else
		[values removeObjectForKey:@(state)];
}

- (void)setTitle:(NSString *)title forState:(UIControlState)state { UIKitSetForState(_titles, [title copy], state); [self updateContent]; }
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state { UIKitSetForState(_titleColors, color, state); [self updateContent]; }
- (void)setTitleShadowColor:(UIColor *)color forState:(UIControlState)state { }
- (void)setImage:(UIImage *)image forState:(UIControlState)state { UIKitSetForState(_images, image, state); [self updateContent]; }
- (void)setBackgroundImage:(UIImage *)image forState:(UIControlState)state { UIKitSetForState(_backgroundImages, image, state); [self updateContent]; }

- (void)updateContent
{
	[_titleLabel setText:[self currentTitle]];
	UIColor *color = [self currentTitleColor] ?: [UIColor whiteColor];
	if ([self isHighlighted] && [_titleColors objectForKey:@(UIControlStateHighlighted)] == nil)
		color = [color colorWithAlphaComponent:0.3];
	if (![self isEnabled])
		color = [color colorWithAlphaComponent:0.35];
	[_titleLabel setTextColor:color];
	[_imageView setImage:[self currentImage]];
	[self setNeedsLayout];
	[self setNeedsDisplay:YES];
}

- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; [self updateContent]; }
- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; [self updateContent]; }
- (void)setSelected:(BOOL)selected { [super setSelected:selected]; [self updateContent]; }

- (CGSize)sizeThatFits:(CGSize)size
{
	CGSize title = [[self currentTitle] sizeWithFont:[_titleLabel font]];
	CGSize image = [self currentImage] != nil ? [[self currentImage] size] : CGSizeZero;
	return CGSizeMake(title.width + image.width + _contentEdgeInsets.left + _contentEdgeInsets.right + 8,
	                  MAX(title.height, image.height) + _contentEdgeInsets.top + _contentEdgeInsets.bottom + 8);
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect bounds = UIEdgeInsetsInsetRect(NSRectToCGRect([self bounds]), _contentEdgeInsets);
	UIImage *image = [self currentImage];
	CGSize imageSize = image != nil ? [image size] : CGSizeZero;
	CGSize titleSize = [[self currentTitle] length] > 0 ? [[self currentTitle] sizeWithFont:[_titleLabel font]] : CGSizeZero;
	CGFloat total = imageSize.width + titleSize.width;
	CGFloat x = bounds.origin.x + (bounds.size.width - total) / 2;
	if ([self contentHorizontalAlignment] == UIControlContentHorizontalAlignmentLeft)
		x = bounds.origin.x;
	else if ([self contentHorizontalAlignment] == UIControlContentHorizontalAlignmentRight)
		x = CGRectGetMaxX(bounds) - total;
	[_imageView setFrame:NSMakeRect(floor(x), floor(CGRectGetMidY(bounds) - imageSize.height / 2), imageSize.width, imageSize.height)];
	[_titleLabel setFrame:NSMakeRect(floor(x + imageSize.width), floor(CGRectGetMidY(bounds) - titleSize.height / 2), ceil(titleSize.width) + 1, ceil(titleSize.height))];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	UIImage *background = [self currentBackgroundImage];
	if (background != nil)
		[background drawInRect:NSRectToCGRect([self bounds])];
}

@end

#pragma mark - UISwitch

@implementation UISwitch {
	BOOL _on;
}

@synthesize onTintColor = _onTintColor;

- (instancetype)initWithFrame:(CGRect)frame
{
	frame.size = CGSizeMake(51, 31);
	return [super initWithFrame:frame];
}

- (BOOL)isOn { return _on; }
- (void)setOn:(BOOL)on { _on = on; [self setNeedsDisplay:YES]; }
- (void)setOn:(BOOL)on animated:(BOOL)animated { [self setOn:on]; }

- (CGSize)sizeThatFits:(CGSize)size
{
	return CGSizeMake(51, 31);
}

- (void)uikitTapped
{
	[self setOn:!_on];
	[self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)drawRect:(NSRect)rect
{
	NSRect track = NSMakeRect(0.5, 0.5, 50, 30);
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:track xRadius:15 yRadius:15];
	NSColor *on = _onTintColor != nil ? [_onTintColor nsColor] : [NSColor colorWithCalibratedRed:0.3 green:0.85 blue:0.39 alpha:1];
	[(_on ? on : [NSColor colorWithCalibratedWhite:0.9 alpha:1]) setFill];
	[path fill];
	NSRect knob = NSMakeRect(_on ? 21 : 1.5, 1.5, 28, 28);
	[[NSColor whiteColor] setFill];
	NSBezierPath *knobPath = [NSBezierPath bezierPathWithOvalInRect:knob];
	[knobPath fill];
	[[NSColor colorWithCalibratedWhite:0.75 alpha:1] setStroke];
	[knobPath stroke];
	if ([self alpha] < 1 || ![self isEnabled]) {
		[[NSColor colorWithCalibratedWhite:1 alpha:0.5] setFill];
		[path fill];
	}
}

@end

#pragma mark - UISegmentedControl

@interface UIKitSegment : NSObject {
@public
	NSString *title;
	UIImage *image;
	BOOL disabled;
	CGFloat width;
}
@end

@implementation UIKitSegment
@end

@implementation UISegmentedControl {
	NSMutableArray<UIKitSegment *> *_segments;
	NSInteger _selected;
	NSInteger _pressed;
	BOOL _momentary;
}

@synthesize segmentedControlStyle = _segmentedControlStyle;
@synthesize tintColor = _tintColor;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_segments = [NSMutableArray array];
		_selected = UISegmentedControlNoSegment;
		_pressed = -1;
	}
	return self;
}

- (instancetype)initWithItems:(NSArray *)items
{
	if ((self = [self initWithFrame:CGRectMake(0, 0, MAX(1, [items count]) * 72, 29)])) {
		for (id item in items) {
			UIKitSegment *segment = [[UIKitSegment alloc] init];
			if ([item isKindOfClass:[UIImage class]])
				segment->image = item;
			else
				segment->title = [[item description] copy];
			[_segments addObject:segment];
		}
	}
	return self;
}

- (NSUInteger)numberOfSegments { return [_segments count]; }
- (NSInteger)selectedSegmentIndex { return _selected; }
- (void)setSelectedSegmentIndex:(NSInteger)index { _selected = index; [self setNeedsDisplay:YES]; }
- (BOOL)isMomentary { return _momentary; }
- (void)setMomentary:(BOOL)momentary { _momentary = momentary; }

- (UIKitSegment *)segmentAtIndex:(NSUInteger)index
{
	return index < [_segments count] ? [_segments objectAtIndex:index] : nil;
}

- (void)insertSegmentWithTitle:(NSString *)title atIndex:(NSUInteger)index animated:(BOOL)animated
{
	UIKitSegment *segment = [[UIKitSegment alloc] init];
	segment->title = [title copy];
	[_segments insertObject:segment atIndex:MIN(index, [_segments count])];
	[self setNeedsDisplay:YES];
}

- (void)insertSegmentWithImage:(UIImage *)image atIndex:(NSUInteger)index animated:(BOOL)animated
{
	UIKitSegment *segment = [[UIKitSegment alloc] init];
	segment->image = image;
	[_segments insertObject:segment atIndex:MIN(index, [_segments count])];
	[self setNeedsDisplay:YES];
}

- (void)removeSegmentAtIndex:(NSUInteger)index animated:(BOOL)animated
{
	if (index < [_segments count])
		[_segments removeObjectAtIndex:index];
	if (_selected >= (NSInteger)[_segments count])
		_selected = UISegmentedControlNoSegment;
	[self setNeedsDisplay:YES];
}

- (void)removeAllSegments
{
	[_segments removeAllObjects];
	_selected = UISegmentedControlNoSegment;
	[self setNeedsDisplay:YES];
}

- (void)setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)index { [self segmentAtIndex:index]->title = [title copy]; [self setNeedsDisplay:YES]; }
- (NSString *)titleForSegmentAtIndex:(NSUInteger)index { return [self segmentAtIndex:index]->title; }
- (void)setImage:(UIImage *)image forSegmentAtIndex:(NSUInteger)index { [self segmentAtIndex:index]->image = image; [self setNeedsDisplay:YES]; }
- (UIImage *)imageForSegmentAtIndex:(NSUInteger)index { return [self segmentAtIndex:index]->image; }
- (void)setEnabled:(BOOL)enabled forSegmentAtIndex:(NSUInteger)index { [self segmentAtIndex:index]->disabled = !enabled; [self setNeedsDisplay:YES]; }
- (BOOL)isEnabledForSegmentAtIndex:(NSUInteger)index { return ![self segmentAtIndex:index]->disabled; }
- (void)setWidth:(CGFloat)width forSegmentAtIndex:(NSUInteger)index { [self segmentAtIndex:index]->width = width; [self setNeedsDisplay:YES]; }

- (NSRect)rectForSegment:(NSUInteger)index
{
	NSRect bounds = [self bounds];
	CGFloat width = [_segments count] > 0 ? bounds.size.width / [_segments count] : bounds.size.width;
	return NSMakeRect(floor(index * width), 0, floor(width), bounds.size.height);
}

- (void)drawRect:(NSRect)rect
{
	NSColor *tint = _tintColor != nil ? [_tintColor nsColor] : UIKitTintColor();
	NSRect bounds = NSInsetRect([self bounds], 0.5, 0.5);
	NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:4 yRadius:4];
	[[NSColor whiteColor] setFill];
	[outline fill];
	for (NSUInteger i = 0; i < [_segments count]; i++) {
		UIKitSegment *segment = [_segments objectAtIndex:i];
		NSRect cell = [self rectForSegment:i];
		BOOL selected = (NSInteger)i == _selected || (NSInteger)i == _pressed;
		if (selected) {
			[NSGraphicsContext saveGraphicsState];
			[outline addClip];
			[((NSInteger)i == _pressed && (NSInteger)i != _selected ? [tint colorWithAlphaComponent:0.2] : tint) setFill];
			NSRectFill(cell);
			[NSGraphicsContext restoreGraphicsState];
		}
		if (i > 0) {
			[tint setFill];
			NSRectFill(NSMakeRect(cell.origin.x, 0, 1, cell.size.height));
		}
		NSColor *color = (NSInteger)i == _selected ? [NSColor whiteColor] : tint;
		if (segment->disabled)
			color = [color colorWithAlphaComponent:0.4];
		if (segment->title != nil) {
			NSDictionary *attributes = @{ NSFontAttributeName: [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: color };
			NSSize size = [segment->title sizeWithAttributes:attributes];
			[segment->title drawAtPoint:NSMakePoint(floor(NSMidX(cell) - size.width / 2), floor(NSMidY(cell) - size.height / 2)) withAttributes:attributes];
		} else if (segment->image != nil) {
			CGSize size = [segment->image size];
			[segment->image drawInRect:CGRectMake(floor(NSMidX(cell) - size.width / 2), floor(NSMidY(cell) - size.height / 2), size.width, size.height)];
		}
	}
	[tint setStroke];
	[outline stroke];
}

- (NSInteger)segmentAtTouch:(NSSet *)touches
{
	CGPoint point = [[touches anyObject] locationInView:self];
	for (NSUInteger i = 0; i < [_segments count]; i++)
		if (NSPointInRect(NSMakePoint(point.x, point.y), [self rectForSegment:i]))
			return ((UIKitSegment *)[_segments objectAtIndex:i])->disabled ? -1 : (NSInteger)i;
	return -1;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (![self isEnabled])
		return;
	_pressed = [self segmentAtTouch:touches];
	[self setNeedsDisplay:YES];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSInteger index = [self segmentAtTouch:touches];
	BOOL fire = index >= 0 && index == _pressed;
	_pressed = -1;
	if (fire) {
		BOOL changed = index != _selected;
		_selected = _momentary ? UISegmentedControlNoSegment : index;
		if (changed || _momentary)
			[self sendActionsForControlEvents:UIControlEventValueChanged];
	}
	[self setNeedsDisplay:YES];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	_pressed = -1;
	[self setNeedsDisplay:YES];
}

@end

#pragma mark - UIActivityIndicatorView

@implementation UIActivityIndicatorView {
	UIActivityIndicatorViewStyle _style;
	BOOL _hidesWhenStopped;
	UIColor *_color;
	NSTimer *_timer;
	NSInteger _step;
}

- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style
{
	CGFloat size = style == UIActivityIndicatorViewStyleWhiteLarge ? 37 : style >= UIActivityIndicatorViewStyleWhiteSmall ? 16 : 20;
	if ((self = [super initWithFrame:CGRectMake(0, 0, size, size)])) {
		_style = style;
		_hidesWhenStopped = YES;
		[self setHidden:YES];
		[self setUserInteractionEnabled:NO];
	}
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [self initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite]))
		[self setFrame:frame];
	return self;
}

- (void)dealloc
{
	[_timer invalidate];
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle { return _style; }
- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)style { _style = style; [self setNeedsDisplay:YES]; }
- (BOOL)hidesWhenStopped { return _hidesWhenStopped; }
- (void)setHidesWhenStopped:(BOOL)hides { _hidesWhenStopped = hides; if (_timer == nil) [self setHidden:hides]; }
- (UIColor *)color { return _color; }
- (void)setColor:(UIColor *)color { _color = color; [self setNeedsDisplay:YES]; }
- (BOOL)isAnimating { return _timer != nil; }

- (void)startAnimating
{
	if (_timer != nil)
		return;
	[self setHidden:NO];
	_timer = [NSTimer timerWithTimeInterval:1.0 / 12 target:self selector:@selector(advance:) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stopAnimating
{
	[_timer invalidate];
	_timer = nil;
	if (_hidesWhenStopped)
		[self setHidden:YES];
	[self setNeedsDisplay:YES];
}

- (void)advance:(NSTimer *)timer
{
	_step = (_step + 1) % 12;
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	CGFloat radius = MIN(bounds.size.width, bounds.size.height) / 2;
	NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
	NSColor *base = _color != nil ? [_color nsColor] :
		(_style == UIActivityIndicatorViewStyleGray || _style == UIActivityIndicatorViewStyleGraySmall) ? [NSColor grayColor] : [NSColor whiteColor];
	for (NSInteger i = 0; i < 12; i++) {
		CGFloat angle = (i * 30.0) * M_PI / 180;
		NSBezierPath *spoke = [NSBezierPath bezierPath];
		[spoke moveToPoint:NSMakePoint(center.x + cos(angle) * radius * 0.5, center.y + sin(angle) * radius * 0.5)];
		[spoke lineToPoint:NSMakePoint(center.x + cos(angle) * radius * 0.95, center.y + sin(angle) * radius * 0.95)];
		[spoke setLineWidth:MAX(2, radius / 5)];
		[spoke setLineCapStyle:NSRoundLineCapStyle];
		CGFloat alpha = 0.2 + 0.8 * ((i - _step + 12) % 12) / 11.0;
		[[base colorWithAlphaComponent:alpha] setStroke];
		[spoke stroke];
	}
}

@end

#pragma mark - UITextField

@interface UITextField () <NSTextFieldDelegate>
@end

@implementation UITextField {
	NSTextField *_field;
	UIFont *_font;
	UIColor *_textColor;
	UITextBorderStyle _borderStyle;
	UIView *_leftView;
	UIView *_rightView;
	BOOL _editing;
	BOOL _secure;
}

@synthesize delegate = _delegate;
@synthesize clearsOnBeginEditing = _clearsOnBeginEditing;
@synthesize clearButtonMode = _clearButtonMode;
@synthesize leftViewMode = _leftViewMode;
@synthesize rightViewMode = _rightViewMode;
@synthesize background = _background;
@synthesize adjustsFontSizeToFitWidth = _adjustsFontSizeToFitWidth;
@synthesize minimumFontSize = _minimumFontSize;
@synthesize autocapitalizationType = _autocapitalizationType;
@synthesize autocorrectionType = _autocorrectionType;
@synthesize spellCheckingType = _spellCheckingType;
@synthesize keyboardType = _keyboardType;
@synthesize keyboardAppearance = _keyboardAppearance;
@synthesize returnKeyType = _returnKeyType;
@synthesize enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_font = [UIFont systemFontOfSize:17];
		_textColor = [UIColor blackColor];
		[self makeField:NO];
	}
	return self;
}

- (void)makeField:(BOOL)secure
{
	NSString *text = [_field stringValue];
	NSString *placeholder = [[_field cell] placeholderString];
	[_field removeFromSuperview];
	Class cls = secure ? [NSSecureTextField class] : [NSTextField class];
	_field = [[cls alloc] initWithFrame:NSZeroRect];
	[_field setBezeled:NO];
	[_field setBordered:NO];
	[_field setDrawsBackground:NO];
	[_field setEditable:YES];
	[_field setSelectable:YES];
	[_field setDelegate:self];
	[_field setTarget:self];
	[_field setAction:@selector(fieldReturned:)];
	[_field setFont:[_font nsFont]];
	[_field setTextColor:[_textColor nsColor]];
	[_field setStringValue:text ?: @""];
	if (placeholder != nil)
		[[_field cell] setPlaceholderString:placeholder];
	[[_field cell] setScrollable:YES];
	[self addSubview:_field];
	[self setNeedsLayout];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	NSRect bounds = [self bounds];
	CGFloat left = _borderStyle == UITextBorderStyleNone ? 0 : 7;
	CGFloat right = left;
	if (_leftView != nil && _leftViewMode != UITextFieldViewModeNever) {
		NSRect frame = [_leftView frame];
		frame.origin = NSMakePoint(left, floor((bounds.size.height - frame.size.height) / 2));
		[_leftView setFrame:frame];
		left += frame.size.width + 4;
	}
	if (_rightView != nil && _rightViewMode != UITextFieldViewModeNever) {
		NSRect frame = [_rightView frame];
		frame.origin = NSMakePoint(bounds.size.width - right - frame.size.width, floor((bounds.size.height - frame.size.height) / 2));
		[_rightView setFrame:frame];
		right += frame.size.width + 4;
	}
	CGFloat height = MIN(bounds.size.height, ceil([[_font nsFont] ascender] - [[_font nsFont] descender]) + 4);
	[_field setFrame:NSMakeRect(left, floor((bounds.size.height - height) / 2), MAX(0, bounds.size.width - left - right), height)];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	NSRect bounds = NSInsetRect([self bounds], 0.5, 0.5);
	if (_background != nil) {
		[_background drawInRect:NSRectToCGRect([self bounds])];
	} else if (_borderStyle == UITextBorderStyleRoundedRect) {
		NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:5 yRadius:5];
		[[NSColor whiteColor] setFill];
		[path fill];
		[[NSColor colorWithCalibratedWhite:0.8 alpha:1] setStroke];
		[path stroke];
	} else if (_borderStyle == UITextBorderStyleLine || _borderStyle == UITextBorderStyleBezel) {
		[[NSColor colorWithCalibratedWhite:0.6 alpha:1] setStroke];
		[NSBezierPath strokeRect:bounds];
	}
}

- (NSString *)text { return [_field stringValue]; }
- (void)setText:(NSString *)text { [_field setStringValue:text ?: @""]; }
- (NSString *)placeholder { return [[_field cell] placeholderString]; }
- (void)setPlaceholder:(NSString *)placeholder { [[_field cell] setPlaceholderString:placeholder ?: @""]; }
- (UIFont *)font { return _font; }
- (void)setFont:(UIFont *)font { _font = font ?: [UIFont systemFontOfSize:17]; [_field setFont:[_font nsFont]]; [self setNeedsLayout]; }
- (UIColor *)textColor { return _textColor; }
- (void)setTextColor:(UIColor *)color { _textColor = color ?: [UIColor blackColor]; [_field setTextColor:[_textColor nsColor]]; }
- (NSTextAlignment)textAlignment { return [_field alignment]; }
- (void)setTextAlignment:(NSTextAlignment)alignment { [_field setAlignment:alignment]; }
- (UITextBorderStyle)borderStyle { return _borderStyle; }
- (void)setBorderStyle:(UITextBorderStyle)style { _borderStyle = style; [self setNeedsLayout]; [self setNeedsDisplay:YES]; }
- (UIView *)leftView { return _leftView; }
- (void)setLeftView:(UIView *)view { [_leftView removeFromSuperview]; _leftView = view; if (view) [self addSubview:view]; [self setNeedsLayout]; }
- (UIView *)rightView { return _rightView; }
- (void)setRightView:(UIView *)view { [_rightView removeFromSuperview]; _rightView = view; if (view) [self addSubview:view]; [self setNeedsLayout]; }
- (BOOL)isEditing { return _editing; }
- (BOOL)isSecureTextEntry { return _secure; }

- (void)setSecureTextEntry:(BOOL)secure
{
	if (secure == _secure)
		return;
	_secure = secure;
	[self makeField:secure];
}

- (id<UITextInputTraits>)textInputTraits
{
	return self;
}

- (BOOL)canBecomeFirstResponder
{
	return [self isEnabled];
}

- (BOOL)becomeFirstResponder
{
	if ([_delegate respondsToSelector:@selector(textFieldShouldBeginEditing:)] && ![_delegate textFieldShouldBeginEditing:self])
		return NO;
	return [[self window] makeFirstResponder:_field];
}

- (BOOL)resignFirstResponder
{
	if (!_editing)
		return YES;
	NSWindow *window = [self window];
	return [window makeFirstResponder:window];
}

- (BOOL)isFirstResponder
{
	return _editing;
}

- (void)controlTextDidBeginEditing:(NSNotification *)notification
{
	_editing = YES;
	if (_clearsOnBeginEditing)
		[_field setStringValue:@""];
	if ([_delegate respondsToSelector:@selector(textFieldDidBeginEditing:)])
		[_delegate textFieldDidBeginEditing:self];
	[self sendActionsForControlEvents:UIControlEventEditingDidBegin];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"UITextFieldTextDidBeginEditingNotification" object:self];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	[self sendActionsForControlEvents:UIControlEventEditingChanged];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"UITextFieldTextDidChangeNotification" object:self];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	if (!_editing)
		return;
	_editing = NO;
	if ([_delegate respondsToSelector:@selector(textFieldDidEndEditing:)])
		[_delegate textFieldDidEndEditing:self];
	[self sendActionsForControlEvents:UIControlEventEditingDidEnd];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"UITextFieldTextDidEndEditingNotification" object:self];
}

/* Return in the field. */
- (void)fieldReturned:(id)sender
{
	if ([_delegate respondsToSelector:@selector(textFieldShouldReturn:)])
		[_delegate textFieldShouldReturn:self];
	[self sendActionsForControlEvents:UIControlEventEditingDidEndOnExit];
}

@end

#pragma mark - UISearchBar

@interface UISearchBar () <UITextFieldDelegate>
@end

@implementation UISearchBar {
	UITextField *_field;
	UIButton *_cancel;
	BOOL _showsCancelButton;
}

@synthesize delegate = _delegate;
@synthesize prompt = _prompt;
@synthesize showsBookmarkButton = _showsBookmarkButton;
@synthesize showsScopeBar = _showsScopeBar;
@synthesize scopeButtonTitles = _scopeButtonTitles;
@synthesize selectedScopeButtonIndex = _selectedScopeButtonIndex;
@synthesize barStyle = _barStyle;
@synthesize tintColor = _tintColor;
@synthesize barTintColor = _barTintColor;
@synthesize translucent = _translucent;

- (instancetype)initWithFrame:(CGRect)frame
{
	if (frame.size.height <= 0)
		frame.size.height = 44;
	if ((self = [super initWithFrame:frame])) {
		_field = [[UITextField alloc] initWithFrame:CGRectZero];
		[_field setBorderStyle:UITextBorderStyleRoundedRect];
		[_field setFont:[UIFont systemFontOfSize:14]];
		[_field setPlaceholder:@"Search"];
		[_field setDelegate:self];
		[_field addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingChanged];
		[self addSubview:_field];
		_cancel = [UIButton buttonWithType:UIButtonTypeRoundedRect];
		[_cancel setTitle:@"Cancel" forState:UIControlStateNormal];
		[_cancel addTarget:self action:@selector(cancelPressed:) forControlEvents:UIControlEventTouchUpInside];
	}
	return self;
}

- (UITextField *)searchField { return _field; }
- (NSString *)text { return [_field text]; }
- (void)setText:(NSString *)text { [_field setText:text]; }
- (NSString *)placeholder { return [_field placeholder]; }
- (void)setPlaceholder:(NSString *)placeholder { [_field setPlaceholder:placeholder]; }
- (BOOL)showsCancelButton { return _showsCancelButton; }

- (void)setShowsCancelButton:(BOOL)shows
{
	_showsCancelButton = shows;
	if (shows)
		[self addSubview:_cancel];
	else
		[_cancel removeFromSuperview];
	[self setNeedsLayout];
}

- (void)setShowsCancelButton:(BOOL)shows animated:(BOOL)animated { [self setShowsCancelButton:shows]; }

#define UIKIT_TRAIT(type, getter, setter) \
	- (type)getter { return [_field getter]; } \
	- (void)setter:(type)value { [_field setter:value]; }
UIKIT_TRAIT(UITextAutocapitalizationType, autocapitalizationType, setAutocapitalizationType)
UIKIT_TRAIT(UITextAutocorrectionType, autocorrectionType, setAutocorrectionType)
UIKIT_TRAIT(UITextSpellCheckingType, spellCheckingType, setSpellCheckingType)
UIKIT_TRAIT(UIKeyboardType, keyboardType, setKeyboardType)
UIKIT_TRAIT(UIKeyboardAppearance, keyboardAppearance, setKeyboardAppearance)
UIKIT_TRAIT(UIReturnKeyType, returnKeyType, setReturnKeyType)
UIKIT_TRAIT(BOOL, enablesReturnKeyAutomatically, setEnablesReturnKeyAutomatically)
#undef UIKIT_TRAIT
- (BOOL)isSecureTextEntry { return [_field isSecureTextEntry]; }
- (void)setSecureTextEntry:(BOOL)secure { [_field setSecureTextEntry:secure]; }

- (BOOL)becomeFirstResponder { return [_field becomeFirstResponder]; }
- (BOOL)resignFirstResponder { return [_field resignFirstResponder]; }
- (BOOL)isFirstResponder { return [_field isFirstResponder]; }

- (CGSize)sizeThatFits:(CGSize)size
{
	return CGSizeMake(size.width, 44);
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	NSRect bounds = [self bounds];
	CGFloat right = 8;
	if (_showsCancelButton) {
		CGFloat width = [_cancel sizeThatFits:CGSizeZero].width;
		[_cancel setFrame:NSMakeRect(bounds.size.width - width - 6, 0, width, bounds.size.height)];
		right += width + 4;
	}
	[_field setFrame:NSMakeRect(8, floor((bounds.size.height - 28) / 2), MAX(0, bounds.size.width - 8 - right), 28)];
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor colorWithCalibratedRed:0.79 green:0.79 blue:0.81 alpha:1] setFill];
	NSRectFill(rect);
}

- (void)fieldChanged:(id)sender
{
	if ([_delegate respondsToSelector:@selector(searchBar:textDidChange:)])
		[_delegate searchBar:self textDidChange:[_field text]];
}

- (void)cancelPressed:(id)sender
{
	if ([_delegate respondsToSelector:@selector(searchBarCancelButtonClicked:)])
		[_delegate searchBarCancelButtonClicked:self];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	return ![_delegate respondsToSelector:@selector(searchBarShouldBeginEditing:)] || [_delegate searchBarShouldBeginEditing:self];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	if ([_delegate respondsToSelector:@selector(searchBarTextDidBeginEditing:)])
		[_delegate searchBarTextDidBeginEditing:self];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if ([_delegate respondsToSelector:@selector(searchBarTextDidEndEditing:)])
		[_delegate searchBarTextDidEndEditing:self];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if ([_delegate respondsToSelector:@selector(searchBarSearchButtonClicked:)])
		[_delegate searchBarSearchButtonClicked:self];
	return YES;
}

@end
