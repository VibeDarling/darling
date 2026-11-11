/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <Foundation/Foundation.h>

@class UIView;

NS_ASSUME_NONNULL_BEGIN

/* A view as context menus and pointer effects lift it. Darling shows neither, so it only
 * holds the view. */
@interface UITargetedPreview : NSObject <NSCopying>
- (instancetype)initWithView:(UIView *)view;
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) CGSize size;
@end

NS_ASSUME_NONNULL_END
