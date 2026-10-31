/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* iOS's first responder for UIViews, and typing for views that adopt
 * UIKeyInput.
 *
 * A UIView is an NSView, and the two frameworks mean different things by the
 * same selectors. On iOS, -becomeFirstResponder and -resignFirstResponder are
 * requests the app makes; in AppKit they are questions -[NSWindow
 * makeFirstResponder:] asks the views involved. AppKit sets the window's
 * first responder before it asks the new one, so a view that is already the
 * first responder is being asked, and anything else is the app's request.
 * Resigning is told apart by a flag set while UIKit itself gives it up.
 *
 * Whether the host shows its soft keyboard is the display backend's
 * business: AppKit's Pocket backend shows it while the first responder is a
 * text editor or adopts UIKeyInput, and says how tall it is once it shows;
 * apps hear of it as iOS tells them, by the UIKeyboard notifications. */

#import <UIKit/UIKit.h>
#import <UIKit/UIView.h>
#import <UIKit/UITextInput.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSText.h>

/* Set while a view gives up first responder at the app's request, so that
 * AppKit's own question to it is answered yes. */
static BOOL sUIKitResigning;

@implementation UIView (UIKitFirstResponder)

- (BOOL)canBecomeFirstResponder
{
	return NO;
}

- (BOOL)isFirstResponder
{
	return [[self window] firstResponder] == self;
}

- (BOOL)becomeFirstResponder
{
	NSWindow *window = [self window];
	if (window == nil)
		return NO;
	/* AppKit asking (it set the first responder first), or already so. */
	if ([window firstResponder] == self)
		return YES;
	if (![self canBecomeFirstResponder])
		return NO;
	return [window makeFirstResponder:self];
}

- (BOOL)resignFirstResponder
{
	NSWindow *window = [self window];
	if (sUIKitResigning || window == nil || [window firstResponder] != self)
		return YES;
	/* The app's request, or AppKit moving on to another responder; either
	   way handing it to the window ends with the view no longer first. */
	sUIKitResigning = YES;
	BOOL resigned = [window makeFirstResponder:window];
	sUIKitResigning = NO;
	return resigned;
}

/* Typing, for views that adopt UIKeyInput: text as -insertText:, Return as
   "\n" and the Delete key as -deleteBackward, as iOS's keyboard sends them.
   Function keys (arrows and the like) are dropped; a view that wants them
   overrides -keyDown:. Other views pass the event on, as NSView does. */
- (void)keyDown:(NSEvent *)event
{
	if (![self conformsToProtocol:@protocol(UIKeyInput)]) {
		[super keyDown:event];
		return;
	}
	id<UIKeyInput> input = (id<UIKeyInput>)self;
	NSString *characters = [event characters];
	NSMutableString *text = [NSMutableString string];
	void (^flush)(void) = ^{
		if ([text length] > 0) {
			[input insertText:[text copy]];
			[text setString:@""];
		}
	};
	for (NSUInteger i = 0; i < [characters length]; i++) {
		unichar c = [characters characterAtIndex:i];
		if (c == 0x08 || c == 0x7F) {
			flush();
			[input deleteBackward];
		} else if (c == '\r' || c == '\n' || c == 0x03) {
			[text appendString:@"\n"];
		} else if (c >= 0xF700 && c <= 0xF8FF) {
			/* NSUpArrowFunctionKey and the rest. */
		} else if (c >= 0x20 || c == '\t' || c == 0x1B) {
			[text appendFormat:@"%C", c];
		}
	}
	flush();
}

@end

/* The soft keyboard's comings and goings, from the display backend. */
@interface UIKitKeyboardTracker : NSObject
@end

static CGFloat sUIKitKeyboardHeight;

/* Where a keyboard of a height is on the screen: off its bottom edge when
   it is coming or going. */
static NSValue *UIKitKeyboardFrame(CGRect screen, CGFloat height, BOOL shown)
{
	CGRect frame = CGRectMake(0, shown ? screen.size.height - height : screen.size.height, screen.size.width, height);
	return [NSValue valueWithCGRect:frame];
}

static NSValue *UIKitKeyboardCenter(CGRect screen, CGFloat height, BOOL shown)
{
	CGRect frame = [UIKitKeyboardFrame(screen, height, shown) CGRectValue];
	return [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame))];
}

@implementation UIKitKeyboardTracker

+ (void)load
{
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(heightChanged:)
	                                             name:@"NSSoftKeyboardHeightDidChangeNotification"
	                                           object:nil];
}

+ (void)heightChanged:(NSNotification *)notification
{
	CGFloat height = [[[notification userInfo] objectForKey:@"height"] doubleValue];
	CGFloat old = sUIKitKeyboardHeight;
	if (height == old)
		return;
	sUIKitKeyboardHeight = height;

	BOOL showing = height > 0;
	CGFloat size = showing ? height : old;
	CGRect screen = [[UIScreen mainScreen] bounds];
	NSDictionary *info = @{
		UIKeyboardFrameBeginUserInfoKey: UIKitKeyboardFrame(screen, old ?: size, old > 0),
		UIKeyboardFrameEndUserInfoKey: UIKitKeyboardFrame(screen, size, showing),
		UIKeyboardCenterBeginUserInfoKey: UIKitKeyboardCenter(screen, old ?: size, old > 0),
		UIKeyboardCenterEndUserInfoKey: UIKitKeyboardCenter(screen, size, showing),
		UIKeyboardBoundsUserInfoKey: [NSValue valueWithCGRect:CGRectMake(0, 0, screen.size.width, size)],
		/* The host's keyboard has finished moving by now; apps animate
		   their own views over iOS's usual time and curve. */
		UIKeyboardAnimationDurationUserInfoKey: @0.25,
		UIKeyboardAnimationCurveUserInfoKey: @7,
		UIKeyboardIsLocalUserInfoKey: @YES,
	};
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName:UIKeyboardWillChangeFrameNotification object:nil userInfo:info];
	[center postNotificationName:showing ? UIKeyboardWillShowNotification : UIKeyboardWillHideNotification object:nil userInfo:info];
	[center postNotificationName:showing ? UIKeyboardDidShowNotification : UIKeyboardDidHideNotification object:nil userInfo:info];
	[center postNotificationName:UIKeyboardDidChangeFrameNotification object:nil userInfo:info];
}

@end
