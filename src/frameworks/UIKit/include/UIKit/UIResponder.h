/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIRESPONDER_H
#define UIKIT_UIRESPONDER_H

#import <Foundation/NSObject.h>

@class UIResponder;

NS_ASSUME_NONNULL_BEGIN

/* The edit menu's actions; a responder implements those it supports. */
@protocol UIResponderStandardEditActions <NSObject>
@optional
- (void)cut:(nullable id)sender;
- (void)copy:(nullable id)sender;
- (void)paste:(nullable id)sender;
- (void)select:(nullable id)sender;
- (void)selectAll:(nullable id)sender;
- (void)delete:(nullable id)sender;
@end

@interface UIResponder : NSObject <UIResponderStandardEditActions> {
@private
	UIResponder *_nextResponder;
	BOOL _firstResponder;
}

@property (nonatomic, readonly, nullable) UIResponder *nextResponder;

@property (nonatomic, readonly) BOOL canBecomeFirstResponder;
- (BOOL)becomeFirstResponder;
@property (nonatomic, readonly) BOOL isFirstResponder;
- (BOOL)resignFirstResponder;

@end

NS_ASSUME_NONNULL_END

#endif /* UIKIT_UIRESPONDER_H */
