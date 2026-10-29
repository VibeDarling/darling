/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UITextView.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIColor.h>
#import "UIKitPrivate.h"
#import <AppKit/NSTextView.h>
#import <AppKit/NSTextContainer.h>
#import <AppKit/NSLayoutManager.h>
#import <AppKit/NSTextStorage.h>

/*
 * The text is AppKit's: an NSTextView as wide as the text view and as tall
 * as its text, scrolled by the UIScrollView it is in. A separate object is
 * the NSTextView's delegate, since some of AppKit's delegate methods have
 * the names of UITextViewDelegate's.
 */

@interface UIKitTextViewBridge : NSObject <NSTextViewDelegate> {
@public
	__weak UITextView *owner;
}
@end

@interface UITextView ()
- (void)uikitTextChanged;
- (void)uikitEditingChanged:(BOOL)editing;
- (void)uikitSelectionChanged;
- (BOOL)uikitShouldBeginEditing;
- (BOOL)uikitShouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
@end

@implementation UIKitTextViewBridge

- (BOOL)textShouldBeginEditing:(NSText *)text { return [owner uikitShouldBeginEditing]; }
- (void)textDidBeginEditing:(NSNotification *)notification { [owner uikitEditingChanged:YES]; }
- (void)textDidEndEditing:(NSNotification *)notification { [owner uikitEditingChanged:NO]; }
- (void)textDidChange:(NSNotification *)notification { [owner uikitTextChanged]; }
- (void)textViewDidChangeSelection:(NSNotification *)notification { [owner uikitSelectionChanged]; }

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)range replacementString:(NSString *)string
{
	return [owner uikitShouldChangeTextInRange:range replacementText:string];
}

@end

@implementation UITextView {
	NSTextView *_textView;
	UIKitTextViewBridge *_bridge;
	UIFont *_font;
	UIColor *_textColor;
	UIEdgeInsets _textContainerInset;
	BOOL _editing;
}

@synthesize dataDetectorTypes = _dataDetectorTypes;
@synthesize allowsEditingTextAttributes = _allowsEditingTextAttributes;
@synthesize linkTextAttributes = _linkTextAttributes;
@synthesize clearsOnInsertion = _clearsOnInsertion;
@synthesize inputView = _inputView;
@synthesize inputAccessoryView = _inputAccessoryView;
@synthesize autocapitalizationType = _autocapitalizationType;
@synthesize autocorrectionType = _autocorrectionType;
@synthesize spellCheckingType = _spellCheckingType;
@synthesize keyboardType = _keyboardType;
@synthesize keyboardAppearance = _keyboardAppearance;
@synthesize returnKeyType = _returnKeyType;
@synthesize enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically;
@synthesize secureTextEntry = _secureTextEntry;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]) == nil)
		return nil;
	_font = [UIFont systemFontOfSize:12];
	_textColor = [UIColor blackColor];
	_textContainerInset = UIEdgeInsetsMake(8, 0, 8, 0);
	_bridge = [[UIKitTextViewBridge alloc] init];
	_bridge->owner = self;
	_textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
	[_textView setDrawsBackground:NO];
	[_textView setRichText:YES];
	[_textView setEditable:YES];
	[_textView setSelectable:YES];
	[_textView setVerticallyResizable:YES];
	[_textView setHorizontallyResizable:NO];
	[_textView setFont:[_font nsFont]];
	[_textView setTextColor:[_textColor nsColor]];
	[_textView setTextContainerInset:NSMakeSize(5, 8)];
	[[_textView textContainer] setWidthTracksTextView:YES];
	[_textView setDelegate:_bridge];
	[self addSubview:_textView];
	[self setBackgroundColor:[UIColor whiteColor]];
	[self setAlwaysBounceVertical:YES];
	return self;
}

- (void)uikitDecodeNib:(NSCoder *)coder
{
	[super uikitDecodeNib:coder];
	if ([coder containsValueForKey:@"UIFont"])
		[self setFont:[coder decodeObjectForKey:@"UIFont"]];
	if ([coder containsValueForKey:@"UITextColor"])
		[self setTextColor:[coder decodeObjectForKey:@"UITextColor"]];
	if ([coder containsValueForKey:@"UIAttributedText"])
		[self setAttributedText:[coder decodeObjectForKey:@"UIAttributedText"]];
	else if ([coder containsValueForKey:@"UIText"])
		[self setText:[coder decodeObjectForKey:@"UIText"]];
	if ([coder containsValueForKey:@"UITextAlignment"])
		[self setTextAlignment:[coder decodeIntegerForKey:@"UITextAlignment"]];
	[self setEditable:[coder decodeBoolForKey:@"UIEditable"]];
	[self setSelectable:[coder containsValueForKey:@"UISelectable"] ? [coder decodeBoolForKey:@"UISelectable"] : YES];
	_dataDetectorTypes = [coder decodeIntegerForKey:@"UIDataDetectorTypes"];
	_autocapitalizationType = [coder decodeIntegerForKey:@"UIAutocapitalizationType"];
	_autocorrectionType = [coder decodeIntegerForKey:@"UIAutocorrectionType"];
	_keyboardType = [coder decodeIntegerForKey:@"UIKeyboardType"];
	_returnKeyType = [coder decodeIntegerForKey:@"UIReturnKeyType"];
}

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)container
{
	return [self initWithFrame:frame];
}

- (id<UITextViewDelegate>)delegate { return (id<UITextViewDelegate>)[super delegate]; }
- (void)setDelegate:(id<UITextViewDelegate>)delegate { [super setDelegate:delegate]; }

- (void)uikitFitText
{
	NSRect bounds = [self bounds];
	[_textView setFrameSize:NSMakeSize(bounds.size.width, [_textView frame].size.height)];
	[_textView sizeToFit];
	CGFloat height = MAX(bounds.size.height, [_textView frame].size.height);
	[_textView setFrame:NSMakeRect(0, 0, bounds.size.width, height)];
	[self setContentSize:CGSizeMake(bounds.size.width, [_textView frame].size.height)];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	[self uikitFitText];
}

#pragma mark Text

- (NSString *)text { return [[_textView string] copy]; }

- (void)setText:(NSString *)text
{
	[_textView setString:text ?: @""];
	[_textView setFont:[_font nsFont]];
	[_textView setTextColor:[_textColor nsColor]];
	[self uikitFitText];
}

- (NSAttributedString *)attributedText
{
	return [[NSAttributedString alloc] initWithAttributedString:[_textView textStorage]];
}

/* AppKit's text system takes AppKit's fonts and colors, not the UIFonts and
 * UIColors iOS apps (and their nibs) put in the attributes. */
- (void)setAttributedText:(NSAttributedString *)text
{
	[[_textView textStorage] setAttributedString:text != nil ? UIKitAppKitAttributedString(text) : [[NSAttributedString alloc] init]];
	[self uikitFitText];
}

- (UIFont *)font { return _font; }

- (void)setFont:(UIFont *)font
{
	_font = font ?: [UIFont systemFontOfSize:12];
	[_textView setFont:[_font nsFont]];
	[self uikitFitText];
}

- (UIColor *)textColor { return _textColor; }

- (void)setTextColor:(UIColor *)color
{
	_textColor = color ?: [UIColor blackColor];
	[_textView setTextColor:[_textColor nsColor]];
}

- (NSTextAlignment)textAlignment { return [_textView alignment]; }
- (void)setTextAlignment:(NSTextAlignment)alignment { [_textView setAlignment:alignment]; }
- (NSRange)selectedRange { return [_textView selectedRange]; }
- (void)setSelectedRange:(NSRange)range { [_textView setSelectedRange:range]; }
- (BOOL)isEditable { return [_textView isEditable]; }
- (void)setEditable:(BOOL)editable { [_textView setEditable:editable]; }
- (BOOL)isSelectable { return [_textView isSelectable]; }
- (void)setSelectable:(BOOL)selectable { [_textView setSelectable:selectable]; }
- (NSDictionary *)typingAttributes { return [_textView typingAttributes]; }
- (void)setTypingAttributes:(NSDictionary *)attributes { [_textView setTypingAttributes:attributes]; }
- (UIEdgeInsets)textContainerInset { return _textContainerInset; }

- (void)setTextContainerInset:(UIEdgeInsets)inset
{
	_textContainerInset = inset;
	/* AppKit's inset is the same on both sides. */
	[_textView setTextContainerInset:NSMakeSize(5 + MAX(inset.left, inset.right), MAX(inset.top, inset.bottom))];
	[self uikitFitText];
}

- (NSTextContainer *)textContainer { return [_textView textContainer]; }
- (NSLayoutManager *)layoutManager { return [_textView layoutManager]; }
- (NSTextStorage *)textStorage { return [_textView textStorage]; }

- (void)scrollRangeToVisible:(NSRange)range
{
	NSLayoutManager *layoutManager = [_textView layoutManager];
	NSRange glyphs = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
	NSRect rect = [layoutManager boundingRectForGlyphRange:glyphs inTextContainer:[_textView textContainer]];
	NSPoint origin = [_textView textContainerOrigin];
	[self scrollRectToVisible:CGRectMake(rect.origin.x + origin.x, rect.origin.y + origin.y, MAX(rect.size.width, 1), MAX(rect.size.height, 1)) animated:NO];
}

#pragma mark Editing

- (BOOL)canBecomeFirstResponder { return [_textView isEditable] || [_textView isSelectable]; }

- (BOOL)becomeFirstResponder
{
	if (![self uikitShouldBeginEditing])
		return NO;
	return [[self window] makeFirstResponder:_textView];
}

- (BOOL)resignFirstResponder
{
	if (!_editing)
		return YES;
	id<UITextViewDelegate> delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(textViewShouldEndEditing:)] && ![delegate textViewShouldEndEditing:self])
		return NO;
	NSWindow *window = [self window];
	BOOL resigned = [window makeFirstResponder:window];
	if (resigned && _editing)
		[self uikitEditingChanged:NO];
	return resigned;
}

- (BOOL)isFirstResponder { return _editing; }

- (BOOL)uikitShouldBeginEditing
{
	id<UITextViewDelegate> delegate = [self delegate];
	return ![delegate respondsToSelector:@selector(textViewShouldBeginEditing:)] || [delegate textViewShouldBeginEditing:self];
}

- (BOOL)uikitShouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
	id<UITextViewDelegate> delegate = [self delegate];
	return ![delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]
		|| [delegate textView:self shouldChangeTextInRange:range replacementText:text ?: @""];
}

- (void)uikitEditingChanged:(BOOL)editing
{
	if (editing == _editing)
		return;
	_editing = editing;
	id<UITextViewDelegate> delegate = [self delegate];
	if (editing) {
		if ([delegate respondsToSelector:@selector(textViewDidBeginEditing:)])
			[delegate textViewDidBeginEditing:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidBeginEditingNotification object:self];
	} else {
		if ([delegate respondsToSelector:@selector(textViewDidEndEditing:)])
			[delegate textViewDidEndEditing:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidEndEditingNotification object:self];
	}
}

- (void)uikitTextChanged
{
	[self uikitFitText];
	id<UITextViewDelegate> delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(textViewDidChange:)])
		[delegate textViewDidChange:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:self];
}

- (void)uikitSelectionChanged
{
	id<UITextViewDelegate> delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(textViewDidChangeSelection:)])
		[delegate textViewDidChangeSelection:self];
}

@end
