/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIDATEPICKER_H
#define UIKIT_UIDATEPICKER_H

#import <UIKit/UIControl.h>

typedef NS_ENUM(NSInteger, UIDatePickerMode) {
	UIDatePickerModeTime,
	UIDatePickerModeDate,
	UIDatePickerModeDateAndTime,
	UIDatePickerModeCountDownTimer,
};

@interface UIDatePicker : UIControl
@property (nonatomic) UIDatePickerMode datePickerMode;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSDate *minimumDate;
@property (nonatomic, strong) NSDate *maximumDate;
@property (nonatomic, strong) NSLocale *locale;
@property (nonatomic, copy) NSCalendar *calendar;
@property (nonatomic, strong) NSTimeZone *timeZone;
@property (nonatomic) NSTimeInterval countDownDuration;
@property (nonatomic) NSInteger minuteInterval;
- (void)setDate:(NSDate *)date animated:(BOOL)animated;
@end

#endif /* UIKIT_UIDATEPICKER_H */
