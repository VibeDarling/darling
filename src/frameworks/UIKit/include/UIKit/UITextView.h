/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UITEXTVIEW_H
#define UIKIT_UITEXTVIEW_H

#import <UIKit/UIScrollView.h>
#import <UIKit/UITextField.h>
#import <UIKit/UIWebView.h>
#import <AppKit/NSTextStorage.h>
#import <AppKit/NSLayoutManager.h>
#import <AppKit/NSTextContainer.h>

@class UITextView, UIFont, UIColor;


@protocol UITextViewDelegate <NSObject, UIScrollViewDelegate>
@optional
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView;
- (BOOL)textViewShouldEndEditing:(UITextView *)textView;
- (void)textViewDidBeginEditing:(UITextView *)textView;
- (void)textViewDidEndEditing:(UITextView *)textView;
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)textViewDidChange:(UITextView *)textView;
- (void)textViewDidChangeSelection:(UITextView *)textView;
@end

@interface UITextView : UIScrollView <UITextInputTraits>
@property (nonatomic, weak) id<UITextViewDelegate> delegate;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSAttributedString *attributedText;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic) NSTextAlignment textAlignment;
@property (nonatomic) NSRange selectedRange;
@property (nonatomic, getter=isEditable) BOOL editable;
@property (nonatomic, getter=isSelectable) BOOL selectable;
@property (nonatomic) UIDataDetectorTypes dataDetectorTypes;
@property (nonatomic) BOOL allowsEditingTextAttributes;
@property (nonatomic, copy) NSDictionary *typingAttributes;
@property (nonatomic, copy) NSDictionary *linkTextAttributes;
@property (nonatomic) UIEdgeInsets textContainerInset;
@property (nonatomic) BOOL clearsOnInsertion;
@property (nonatomic, strong) UIView *inputView;
@property (nonatomic, strong) UIView *inputAccessoryView;
@property (nonatomic, readonly) NSTextContainer *textContainer;
@property (nonatomic, readonly) NSLayoutManager *layoutManager;
@property (nonatomic, readonly) NSTextStorage *textStorage;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic) UITextAutocorrectionType autocorrectionType;
@property (nonatomic) UITextSpellCheckingType spellCheckingType;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) BOOL enablesReturnKeyAutomatically;
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
- (void)scrollRangeToVisible:(NSRange)range;
@end

#endif /* UIKIT_UITEXTVIEW_H */
