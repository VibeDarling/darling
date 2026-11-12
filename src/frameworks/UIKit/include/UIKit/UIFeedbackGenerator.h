/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIFEEDBACKGENERATOR_H
#define UIKIT_UIFEEDBACKGENERATOR_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGBase.h>

/* Haptics. A phone host has no Taptic Engine to drive, so these accept
   every request and do nothing. */
@interface UIFeedbackGenerator : NSObject
- (void)prepare;
@end

typedef NS_ENUM(NSInteger, UIImpactFeedbackStyle) {
	UIImpactFeedbackStyleLight,
	UIImpactFeedbackStyleMedium,
	UIImpactFeedbackStyleHeavy,
	UIImpactFeedbackStyleSoft,
	UIImpactFeedbackStyleRigid,
};

@interface UIImpactFeedbackGenerator : UIFeedbackGenerator
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style;
- (void)impactOccurred;
- (void)impactOccurredWithIntensity:(CGFloat)intensity;
@end

@interface UISelectionFeedbackGenerator : UIFeedbackGenerator
- (void)selectionChanged;
@end

typedef NS_ENUM(NSInteger, UINotificationFeedbackType) {
	UINotificationFeedbackTypeSuccess,
	UINotificationFeedbackTypeWarning,
	UINotificationFeedbackTypeError,
};

@interface UINotificationFeedbackGenerator : UIFeedbackGenerator
- (void)notificationOccurred:(UINotificationFeedbackType)notificationType;
@end

#endif /* UIKIT_UIFEEDBACKGENERATOR_H */
