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

// Numeric values of UIControlEvents and UIControlState: BSD Chameleon UIControl.h (rung 2); Apple's
// pages give names only (notice above, full text in LICENSE.Chameleon). Omitted for lack of a value source: UIControlStateFocused and the
// primary/menu action events.

#pragma once
#import <UIKit/UIView.h>
#import <Foundation/NSSet.h>

typedef NS_OPTIONS(NSUInteger, UIControlEvents) {
    UIControlEventTouchDown           = 1 <<  0,
    UIControlEventTouchDownRepeat     = 1 <<  1,
    UIControlEventTouchDragInside     = 1 <<  2,
    UIControlEventTouchDragOutside    = 1 <<  3,
    UIControlEventTouchDragEnter      = 1 <<  4,
    UIControlEventTouchDragExit       = 1 <<  5,
    UIControlEventTouchUpInside       = 1 <<  6,
    UIControlEventTouchUpOutside      = 1 <<  7,
    UIControlEventTouchCancel         = 1 <<  8,

    UIControlEventValueChanged        = 1 << 12,

    UIControlEventEditingDidBegin     = 1 << 16,
    UIControlEventEditingChanged      = 1 << 17,
    UIControlEventEditingDidEnd       = 1 << 18,
    UIControlEventEditingDidEndOnExit = 1 << 19,

    UIControlEventAllTouchEvents      = 0x00000FFF,
    UIControlEventAllEditingEvents    = 0x000F0000,
    UIControlEventApplicationReserved = 0x0F000000,
    UIControlEventSystemReserved      = 0xF0000000,
    UIControlEventAllEvents           = 0xFFFFFFFF
};

typedef NS_OPTIONS(NSUInteger, UIControlState) {
    UIControlStateNormal      = 0,
    UIControlStateHighlighted = 1 << 0,
    UIControlStateDisabled    = 1 << 1,
    UIControlStateSelected    = 1 << 2,
    UIControlStateApplication = 0x00FF0000,
    UIControlStateReserved    = 0xFF000000
};

NS_ASSUME_NONNULL_BEGIN

// No touch tracking, rendering or UIEvent yet: events are only delivered by
// sendActionsForControlEvents:.  The superclass is upstream's NSView-based
// UIView, so a nil target is searched along the NSResponder chain.
@interface UIControl : UIView {
@package
	BOOL _uiDisabled;
	BOOL _uiSelected;
	BOOL _uiHighlighted;
	NSMutableArray *_uiActions;
}
// state is derived from enabled, selected and highlighted, not stored.
@property(nonatomic, readonly) UIControlState state;
@property(nonatomic, getter=isEnabled) BOOL enabled;
@property(nonatomic, getter=isSelected) BOOL selected;
@property(nonatomic, getter=isHighlighted) BOOL highlighted;

- (void)addTarget:(nullable id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents;
- (void)removeTarget:(nullable id)target action:(nullable SEL)action forControlEvents:(UIControlEvents)controlEvents;
- (void)sendActionsForControlEvents:(UIControlEvents)controlEvents;
// May contain NSNull for actions dispatched to the responder chain.
@property(nonatomic, readonly) NSSet *allTargets;
@property(nonatomic, readonly) UIControlEvents allControlEvents;
@end

NS_ASSUME_NONNULL_END
