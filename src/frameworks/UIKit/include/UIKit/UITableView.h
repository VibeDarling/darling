/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UITABLEVIEW_H
#define UIKIT_UITABLEVIEW_H

#import <UIKit/UIScrollView.h>
#import <Foundation/NSIndexPath.h>
#import <AppKit/NSText.h>

@class UITableView, UITableViewCell, UILabel, UIImageView, UIColor, UIFont, UIImage;

typedef NS_ENUM(NSInteger, UITableViewStyle) {
	UITableViewStylePlain,
	UITableViewStyleGrouped,
};

typedef NS_ENUM(NSInteger, UITableViewScrollPosition) {
	UITableViewScrollPositionNone,
	UITableViewScrollPositionTop,
	UITableViewScrollPositionMiddle,
	UITableViewScrollPositionBottom,
};

typedef NS_ENUM(NSInteger, UITableViewRowAnimation) {
	UITableViewRowAnimationFade,
	UITableViewRowAnimationRight,
	UITableViewRowAnimationLeft,
	UITableViewRowAnimationTop,
	UITableViewRowAnimationBottom,
	UITableViewRowAnimationNone,
	UITableViewRowAnimationMiddle,
	UITableViewRowAnimationAutomatic = 100,
};

typedef NS_ENUM(NSInteger, UITableViewCellStyle) {
	UITableViewCellStyleDefault,
	UITableViewCellStyleValue1,
	UITableViewCellStyleValue2,
	UITableViewCellStyleSubtitle,
};

typedef NS_ENUM(NSInteger, UITableViewCellSelectionStyle) {
	UITableViewCellSelectionStyleNone,
	UITableViewCellSelectionStyleBlue,
	UITableViewCellSelectionStyleGray,
	UITableViewCellSelectionStyleDefault,
};

typedef NS_ENUM(NSInteger, UITableViewCellAccessoryType) {
	UITableViewCellAccessoryNone,
	UITableViewCellAccessoryDisclosureIndicator,
	UITableViewCellAccessoryDetailDisclosureButton,
	UITableViewCellAccessoryCheckmark,
	UITableViewCellAccessoryDetailButton,
};

typedef NS_ENUM(NSInteger, UITableViewCellEditingStyle) {
	UITableViewCellEditingStyleNone,
	UITableViewCellEditingStyleDelete,
	UITableViewCellEditingStyleInsert,
};

typedef NS_ENUM(NSInteger, UITableViewCellSeparatorStyle) {
	UITableViewCellSeparatorStyleNone,
	UITableViewCellSeparatorStyleSingleLine,
	UITableViewCellSeparatorStyleSingleLineEtched,
};

extern NSString *const UITableViewIndexSearch;
extern const CGFloat UITableViewAutomaticDimension;

NS_ASSUME_NONNULL_BEGIN

@interface NSIndexPath (UITableView)
+ (instancetype)indexPathForRow:(NSInteger)row inSection:(NSInteger)section;
+ (instancetype)indexPathForItem:(NSInteger)item inSection:(NSInteger)section;
@property (nonatomic, readonly) NSInteger section;
@property (nonatomic, readonly) NSInteger row;
@property (nonatomic, readonly) NSInteger item;
@end

@protocol UITableViewDataSource <NSObject>
@required
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
@optional
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section;
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index;
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;
@end

@protocol UITableViewDelegate <UIScrollViewDelegate>
@optional
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;
- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
- (nullable UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender;
- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender;
@end

@interface UITableView : UIScrollView
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;
@property (nonatomic, readonly) UITableViewStyle style;
@property (nullable, nonatomic, weak) id<UITableViewDataSource> dataSource;
@property (nullable, nonatomic, weak) id<UITableViewDelegate> delegate;
@property (nonatomic) CGFloat rowHeight;
@property (nonatomic) CGFloat estimatedRowHeight;
@property (nonatomic) CGFloat sectionHeaderHeight;
@property (nonatomic) CGFloat sectionFooterHeight;
@property (nonatomic) UITableViewCellSeparatorStyle separatorStyle;
@property (nullable, nonatomic, strong) UIColor *separatorColor;
@property (nonatomic) UIEdgeInsets separatorInset;
@property (nullable, nonatomic, strong) UIView *tableHeaderView;
@property (nullable, nonatomic, strong) UIView *tableFooterView;
@property (nullable, nonatomic, strong) UIView *backgroundView;
@property (nonatomic) BOOL allowsSelection;
@property (nonatomic) BOOL allowsSelectionDuringEditing;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic, getter=isEditing) BOOL editing;
@property (nonatomic) NSInteger sectionIndexMinimumDisplayRowCount;
@property (nullable, nonatomic, strong) UIColor *sectionIndexColor;
@property (nullable, nonatomic, strong) UIColor *sectionIndexBackgroundColor;
- (void)setEditing:(BOOL)editing animated:(BOOL)animated;
- (void)reloadData;
- (void)reloadSectionIndexTitles;
@property (nonatomic, readonly) NSInteger numberOfSections;
- (NSInteger)numberOfRowsInSection:(NSInteger)section;
- (CGRect)rectForSection:(NSInteger)section;
- (CGRect)rectForHeaderInSection:(NSInteger)section;
- (CGRect)rectForFooterInSection:(NSInteger)section;
- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point;
- (nullable NSIndexPath *)indexPathForCell:(UITableViewCell *)cell;
- (nullable NSArray<NSIndexPath *> *)indexPathsForRowsInRect:(CGRect)rect;
- (nullable __kindof UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath;
@property (nonatomic, readonly) NSArray<__kindof UITableViewCell *> *visibleCells;
@property (nonatomic, readonly, nullable) NSArray<NSIndexPath *> *indexPathsForVisibleRows;
- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated;
- (void)scrollToNearestSelectedRowAtScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated;
- (void)beginUpdates;
- (void)endUpdates;
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)insertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
- (void)reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
@property (nonatomic, readonly, nullable) NSIndexPath *indexPathForSelectedRow;
@property (nonatomic, readonly, nullable) NSArray<NSIndexPath *> *indexPathsForSelectedRows;
- (void)selectRowAtIndexPath:(nullable NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition;
- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;
- (nullable __kindof UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier;
- (__kindof UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
- (void)registerClass:(nullable Class)cellClass forCellReuseIdentifier:(NSString *)identifier;
@end

@interface UITableViewCell : UIView
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier;
- (instancetype)initWithFrame:(CGRect)frame reuseIdentifier:(nullable NSString *)reuseIdentifier;
@property (nullable, nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) UIView *contentView;
@property (nullable, nonatomic, readonly) UILabel *textLabel;
@property (nullable, nonatomic, readonly) UILabel *detailTextLabel;
@property (nullable, nonatomic, readonly) UIImageView *imageView;
@property (nullable, nonatomic, strong) UIView *backgroundView;
@property (nullable, nonatomic, strong) UIView *selectedBackgroundView;
@property (nonatomic) UITableViewCellSelectionStyle selectionStyle;
@property (nonatomic) UITableViewCellAccessoryType accessoryType;
@property (nullable, nonatomic, strong) UIView *accessoryView;
@property (nonatomic) UITableViewCellAccessoryType editingAccessoryType;
@property (nullable, nonatomic, strong) UIView *editingAccessoryView;
@property (nonatomic) NSInteger indentationLevel;
@property (nonatomic) CGFloat indentationWidth;
@property (nonatomic) BOOL showsReorderControl;
@property (nonatomic) BOOL shouldIndentWhileEditing;
@property (nonatomic, readonly) UITableViewCellEditingStyle editingStyle;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, getter=isEditing) BOOL editing;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated;
- (void)setEditing:(BOOL)editing animated:(BOOL)animated;
- (void)prepareForReuse;
/* The iPhone OS 2 API, still used by older apps. */
@property (nullable, nonatomic, copy) NSString *text;
@property (nullable, nonatomic, strong) UIFont *font;
@property (nullable, nonatomic, strong) UIColor *textColor;
@property (nullable, nonatomic, strong) UIColor *selectedTextColor;
@property (nullable, nonatomic, strong) UIImage *image;
@property (nonatomic) NSTextAlignment textAlignment;
/* Private UIKit API that subclasses override and call through. */
- (void)_updateHighlightColorsForView:(id)view highlighted:(BOOL)highlighted;
- (float)selectionPercent;
@end

NS_ASSUME_NONNULL_END

#endif /* UIKIT_UITABLEVIEW_H */
