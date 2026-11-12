/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIPICKERVIEW_H
#define UIKIT_UIPICKERVIEW_H

#import <UIKit/UIView.h>

@class UIPickerView, NSAttributedString;

@protocol UIPickerViewDataSource <NSObject>
@required
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView;
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component;
@end

@protocol UIPickerViewDelegate <NSObject>
@optional
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component;
- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component;
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component;
- (NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component;
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view;
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component;
@end

@interface UIPickerView : UIView
@property (nonatomic, weak) id<UIPickerViewDataSource> dataSource;
@property (nonatomic, weak) id<UIPickerViewDelegate> delegate;
@property (nonatomic) BOOL showsSelectionIndicator;
@property (nonatomic, readonly) NSInteger numberOfComponents;
- (NSInteger)numberOfRowsInComponent:(NSInteger)component;
- (CGSize)rowSizeForComponent:(NSInteger)component;
- (UIView *)viewForRow:(NSInteger)row forComponent:(NSInteger)component;
- (void)reloadAllComponents;
- (void)reloadComponent:(NSInteger)component;
- (void)selectRow:(NSInteger)row inComponent:(NSInteger)component animated:(BOOL)animated;
- (NSInteger)selectedRowInComponent:(NSInteger)component;
@end

#endif /* UIKIT_UIPICKERVIEW_H */
