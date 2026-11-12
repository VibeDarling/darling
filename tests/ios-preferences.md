# Preferences.framework

`ios-preferences.m` checks Darling's Preferences.framework
(`src/private-frameworks/Preferences`) the way tweak preference bundles use
it. It writes a settings bundle (`Root.plist`, `Detail.plist` and an English
`Root.strings`) to a temporary directory and shows a `PSListController`
subclass that loads it, inside a `PSRootController`. Then it checks:

- **Loading the plist.**
  - Every item becomes a specifier, and the page title and labels are
    localized from the strings table.
  - A link list gets its value titles and `PSListItemsController`.
  - A text field becomes a `PSTextFieldSpecifier` with its placeholder and
    keyboard traits (`keyboard`, `autoCaps`, `noAutoCorrect`).
  - A button gets its action.
- **The table.**
  - Group specifiers start the sections, with headers and footers.
  - Rows before the first group form a section without a header.
  - Each row has its cell class (switch, slider, segments, text field),
    showing the stored value or the plist's `default`.
- **Changing settings.**
  - Tapping the switch, with real pointer events, stores the value under its
    `key` in the `defaults` domain's plist. It also posts its
    `PostNotification`, observed through the Darwin notify center.
  - The slider, segments and text field (on return) store their values.
  - Tapping a row of a radio group (`isRadioGroup`) stores the row's
    `value` under the group's key and moves the checkmark.
  - A button calls its action with the specifier.
- **Pages.**
  - Tapping the link list pushes its choices with the current one checked.
    A tap stores the new choice, and back on the page the row shows it.
  - A link pushes its `detail` controller with its parent and specifier, and
    the controller's plist names the page.
- **Changing the specifiers.**
  - Inserting, removing and adding specifiers and groups updates the table.
  - Disabling a specifier and reloading it disables its control.
  - `reloadSpecifiers` keeps the loaded specifiers.
  - `SpecifiersFromPlist` works on its own.

It prints one PASS/FAIL line per check (36 in all), leaves the page up for
three seconds for a screenshot, and exits nonzero on any failure.

It builds like `ios-uikit-classes.m`, also passing
`-F $SDK/System/iOSSupport/System/Library/PrivateFrameworks` when compiling,
and `-F $R/System/iOSSupport/System/Library/PrivateFrameworks -framework
Preferences` when linking.

Getting the pages to look right needed a fix that is not obvious:

- **Images were drawn upside down in every UIKit view.** Cocotron's
  `-[NSImage drawInRect:fromRect:operation:fraction:respectFlipped:hints:]`
  ignored `respectFlipped`, and all UIKit views are flipped. Symmetric icons
  hid this. It showed as a mirrored "S" on a settings row icon. The method
  now flips the image back within its rect when the context is flipped.
