/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIAlertView.h>
#import <UIKit/UITextField.h>
#import <UIKit/UIControl.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UITouch.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSMutableParagraphStyle.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSGraphicsContext.h>
#import <objc/message.h>
#import "UIKitPrivate.h"

#pragma mark - Overlay

NSInteger UIKitOverlayCount;
NSString *const UIKitOverlaysDidChangeNotification = @"UIKitOverlaysDidChangeNotification";

/* Dims the window behind an alert or sheet and swallows taps outside it. */
@interface UIKitModalOverlay : UIView
@property (nonatomic) CGFloat dim;
@end

@implementation UIKitModalOverlay

- (void)removeFromSuperview
{
	BOOL shown = [self superview] != nil;
	[super removeFromSuperview];
	if (shown && UIKitOverlayCount > 0) {
		UIKitOverlayCount--;
		[[NSNotificationCenter defaultCenter] postNotificationName:UIKitOverlaysDidChangeNotification object:nil];
	}
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor colorWithCalibratedWhite:0 alpha:_dim] setFill];
	NSRectFillUsingOperation(rect, NSCompositeSourceOver);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event { }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { }

@end

static UIKitModalOverlay *UIKitShowOverlay(UIView *panel, UIView *inView, CGFloat dim)
{
	UIView *host = nil;
	if (inView != nil) {
		NSView *content = [[inView window] contentView];
		host = [content isKindOfClass:[UIView class]] ? (UIView *)content : inView;
	}
	if (host == nil)
		host = [UIWindow uikitKeyWindow];
	if (host == nil)
		return nil;
	UIKitModalOverlay *overlay = [[UIKitModalOverlay alloc] initWithFrame:NSRectToCGRect([host bounds])];
	[overlay setDim:dim];
	[overlay setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[overlay addSubview:panel];
	[host addSubview:overlay];
	UIKitOverlayCount++;
	[[NSNotificationCenter defaultCenter] postNotificationName:UIKitOverlaysDidChangeNotification object:nil];
	return overlay;
}

#pragma mark - Buttons

/* A row of choices: what alerts and sheets are made of. */
@interface UIKitChoiceButtons : NSObject {
@public
	NSMutableArray<NSString *> *titles;
	NSInteger cancelIndex;
	NSInteger destructiveIndex;
	NSInteger pressed;
}
@end

@implementation UIKitChoiceButtons

- (instancetype)init
{
	if ((self = [super init])) {
		titles = [NSMutableArray array];
		cancelIndex = -1;
		destructiveIndex = -1;
		pressed = -1;
	}
	return self;
}

@end

static NSDictionary *UIKitChoiceAttributes(BOOL bold, NSColor *color)
{
	return @{
		NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize:17] : [NSFont systemFontOfSize:17],
		NSForegroundColorAttributeName: color,
	};
}

static void UIKitDrawChoice(NSString *title, NSRect rect, BOOL bold, BOOL destructive, BOOL pressed)
{
	if (pressed) {
		[[NSColor colorWithCalibratedWhite:0.85 alpha:1] setFill];
		NSRectFill(rect);
	}
	NSColor *color = destructive ? [NSColor colorWithCalibratedRed:1 green:0.23 blue:0.19 alpha:1] : UIKitTintColor();
	NSDictionary *attributes = UIKitChoiceAttributes(bold, color);
	NSSize size = [title sizeWithAttributes:attributes];
	[title drawAtPoint:NSMakePoint(floor(NSMidX(rect) - size.width / 2), floor(NSMidY(rect) - size.height / 2)) withAttributes:attributes];
}

static NSDictionary *UIKitTextAttributes(CGFloat size, BOOL bold, NSColor *color)
{
	NSMutableParagraphStyle *paragraph = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paragraph setAlignment:NSTextAlignmentCenter];
	return @{
		NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size],
		NSForegroundColorAttributeName: color,
		NSParagraphStyleAttributeName: paragraph,
	};
}

static CGFloat UIKitTextHeight(NSString *text, NSDictionary *attributes, CGFloat width)
{
	if ([text length] == 0)
		return 0;
	return ceil([text boundingRectWithSize:NSMakeSize(width, 10000) options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes].size.height);
}

#pragma mark - UIAlertView

static const CGFloat UIKitAlertWidth = 270;
static const CGFloat UIKitChoiceHeight = 44;

@implementation UIAlertView {
	NSString *_title;
	NSString *_message;
	UIKitChoiceButtons *_buttons;
	UIKitModalOverlay *_overlay;
	NSMutableArray<UITextField *> *_textFields;
	UIAlertViewStyle _style;
	NSString *_context;
	UIAlertView *_selfWhileVisible;
}

@synthesize delegate = _delegate;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_buttons = [[UIKitChoiceButtons alloc] init];
		_textFields = [NSMutableArray array];
	}
	return self;
}

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
{
	if ((self = [self initWithFrame:CGRectZero]) == nil)
		return nil;
	_title = [title copy];
	_message = [message copy];
	_delegate = delegate;
	if (cancelButtonTitle != nil)
		_buttons->cancelIndex = [self addButtonWithTitle:cancelButtonTitle];
	if (otherButtonTitles != nil) {
		[self addButtonWithTitle:otherButtonTitles];
		va_list args;
		va_start(args, otherButtonTitles);
		NSString *other;
		while ((other = va_arg(args, NSString *)) != nil)
			[self addButtonWithTitle:other];
		va_end(args);
	}
	return self;
}

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)title { _title = [title copy]; [self relayout]; }
- (NSString *)message { return _message; }
- (void)setMessage:(NSString *)message { _message = [message copy]; [self relayout]; }
- (NSInteger)cancelButtonIndex { return _buttons->cancelIndex; }
- (void)setCancelButtonIndex:(NSInteger)index { _buttons->cancelIndex = index; [self setNeedsDisplay:YES]; }
- (NSInteger)firstOtherButtonIndex { return _buttons->cancelIndex == 0 ? ([_buttons->titles count] > 1 ? 1 : -1) : ([_buttons->titles count] > 0 ? 0 : -1); }
- (NSInteger)numberOfButtons { return [_buttons->titles count]; }
- (BOOL)isVisible { return _overlay != nil; }
- (NSString *)context { return _context; }
- (void)setContext:(NSString *)context { _context = [context copy]; }
- (void)setNumberOfRows:(int)rows { }
- (void)setRunsModal:(BOOL)modal { }
- (id)buttons { return [_buttons->titles copy]; }
- (void)_updateFrameForDisplay { [self relayout]; }

- (NSInteger)addButtonWithTitle:(NSString *)title
{
	[_buttons->titles addObject:[title copy] ?: @""];
	[self relayout];
	return [_buttons->titles count] - 1;
}

- (NSString *)buttonTitleAtIndex:(NSInteger)index
{
	return index >= 0 && index < (NSInteger)[_buttons->titles count] ? [_buttons->titles objectAtIndex:index] : nil;
}

- (UIAlertViewStyle)alertViewStyle { return _style; }

- (void)setAlertViewStyle:(UIAlertViewStyle)style
{
	_style = style;
	for (UITextField *field in _textFields)
		[field removeFromSuperview];
	[_textFields removeAllObjects];
	NSInteger count = style == UIAlertViewStyleDefault ? 0 : style == UIAlertViewStyleLoginAndPasswordInput ? 2 : 1;
	for (NSInteger i = 0; i < count; i++) {
		UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
		[field setBorderStyle:UITextBorderStyleRoundedRect];
		[field setFont:[UIFont systemFontOfSize:14]];
		[field setSecureTextEntry:style == UIAlertViewStyleSecureTextInput || (style == UIAlertViewStyleLoginAndPasswordInput && i == 1)];
		[_textFields addObject:field];
		[self addSubview:field];
	}
	[self relayout];
}

- (UITextField *)textFieldAtIndex:(NSInteger)index
{
	return index >= 0 && index < (NSInteger)[_textFields count] ? [_textFields objectAtIndex:index] : nil;
}

- (void)addTextFieldWithValue:(NSString *)value label:(NSString *)label
{
	if (_style == UIAlertViewStyleDefault)
		[self setAlertViewStyle:UIAlertViewStylePlainTextInput];
	UITextField *field = [_textFields lastObject];
	[field setText:value];
	[field setPlaceholder:label];
}

- (UITextField *)textField
{
	return [_textFields firstObject];
}

/* Two buttons sit side by side, more are stacked. */
- (BOOL)buttonsSideBySide
{
	return [_buttons->titles count] == 2;
}

- (CGFloat)textBlockHeight
{
	CGFloat width = UIKitAlertWidth - 32;
	CGFloat height = 20;
	height += UIKitTextHeight(_title, UIKitTextAttributes(17, YES, [NSColor blackColor]), width);
	if ([_message length] > 0)
		height += 4 + UIKitTextHeight(_message, UIKitTextAttributes(13, NO, [NSColor blackColor]), width);
	height += [_textFields count] * 34;
	return height + 18;
}

- (void)relayout
{
	CGFloat height = [self textBlockHeight];
	NSUInteger count = [_buttons->titles count];
	height += count == 0 ? 0 : [self buttonsSideBySide] ? UIKitChoiceHeight : count * UIKitChoiceHeight;
	NSRect frame = [self frame];
	frame.size = NSMakeSize(UIKitAlertWidth, height);
	NSView *superview = [self superview];
	if (superview != nil) {
		NSRect bounds = [superview bounds];
		frame.origin = NSMakePoint(floor(NSMidX(bounds) - frame.size.width / 2), floor(NSMidY(bounds) - frame.size.height / 2));
	}
	[self setFrame:frame];
	CGFloat y = [self textBlockHeight] - 18 - [_textFields count] * 34 + 4;
	for (UITextField *field in _textFields) {
		[field setFrame:NSMakeRect(16, y, UIKitAlertWidth - 32, 28)];
		y += 34;
	}
	[self setNeedsDisplay:YES];
}

- (NSRect)rectForButton:(NSUInteger)index
{
	CGFloat top = [self textBlockHeight];
	if ([self buttonsSideBySide])
		return NSMakeRect(index * UIKitAlertWidth / 2, top, UIKitAlertWidth / 2, UIKitChoiceHeight);
	/* The cancel button goes last when stacked. */
	NSUInteger row = index;
	if (_buttons->cancelIndex >= 0) {
		if ((NSInteger)index == _buttons->cancelIndex)
			row = [_buttons->titles count] - 1;
		else if ((NSInteger)index > _buttons->cancelIndex)
			row = index - 1;
	}
	return NSMakeRect(0, top + row * UIKitChoiceHeight, UIKitAlertWidth, UIKitChoiceHeight);
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	NSBezierPath *panel = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:12 yRadius:12];
	[[NSColor colorWithCalibratedWhite:0.97 alpha:1] setFill];
	[panel fill];
	[NSGraphicsContext saveGraphicsState];
	[panel addClip];

	CGFloat width = UIKitAlertWidth - 32;
	CGFloat y = 20;
	NSDictionary *titleAttributes = UIKitTextAttributes(17, YES, [NSColor blackColor]);
	CGFloat titleHeight = UIKitTextHeight(_title, titleAttributes, width);
	[_title drawInRect:NSMakeRect(16, y, width, titleHeight) withAttributes:titleAttributes];
	y += titleHeight;
	if ([_message length] > 0) {
		NSDictionary *messageAttributes = UIKitTextAttributes(13, NO, [NSColor blackColor]);
		CGFloat messageHeight = UIKitTextHeight(_message, messageAttributes, width);
		[_message drawInRect:NSMakeRect(16, y + 4, width, messageHeight) withAttributes:messageAttributes];
	}

	[[NSColor colorWithCalibratedWhite:0.8 alpha:1] setFill];
	for (NSUInteger i = 0; i < [_buttons->titles count]; i++) {
		NSRect button = [self rectForButton:i];
		UIKitDrawChoice([_buttons->titles objectAtIndex:i], button, (NSInteger)i == _buttons->cancelIndex, NO, (NSInteger)i == _buttons->pressed);
		[[NSColor colorWithCalibratedWhite:0.8 alpha:1] setFill];
		NSRectFill(NSMakeRect(button.origin.x, button.origin.y, button.size.width, 0.5));
		if ([self buttonsSideBySide] && i == 1)
			NSRectFill(NSMakeRect(button.origin.x, button.origin.y, 0.5, button.size.height));
	}
	[NSGraphicsContext restoreGraphicsState];
}

- (NSInteger)buttonAtTouch:(NSSet *)touches
{
	CGPoint point = [[touches anyObject] locationInView:self];
	for (NSUInteger i = 0; i < [_buttons->titles count]; i++)
		if (NSPointInRect(NSMakePoint(point.x, point.y), [self rectForButton:i]))
			return i;
	return -1;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	_buttons->pressed = [self buttonAtTouch:touches];
	[self setNeedsDisplay:YES];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSInteger index = [self buttonAtTouch:touches];
	if (index != _buttons->pressed) {
		_buttons->pressed = index;
		[self setNeedsDisplay:YES];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSInteger index = [self buttonAtTouch:touches];
	BOOL fire = index >= 0 && index == _buttons->pressed;
	_buttons->pressed = -1;
	[self setNeedsDisplay:YES];
	if (!fire)
		return;
	id delegate = _delegate;
	if ([delegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)])
		[delegate alertView:self clickedButtonAtIndex:index];
	[self dismissWithClickedButtonIndex:index animated:YES];
}

- (void)show
{
	if (_overlay != nil)
		return;
	id delegate = _delegate;
	if ([delegate respondsToSelector:@selector(willPresentAlertView:)])
		[delegate willPresentAlertView:self];
	_overlay = UIKitShowOverlay(self, nil, 0.4);
	if (_overlay == nil)
		return;
	/* Kept alive while shown, as UIKit keeps a shown alert. */
	_selfWhileVisible = self;
	[self relayout];
	[self setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin];
	[[_textFields firstObject] becomeFirstResponder];
	if ([delegate respondsToSelector:@selector(didPresentAlertView:)])
		[delegate didPresentAlertView:self];
}

- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated
{
	if (_overlay == nil)
		return;
	id delegate = _delegate;
	if ([delegate respondsToSelector:@selector(alertView:willDismissWithButtonIndex:)])
		[delegate alertView:self willDismissWithButtonIndex:index];
	[self removeFromSuperview];
	[_overlay removeFromSuperview];
	_overlay = nil;
	if ([delegate respondsToSelector:@selector(alertView:didDismissWithButtonIndex:)])
		[delegate alertView:self didDismissWithButtonIndex:index];
	dispatch_async(dispatch_get_main_queue(), ^{
		self->_selfWhileVisible = nil;
	});
}

@end

#pragma mark - UIActionSheet

@implementation UIActionSheet {
	NSString *_title;
	UIKitChoiceButtons *_buttons;
	UIKitModalOverlay *_overlay;
	NSString *_context;
	UIActionSheet *_selfWhileVisible;
}

@synthesize delegate = _delegate;
@synthesize actionSheetStyle = _actionSheetStyle;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
		_buttons = [[UIKitChoiceButtons alloc] init];
	return self;
}

- (instancetype)initWithTitle:(NSString *)title delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
{
	if ((self = [self initWithFrame:CGRectZero]) == nil)
		return nil;
	_title = [title copy];
	_delegate = delegate;
	if (destructiveButtonTitle != nil)
		_buttons->destructiveIndex = [self addButtonWithTitle:destructiveButtonTitle];
	if (otherButtonTitles != nil) {
		[self addButtonWithTitle:otherButtonTitles];
		va_list args;
		va_start(args, otherButtonTitles);
		NSString *other;
		while ((other = va_arg(args, NSString *)) != nil)
			[self addButtonWithTitle:other];
		va_end(args);
	}
	if (cancelButtonTitle != nil)
		_buttons->cancelIndex = [self addButtonWithTitle:cancelButtonTitle];
	return self;
}

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)title { _title = [title copy]; }
- (NSInteger)cancelButtonIndex { return _buttons->cancelIndex; }
- (void)setCancelButtonIndex:(NSInteger)index { _buttons->cancelIndex = index; }
- (NSInteger)destructiveButtonIndex { return _buttons->destructiveIndex; }
- (void)setDestructiveButtonIndex:(NSInteger)index { _buttons->destructiveIndex = index; }
- (NSInteger)firstOtherButtonIndex { return _buttons->destructiveIndex == 0 ? 1 : 0; }
- (NSInteger)numberOfButtons { return [_buttons->titles count]; }
- (BOOL)isVisible { return _overlay != nil; }
- (NSString *)context { return _context; }
- (void)setContext:(NSString *)context { _context = [context copy]; }

- (NSInteger)addButtonWithTitle:(NSString *)title
{
	[_buttons->titles addObject:[title copy] ?: @""];
	return [_buttons->titles count] - 1;
}

- (NSString *)buttonTitleAtIndex:(NSInteger)index
{
	return index >= 0 && index < (NSInteger)[_buttons->titles count] ? [_buttons->titles objectAtIndex:index] : nil;
}

- (CGFloat)titleHeight
{
	if ([_title length] == 0)
		return 0;
	return UIKitTextHeight(_title, UIKitTextAttributes(13, NO, [NSColor grayColor]), [self bounds].size.width - 32) + 26;
}

/* The choices in one rounded group, the cancel button apart below it. */
- (NSRect)rectForButton:(NSUInteger)index
{
	NSRect bounds = [self bounds];
	CGFloat height = 57;
	if ((NSInteger)index == _buttons->cancelIndex)
		return NSMakeRect(0, bounds.size.height - height, bounds.size.width, height);
	NSUInteger row = index;
	if (_buttons->cancelIndex >= 0 && (NSInteger)index > _buttons->cancelIndex)
		row--;
	return NSMakeRect(0, [self titleHeight] + row * height, bounds.size.width, height);
}

- (void)layoutInHost
{
	NSView *host = [self superview];
	NSRect bounds = [host bounds];
	CGFloat width = MIN(bounds.size.width, 414) - 20;
	NSUInteger choices = [_buttons->titles count] - (_buttons->cancelIndex >= 0 ? 1 : 0);
	[self setFrameSize:NSMakeSize(width, 0)];
	CGFloat height = [self titleHeight] + choices * 57 + (_buttons->cancelIndex >= 0 ? 8 + 57 : 0);
	[self setFrame:NSMakeRect(floor((bounds.size.width - width) / 2), bounds.size.height - height - 10, width, height)];
	[self setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin];
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	NSUInteger choices = [_buttons->titles count] - (_buttons->cancelIndex >= 0 ? 1 : 0);
	NSRect group = NSMakeRect(0, 0, bounds.size.width, [self titleHeight] + choices * 57);
	NSBezierPath *groupPath = [NSBezierPath bezierPathWithRoundedRect:group xRadius:13 yRadius:13];
	[[NSColor colorWithCalibratedWhite:0.97 alpha:1] setFill];
	[groupPath fill];
	[NSGraphicsContext saveGraphicsState];
	[groupPath addClip];
	if ([_title length] > 0) {
		NSDictionary *attributes = UIKitTextAttributes(13, NO, [NSColor grayColor]);
		[_title drawInRect:NSMakeRect(16, 13, bounds.size.width - 32, [self titleHeight] - 26) withAttributes:attributes];
	}
	for (NSUInteger i = 0; i < [_buttons->titles count]; i++) {
		if ((NSInteger)i == _buttons->cancelIndex)
			continue;
		NSRect button = [self rectForButton:i];
		UIKitDrawChoice([_buttons->titles objectAtIndex:i], button, NO, (NSInteger)i == _buttons->destructiveIndex, (NSInteger)i == _buttons->pressed);
		if (button.origin.y > 0) {
			[[NSColor colorWithCalibratedWhite:0.8 alpha:1] setFill];
			NSRectFill(NSMakeRect(0, button.origin.y, bounds.size.width, 0.5));
		}
	}
	[NSGraphicsContext restoreGraphicsState];
	if (_buttons->cancelIndex >= 0) {
		NSRect cancel = [self rectForButton:_buttons->cancelIndex];
		NSBezierPath *cancelPath = [NSBezierPath bezierPathWithRoundedRect:cancel xRadius:13 yRadius:13];
		[[NSColor whiteColor] setFill];
		[cancelPath fill];
		[NSGraphicsContext saveGraphicsState];
		[cancelPath addClip];
		UIKitDrawChoice([_buttons->titles objectAtIndex:_buttons->cancelIndex], cancel, YES, NO, _buttons->cancelIndex == _buttons->pressed);
		[NSGraphicsContext restoreGraphicsState];
	}
}

- (NSInteger)buttonAtTouch:(NSSet *)touches
{
	CGPoint point = [[touches anyObject] locationInView:self];
	for (NSUInteger i = 0; i < [_buttons->titles count]; i++)
		if (NSPointInRect(NSMakePoint(point.x, point.y), [self rectForButton:i]))
			return i;
	return -1;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	_buttons->pressed = [self buttonAtTouch:touches];
	[self setNeedsDisplay:YES];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSInteger index = [self buttonAtTouch:touches];
	BOOL fire = index >= 0 && index == _buttons->pressed;
	_buttons->pressed = -1;
	[self setNeedsDisplay:YES];
	if (!fire)
		return;
	id delegate = _delegate;
	if ([delegate respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)])
		[delegate actionSheet:self clickedButtonAtIndex:index];
	[self dismissWithClickedButtonIndex:index animated:YES];
}

- (void)showInView:(UIView *)view
{
	if (_overlay != nil)
		return;
	id delegate = _delegate;
	if ([delegate respondsToSelector:@selector(willPresentActionSheet:)])
		[delegate willPresentActionSheet:self];
	_overlay = UIKitShowOverlay(self, view, 0.4);
	if (_overlay == nil)
		return;
	_selfWhileVisible = self;
	[self layoutInHost];
	if ([delegate respondsToSelector:@selector(didPresentActionSheet:)])
		[delegate didPresentActionSheet:self];
}

- (void)showFromTabBar:(UITabBar *)view { [self showInView:(UIView *)view]; }
- (void)showFromToolbar:(UIView *)view { [self showInView:view]; }
- (void)showFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated { [self showInView:nil]; }
- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated { [self showInView:view]; }

- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated
{
	if (_overlay == nil)
		return;
	id delegate = _delegate;
	if ([delegate respondsToSelector:@selector(actionSheet:willDismissWithButtonIndex:)])
		[delegate actionSheet:self willDismissWithButtonIndex:index];
	[self removeFromSuperview];
	[_overlay removeFromSuperview];
	_overlay = nil;
	if ([delegate respondsToSelector:@selector(actionSheet:didDismissWithButtonIndex:)])
		[delegate actionSheet:self didDismissWithButtonIndex:index];
	dispatch_async(dispatch_get_main_queue(), ^{
		self->_selfWhileVisible = nil;
	});
}

@end

#pragma mark - UIProgressHUD

@implementation UIProgressHUD {
	NSString *_text;
	BOOL _showsText;
	BOOL _done;
	UIActivityIndicatorView *_spinner;
	UIKitModalOverlay *_overlay;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:CGRectMake(0, 0, 160, 120)])) {
		_showsText = YES;
		_spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		[_spinner setFrame:NSMakeRect(61, 22, 37, 37)];
		[self addSubview:_spinner];
	}
	return self;
}

- (instancetype)initWithWindow:(UIWindow *)window
{
	return [self initWithFrame:CGRectZero];
}

- (void)setText:(NSString *)text { _text = [text copy]; [self setNeedsDisplay:YES]; }
- (void)setShowsText:(BOOL)shows { _showsText = shows; [self setNeedsDisplay:YES]; }
- (void)setFontSize:(int)size { }

- (void)done
{
	_done = YES;
	[_spinner stopAnimating];
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	[[NSColor colorWithCalibratedWhite:0 alpha:0.75] setFill];
	[[NSBezierPath bezierPathWithRoundedRect:bounds xRadius:10 yRadius:10] fill];
	if (_done) {
		NSDictionary *attributes = UIKitTextAttributes(40, YES, [NSColor whiteColor]);
		[@"✓" drawInRect:NSMakeRect(0, 18, bounds.size.width, 50) withAttributes:attributes];
	}
	if (_showsText && [_text length] > 0) {
		NSDictionary *attributes = UIKitTextAttributes(15, YES, [NSColor whiteColor]);
		[_text drawInRect:NSMakeRect(8, 72, bounds.size.width - 16, bounds.size.height - 76) withAttributes:attributes];
	}
}

- (void)showInView:(UIView *)view
{
	[self show:YES inView:view];
}

- (void)show:(BOOL)show
{
	[self show:show inView:nil];
}

- (void)show:(BOOL)show inView:(UIView *)view
{
	if (!show) {
		[self hide];
		return;
	}
	if (_overlay != nil)
		return;
	_overlay = UIKitShowOverlay(self, view, 0);
	NSRect bounds = [_overlay bounds];
	[self setFrameOrigin:NSMakePoint(floor(NSMidX(bounds) - 80), floor(NSMidY(bounds) - 60))];
	[self setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin];
	[_spinner startAnimating];
}

- (void)hide
{
	[_spinner stopAnimating];
	[self removeFromSuperview];
	[_overlay removeFromSuperview];
	_overlay = nil;
}

@end
