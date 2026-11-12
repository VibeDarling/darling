/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIMOTIONEFFECT_H
#define UIKIT_UIMOTIONEFFECT_H

#import <Foundation/Foundation.h>
#import <UIKit/UIView.h>
#import <UIKit/UIGeometry.h>

typedef NS_ENUM(NSInteger, UIInterpolatingMotionEffectType) {
	UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis,
	UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis,
};

/* There is no device motion, so the viewer is always straight ahead. */
@interface UIMotionEffect : NSObject <NSCopying, NSCoding>
- (NSDictionary<NSString *, id> *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)viewerOffset;
@end

@interface UIInterpolatingMotionEffect : UIMotionEffect
- (instancetype)initWithKeyPath:(NSString *)keyPath type:(UIInterpolatingMotionEffectType)type;
@property (nonatomic, readonly) NSString *keyPath;
@property (nonatomic, readonly) UIInterpolatingMotionEffectType type;
@property (nonatomic, strong) id minimumRelativeValue;
@property (nonatomic, strong) id maximumRelativeValue;
@end

@interface UIMotionEffectGroup : UIMotionEffect
@property (nonatomic, copy) NSArray<UIMotionEffect *> *motionEffects;
@end

@interface UIView (UIMotionEffects)
- (void)addMotionEffect:(UIMotionEffect *)effect;
- (void)removeMotionEffect:(UIMotionEffect *)effect;
@property (nonatomic, copy) NSArray<UIMotionEffect *> *motionEffects;
@end

#endif /* UIKIT_UIMOTIONEFFECT_H */
