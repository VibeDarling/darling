/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UITEXTFIELD_H
#define UIKIT_UITEXTFIELD_H

#import <UIKit/UIControl.h>
#import <UIKit/UIBarButtonItem.h>
#import <AppKit/NSText.h>

@class UITextField, UISearchBar, UIFont, UIColor, UIImage;

typedef NS_ENUM(NSInteger, UITextAutocapitalizationType) {
	UITextAutocapitalizationTypeNone,
	UITextAutocapitalizationTypeWords,
	UITextAutocapitalizationTypeSentences,
	UITextAutocapitalizationTypeAllCharacters,
};

typedef NS_ENUM(NSInteger, UITextAutocorrectionType) {
	UITextAutocorrectionTypeDefault,
	UITextAutocorrectionTypeNo,
	UITextAutocorrectionTypeYes,
};

typedef NS_ENUM(NSInteger, UITextSpellCheckingType) {
	UITextSpellCheckingTypeDefault,
	UITextSpellCheckingTypeNo,
	UITextSpellCheckingTypeYes,
};

typedef NS_ENUM(NSInteger, UIKeyboardType) {
	UIKeyboardTypeDefault,
	UIKeyboardTypeASCIICapable,
	UIKeyboardTypeNumbersAndPunctuation,
	UIKeyboardTypeURL,
	UIKeyboardTypeNumberPad,
	UIKeyboardTypePhonePad,
	UIKeyboardTypeNamePhonePad,
	UIKeyboardTypeEmailAddress,
	UIKeyboardTypeDecimalPad,
	UIKeyboardTypeTwitter,
	UIKeyboardTypeWebSearch,
};

typedef NS_ENUM(NSInteger, UIKeyboardAppearance) {
	UIKeyboardAppearanceDefault,
	UIKeyboardAppearanceDark,
	UIKeyboardAppearanceLight,
	UIKeyboardAppearanceAlert = UIKeyboardAppearanceDark,
};

typedef NS_ENUM(NSInteger, UIReturnKeyType) {
	UIReturnKeyDefault,
	UIReturnKeyGo,
	UIReturnKeyGoogle,
	UIReturnKeyJoin,
	UIReturnKeyNext,
	UIReturnKeyRoute,
	UIReturnKeySearch,
	UIReturnKeySend,
	UIReturnKeyYahoo,
	UIReturnKeyDone,
	UIReturnKeyEmergencyCall,
};

typedef NS_ENUM(NSInteger, UITextBorderStyle) {
	UITextBorderStyleNone,
	UITextBorderStyleLine,
	UITextBorderStyleBezel,
	UITextBorderStyleRoundedRect,
};

typedef NS_ENUM(NSInteger, UITextFieldViewMode) {
	UITextFieldViewModeNever,
	UITextFieldViewModeWhileEditing,
	UITextFieldViewModeUnlessEditing,
	UITextFieldViewModeAlways,
};

/* The keyboard is the host's: these traits are kept but change nothing. */
@protocol UITextInputTraits <NSObject>
@optional
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic) UITextAutocorrectionType autocorrectionType;
@property (nonatomic) UITextSpellCheckingType spellCheckingType;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) BOOL enablesReturnKeyAutomatically;
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@end

@protocol UITextFieldDelegate <NSObject>
@optional
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField;
- (void)textFieldDidBeginEditing:(UITextField *)textField;
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField;
- (void)textFieldDidEndEditing:(UITextField *)textField;
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string;
- (BOOL)textFieldShouldClear:(UITextField *)textField;
- (BOOL)textFieldShouldReturn:(UITextField *)textField;
@end

/* An AppKit text field inside, so typing, selection and the clipboard are
 * the host's. */
@interface UITextField : UIControl <UITextInputTraits>
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic) NSTextAlignment textAlignment;
@property (nonatomic) UITextBorderStyle borderStyle;
@property (nonatomic, weak) id<UITextFieldDelegate> delegate;
@property (nonatomic) BOOL clearsOnBeginEditing;
@property (nonatomic) UITextFieldViewMode clearButtonMode;
@property (nonatomic, strong) UIView *leftView;
@property (nonatomic) UITextFieldViewMode leftViewMode;
@property (nonatomic, strong) UIView *rightView;
@property (nonatomic) UITextFieldViewMode rightViewMode;
@property (nonatomic, strong) UIImage *background;
@property (nonatomic) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic) CGFloat minimumFontSize;
@property (nonatomic, readonly, getter=isEditing) BOOL editing;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic) UITextAutocorrectionType autocorrectionType;
@property (nonatomic) UITextSpellCheckingType spellCheckingType;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) BOOL enablesReturnKeyAutomatically;
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (BOOL)isFirstResponder;
/* Private UIKit API: the object holding the input traits (the field). */
- (id<UITextInputTraits>)textInputTraits;
@end

@protocol UISearchBarDelegate <NSObject>
@optional
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar;
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar;
- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar;
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar;
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText;
- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar;
- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope;
@end

@interface UISearchBar : UIView <UITextInputTraits>
@property (nonatomic, weak) id<UISearchBarDelegate> delegate;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, copy) NSString *prompt;
@property (nonatomic) BOOL showsCancelButton;
@property (nonatomic) BOOL showsBookmarkButton;
@property (nonatomic) BOOL showsScopeBar;
@property (nonatomic, copy) NSArray *scopeButtonTitles;
@property (nonatomic) NSInteger selectedScopeButtonIndex;
@property (nonatomic) UIBarStyle barStyle;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, strong) UIColor *barTintColor;
@property (nonatomic, getter=isTranslucent) BOOL translucent;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic) UITextAutocorrectionType autocorrectionType;
@property (nonatomic) UITextSpellCheckingType spellCheckingType;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) BOOL enablesReturnKeyAutomatically;
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
- (void)setShowsCancelButton:(BOOL)shows animated:(BOOL)animated;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (BOOL)isFirstResponder;
/* Private UIKit API. */
- (UITextField *)searchField;
@end

#endif /* UIKIT_UITEXTFIELD_H */
