/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIVISUALEFFECTVIEW_H
#define UIKIT_UIVISUALEFFECTVIEW_H

#import <UIKit/UIView.h>

typedef NS_ENUM(NSInteger, UIBlurEffectStyle) {
	UIBlurEffectStyleExtraLight,
	UIBlurEffectStyleLight,
	UIBlurEffectStyleDark,
	UIBlurEffectStyleExtraDark,
	UIBlurEffectStyleRegular = 4,
	UIBlurEffectStyleProminent = 5,
	UIBlurEffectStyleSystemUltraThinMaterial,
	UIBlurEffectStyleSystemThinMaterial,
	UIBlurEffectStyleSystemMaterial,
	UIBlurEffectStyleSystemThickMaterial,
	UIBlurEffectStyleSystemChromeMaterial,
	UIBlurEffectStyleSystemUltraThinMaterialLight,
	UIBlurEffectStyleSystemThinMaterialLight,
	UIBlurEffectStyleSystemMaterialLight,
	UIBlurEffectStyleSystemThickMaterialLight,
	UIBlurEffectStyleSystemChromeMaterialLight,
	UIBlurEffectStyleSystemUltraThinMaterialDark,
	UIBlurEffectStyleSystemThinMaterialDark,
	UIBlurEffectStyleSystemMaterialDark,
	UIBlurEffectStyleSystemThickMaterialDark,
	UIBlurEffectStyleSystemChromeMaterialDark,
};

typedef NS_ENUM(NSInteger, UIVibrancyEffectStyle) {
	UIVibrancyEffectStyleLabel,
	UIVibrancyEffectStyleSecondaryLabel,
	UIVibrancyEffectStyleTertiaryLabel,
	UIVibrancyEffectStyleQuaternaryLabel,
	UIVibrancyEffectStyleFill,
	UIVibrancyEffectStyleSecondaryFill,
	UIVibrancyEffectStyleTertiaryFill,
	UIVibrancyEffectStyleSeparator,
};

@interface UIVisualEffect : NSObject <NSCopying, NSSecureCoding>
@end

@interface UIBlurEffect : UIVisualEffect
+ (UIBlurEffect *)effectWithStyle:(UIBlurEffectStyle)style;
@end

@interface UIVibrancyEffect : UIVisualEffect
+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect;
+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect style:(UIVibrancyEffectStyle)style;
@end

/*
 * Nothing behind a view is blurred here: a blur is drawn as the
 * translucent tint the material has over a plain background, and
 * vibrancy leaves its content as it is.
 */
@interface UIVisualEffectView : UIView
- (instancetype)initWithEffect:(UIVisualEffect *)effect;
@property (nonatomic, readonly, strong) UIView *contentView;
@property (nonatomic, copy) UIVisualEffect *effect;
@end

#endif /* UIKIT_UIVISUALEFFECTVIEW_H */
