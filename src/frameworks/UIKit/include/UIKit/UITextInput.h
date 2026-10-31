/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UITEXTINPUT_H
#define UIKIT_UITEXTINPUT_H

#import <UIKit/UITextField.h>

/*
 * A view that takes typing without being a text field (a terminal, a game).
 * When such a view becomes first responder the host shows its keyboard, as
 * for a text field. Typed text arrives as -insertText: (Return as "\n"),
 * and the Delete key as -deleteBackward. A view that wants other keys
 * (arrows, Escape, modifiers) can still override AppKit's -keyDown:.
 */
@protocol UIKeyInput <UITextInputTraits>
- (BOOL)hasText;
- (void)insertText:(NSString *)text;
- (void)deleteBackward;
@end

#endif /* UIKIT_UITEXTINPUT_H */
