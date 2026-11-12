/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIBARBUTTONITEM_H
#define UIKIT_UIBARBUTTONITEM_H

#import <Foundation/Foundation.h>
#import <UIKit/UIGeometry.h>

@class UIImage, UIView, UIColor;

typedef NS_ENUM(NSInteger, UIBarStyle) {
	UIBarStyleDefault = 0,
	UIBarStyleBlack = 1,
	UIBarStyleBlackOpaque = 1,
	UIBarStyleBlackTranslucent = 2,
};

typedef NS_ENUM(NSInteger, UIBarButtonItemStyle) {
	UIBarButtonItemStylePlain,
	UIBarButtonItemStyleBordered,
	UIBarButtonItemStyleDone,
};

typedef NS_ENUM(NSInteger, UIBarButtonSystemItem) {
	UIBarButtonSystemItemDone,
	UIBarButtonSystemItemCancel,
	UIBarButtonSystemItemEdit,
	UIBarButtonSystemItemSave,
	UIBarButtonSystemItemAdd,
	UIBarButtonSystemItemFlexibleSpace,
	UIBarButtonSystemItemFixedSpace,
	UIBarButtonSystemItemCompose,
	UIBarButtonSystemItemReply,
	UIBarButtonSystemItemAction,
	UIBarButtonSystemItemOrganize,
	UIBarButtonSystemItemBookmarks,
	UIBarButtonSystemItemSearch,
	UIBarButtonSystemItemRefresh,
	UIBarButtonSystemItemStop,
	UIBarButtonSystemItemCamera,
	UIBarButtonSystemItemTrash,
	UIBarButtonSystemItemPlay,
	UIBarButtonSystemItemPause,
	UIBarButtonSystemItemRewind,
	UIBarButtonSystemItemFastForward,
	UIBarButtonSystemItemUndo,
	UIBarButtonSystemItemRedo,
	UIBarButtonSystemItemPageCurl,
};

@interface UIBarItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) NSInteger tag;
@property (nonatomic) UIEdgeInsets imageInsets;
- (void)setTitleTextAttributes:(NSDictionary *)attributes forState:(NSUInteger)state;
@end

@interface UIBarButtonItem : UIBarItem
- (instancetype)initWithTitle:(NSString *)title style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action;
- (instancetype)initWithImage:(UIImage *)image style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action;
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem target:(id)target action:(SEL)action;
- (instancetype)initWithCustomView:(UIView *)customView;
@property (nonatomic) UIBarButtonItemStyle style;
@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;
@property (nonatomic, strong) UIView *customView;
@property (nonatomic) CGFloat width;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, copy) NSSet *possibleTitles;
@end

#endif /* UIKIT_UIBARBUTTONITEM_H */
