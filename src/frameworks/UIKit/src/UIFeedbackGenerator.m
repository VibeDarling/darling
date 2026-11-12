/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIFeedbackGenerator.h>

@implementation UIFeedbackGenerator
- (void)prepare { }
@end

@implementation UIImpactFeedbackGenerator
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style { return [super init]; }
- (instancetype)init { return [self initWithStyle:UIImpactFeedbackStyleMedium]; }
- (void)impactOccurred { }
- (void)impactOccurredWithIntensity:(CGFloat)intensity { }
@end

@implementation UISelectionFeedbackGenerator
- (void)selectionChanged { }
@end

@implementation UINotificationFeedbackGenerator
- (void)notificationOccurred:(UINotificationFeedbackType)notificationType { }
@end
