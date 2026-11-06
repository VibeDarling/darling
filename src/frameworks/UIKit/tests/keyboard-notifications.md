# Keyboard notification names

Exports the six documented keyboard notification constants. Nothing posts them:
UIKit here has no keyboard, so no producer exists and none is faked.

Specification, rung 3 (fetched 2026-10-09 from the DocC JSON behind each page):

- https://developer.apple.com/documentation/uikit/uiresponder/keyboardwillshownotification
- https://developer.apple.com/documentation/uikit/uiresponder/keyboarddidshownotification
- https://developer.apple.com/documentation/uikit/uiresponder/keyboardwillhidenotification
- https://developer.apple.com/documentation/uikit/uiresponder/keyboarddidhidenotification
- https://developer.apple.com/documentation/uikit/uiresponder/keyboardwillchangeframenotification
- https://developer.apple.com/documentation/uikit/uiresponder/keyboarddidchangeframenotification

The pages specify names, type (NSNotification.Name) and that the object is a screen in
iOS 16.1+ and nil before. They do NOT give the string values. Values equal the symbol
names, taken from Chameleon UIWindow.m (BSD-3-Clause, LICENSE.Chameleon). Unresolved:
whether Apple's strings are identical. Observers inside one process only need the
constants to be unique and stable, which the test checks.

Not exported: the userInfo key constants (not imported by Messages), and the private
UIKeyboardRenderDidFinishNotification.
