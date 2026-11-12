/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <UIKit/UIKit.h>
#import "TerminalScreen.h"

@class TerminalView;

@protocol TerminalViewDelegate <NSObject>
/* Bytes typed, for the pty. */
- (void)terminalView:(TerminalView *)view sendData:(NSData *)data;
/* The grid changed size: the pty's window size should follow. */
- (void)terminalView:(TerminalView *)view didResizeToColumns:(int)columns rows:(int)rows;
/* A tap after the program ended. */
- (void)terminalViewWantsRestart:(TerminalView *)view;
@end

/* Draws a TerminalScreen and takes typing for it. Adopting UIKeyInput is
   what makes the host show its keyboard while the view is first responder. */
@interface TerminalView : UIView <UIKeyInput>

@property (nonatomic, weak) id<TerminalViewDelegate> delegate;
@property (nonatomic, strong, readonly) TerminalScreen *screen;
/* While set, a tap asks for a restart instead of the keyboard. */
@property (nonatomic) BOOL ended;

/* Redraws what the screen says changed; called after feeding it output. */
- (void)screenDidChange;

/* Keys for the extra-keys bar: these go through the same mapping as the
   hardware keys (application cursor mode, the Ctrl latch). */
- (void)sendSpecialKey:(unichar)functionKey;
- (void)sendText:(NSString *)text;
@property (nonatomic) BOOL controlLatched;

@end

/* The row of keys phone keyboards lack: Esc, Ctrl, Tab, arrows and a few
   symbols. It sits under the terminal. */
@interface TerminalKeyBar : UIView
@property (nonatomic, weak) TerminalView *terminalView;
@end
