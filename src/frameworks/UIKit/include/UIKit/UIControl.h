/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UICONTROL_H
#define UIKIT_UICONTROL_H

#import <UIKit/UIView.h>
#import <UIKit/UIGeometry.h>

@class UILabel, UIImage, UIColor, UIImageView, UIFont, UITextField, UISearchBar;

typedef NS_OPTIONS(NSUInteger, UIControlEvents) {
	UIControlEventTouchDown = 1 << 0,
	UIControlEventTouchDownRepeat = 1 << 1,
	UIControlEventTouchDragInside = 1 << 2,
	UIControlEventTouchDragOutside = 1 << 3,
	UIControlEventTouchDragEnter = 1 << 4,
	UIControlEventTouchDragExit = 1 << 5,
	UIControlEventTouchUpInside = 1 << 6,
	UIControlEventTouchUpOutside = 1 << 7,
	UIControlEventTouchCancel = 1 << 8,
	UIControlEventValueChanged = 1 << 12,
	UIControlEventEditingDidBegin = 1 << 16,
	UIControlEventEditingChanged = 1 << 17,
	UIControlEventEditingDidEnd = 1 << 18,
	UIControlEventEditingDidEndOnExit = 1 << 19,
	UIControlEventAllTouchEvents = 0x00000FFF,
	UIControlEventAllEditingEvents = 0x000F0000,
	UIControlEventAllEvents = 0xFFFFFFFF,
};

typedef NS_OPTIONS(NSUInteger, UIControlState) {
	UIControlStateNormal = 0,
	UIControlStateHighlighted = 1 << 0,
	UIControlStateDisabled = 1 << 1,
	UIControlStateSelected = 1 << 2,
};

typedef NS_ENUM(NSInteger, UIControlContentHorizontalAlignment) {
	UIControlContentHorizontalAlignmentCenter,
	UIControlContentHorizontalAlignmentLeft,
	UIControlContentHorizontalAlignmentRight,
	UIControlContentHorizontalAlignmentFill,
};

typedef NS_ENUM(NSInteger, UIControlContentVerticalAlignment) {
	UIControlContentVerticalAlignmentCenter,
	UIControlContentVerticalAlignmentTop,
	UIControlContentVerticalAlignmentBottom,
	UIControlContentVerticalAlignmentFill,
};

@interface UIControl : UIView
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, readonly) UIControlState state;
@property (nonatomic, readonly, getter=isTracking) BOOL tracking;
@property (nonatomic, readonly, getter=isTouchInside) BOOL touchInside;
@property (nonatomic) UIControlContentHorizontalAlignment contentHorizontalAlignment;
@property (nonatomic) UIControlContentVerticalAlignment contentVerticalAlignment;
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)events;
- (void)removeTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)events;
- (NSSet *)allTargets;
- (UIControlEvents)allControlEvents;
- (NSArray *)actionsForTarget:(id)target forControlEvent:(UIControlEvents)event;
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event;
- (void)sendActionsForControlEvents:(UIControlEvents)events;
/* The iPhone OS 2 spelling. */
- (void)addTarget:(id)target action:(SEL)action forEvents:(NSInteger)events;
@end

typedef NS_ENUM(NSInteger, UIButtonType) {
	UIButtonTypeCustom = 0,
	UIButtonTypeRoundedRect,
	UIButtonTypeDetailDisclosure,
	UIButtonTypeInfoLight,
	UIButtonTypeInfoDark,
	UIButtonTypeContactAdd,
	UIButtonTypeSystem = UIButtonTypeRoundedRect,
};

@interface UIButton : UIControl
+ (instancetype)buttonWithType:(UIButtonType)buttonType;
@property (nonatomic, readonly) UIButtonType buttonType;
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic, readonly) NSString *currentTitle;
@property (nonatomic, readonly) UIColor *currentTitleColor;
@property (nonatomic, readonly) UIImage *currentImage;
@property (nonatomic, readonly) UIImage *currentBackgroundImage;
@property (nonatomic) UIEdgeInsets contentEdgeInsets;
@property (nonatomic) UIEdgeInsets titleEdgeInsets;
@property (nonatomic) UIEdgeInsets imageEdgeInsets;
@property (nonatomic) BOOL showsTouchWhenHighlighted;
@property (nonatomic) BOOL adjustsImageWhenHighlighted;
@property (nonatomic, strong) UIFont *font;
- (void)setTitle:(NSString *)title forState:(UIControlState)state;
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state;
- (void)setTitleShadowColor:(UIColor *)color forState:(UIControlState)state;
- (void)setImage:(UIImage *)image forState:(UIControlState)state;
- (void)setBackgroundImage:(UIImage *)image forState:(UIControlState)state;
- (NSString *)titleForState:(UIControlState)state;
- (UIColor *)titleColorForState:(UIControlState)state;
- (UIImage *)imageForState:(UIControlState)state;
- (UIImage *)backgroundImageForState:(UIControlState)state;
@end

@interface UISwitch : UIControl
@property (nonatomic, getter=isOn) BOOL on;
@property (nonatomic, strong) UIColor *onTintColor;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

typedef NS_ENUM(NSInteger, UISegmentedControlStyle) {
	UISegmentedControlStylePlain,
	UISegmentedControlStyleBordered,
	UISegmentedControlStyleBar,
	UISegmentedControlStyleBezeled,
};

enum { UISegmentedControlNoSegment = -1 };

@interface UISegmentedControl : UIControl
- (instancetype)initWithItems:(NSArray *)items;
@property (nonatomic) NSInteger selectedSegmentIndex;
@property (nonatomic, readonly) NSUInteger numberOfSegments;
@property (nonatomic) UISegmentedControlStyle segmentedControlStyle;
@property (nonatomic, getter=isMomentary) BOOL momentary;
@property (nonatomic, strong) UIColor *tintColor;
- (void)insertSegmentWithTitle:(NSString *)title atIndex:(NSUInteger)index animated:(BOOL)animated;
- (void)insertSegmentWithImage:(UIImage *)image atIndex:(NSUInteger)index animated:(BOOL)animated;
- (void)removeSegmentAtIndex:(NSUInteger)index animated:(BOOL)animated;
- (void)removeAllSegments;
- (void)setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)index;
- (NSString *)titleForSegmentAtIndex:(NSUInteger)index;
- (void)setImage:(UIImage *)image forSegmentAtIndex:(NSUInteger)index;
- (UIImage *)imageForSegmentAtIndex:(NSUInteger)index;
- (void)setEnabled:(BOOL)enabled forSegmentAtIndex:(NSUInteger)index;
- (BOOL)isEnabledForSegmentAtIndex:(NSUInteger)index;
- (void)setWidth:(CGFloat)width forSegmentAtIndex:(NSUInteger)index;
@end

typedef NS_ENUM(NSInteger, UIActivityIndicatorViewStyle) {
	UIActivityIndicatorViewStyleWhiteLarge,
	UIActivityIndicatorViewStyleWhite,
	UIActivityIndicatorViewStyleGray,
	UIActivityIndicatorViewStyleWhiteSmall = 3,
	UIActivityIndicatorViewStyleWhiteTiny = 4,
	UIActivityIndicatorViewStyleGraySmall = 5,
};

@interface UIActivityIndicatorView : UIView
- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style;
@property (nonatomic) UIActivityIndicatorViewStyle activityIndicatorViewStyle;
@property (nonatomic) BOOL hidesWhenStopped;
@property (nonatomic, strong) UIColor *color;
- (void)startAnimating;
- (void)stopAnimating;
- (BOOL)isAnimating;
@end

#endif /* UIKIT_UICONTROL_H */
