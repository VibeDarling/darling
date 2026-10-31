/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISTEPPER_H
#define UIKIT_UISTEPPER_H

#import <UIKit/UIControl.h>

@class UIImage;

/* A minus and a plus button, which step the value. Holding one repeats
   while autorepeat is on, after half a second. */
@interface UIStepper : UIControl
@property (nonatomic, getter=isContinuous) BOOL continuous;
@property (nonatomic) BOOL autorepeat;
@property (nonatomic) BOOL wraps;
@property (nonatomic) double value;
@property (nonatomic) double minimumValue;
@property (nonatomic) double maximumValue;
@property (nonatomic) double stepValue;
- (void)setIncrementImage:(UIImage *)image forState:(UIControlState)state;
- (void)setDecrementImage:(UIImage *)image forState:(UIControlState)state;
- (void)setDividerImage:(UIImage *)image forLeftSegmentState:(UIControlState)leftState rightSegmentState:(UIControlState)rightState;
- (void)setBackgroundImage:(UIImage *)image forState:(UIControlState)state;
@end

#endif /* UIKIT_UISTEPPER_H */
