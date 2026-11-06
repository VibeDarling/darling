/*
 * Copyright (c) 2011, The Iconfactory. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of The Iconfactory nor the names of its contributors may
 *    be used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE ICONFACTORY BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// The numeric values of UIButtonType come from the BSD-licensed Chameleon UIButton.h (rung 2 for
// values; notice above, full text in LICENSE.Chameleon); Apple's pages give names but no values. UIButtonTypeSystem = 1 is an inference (rung 6):
// the UIButtonType page marks RoundedRect as deprecated in favor of System, which indicates an
// alias, and Chameleon has RoundedRect = 1. UIButtonTypePlain and UIButtonTypeClose are documented
// but have no value source, so they are not declared; +buttonWithType: accepts and stores any value.

#pragma once
#import <UIKit/UIControl.h>
#import <UIKit/UIColor.h>
#import <Foundation/NSDictionary.h>

typedef NS_ENUM(NSInteger, UIButtonType) {
    UIButtonTypeCustom = 0,
    UIButtonTypeRoundedRect,
    UIButtonTypeSystem = UIButtonTypeRoundedRect,
    UIButtonTypeDetailDisclosure,
    UIButtonTypeInfoLight,
    UIButtonTypeInfoDark,
    UIButtonTypeContactAdd,
};

NS_ASSUME_NONNULL_BEGIN

// Data model only: titles and title colors per state; there is no label, drawing or layout.
@interface UIButton : UIControl {
@package
	UIButtonType _uiButtonType;
	NSMutableDictionary *_uiTitles;
	NSMutableDictionary *_uiTitleColors;
}
+ (instancetype)buttonWithType:(UIButtonType)buttonType;
@property(nonatomic, readonly) UIButtonType buttonType;
- (void)setTitle:(nullable NSString *)title forState:(UIControlState)state;
- (nullable NSString *)titleForState:(UIControlState)state;
- (void)setTitleColor:(nullable UIColor *)color forState:(UIControlState)state;
- (nullable UIColor *)titleColorForState:(UIControlState)state;
@end

NS_ASSUME_NONNULL_END
