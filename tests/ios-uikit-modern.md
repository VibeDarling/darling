# UIKit from iOS 8 to 14

`ios-uikit-modern.m` checks the UIKit API that apps built with a current
Xcode use most and that Darling's UIKit lacked:

- **Scenes.** The app has a scene manifest (and a main storyboard that does
  not exist, which a scene app must not load).
  - The app delegate is asked for the configuration. The scene delegate
    class comes from the Info.plist, under its Swift-style
    `Module.SceneDelegate` name.
  - The scene connects, enters the foreground and becomes active, in that
    order. The app delegate's `applicationDidBecomeActive:` is not sent,
    but the notification is still posted.
  - The window made with `initWithWindowScene:` belongs to the scene, and
    the application lists the scene and its session.
- **Trait collections.** A view's traits are a phone's, light, with size
  classes and scale from the screen. An `overrideUserInterfaceStyle`
  reaches subviews, which get `traitCollectionDidChange:`. Dynamic colors
  are resolved for the current traits. Collections merge and contain.
- **UIAlertController.**
  - An alert shows the app's text field and its actions, cancel first.
  - A disabled action does nothing until it is enabled.
  - Choosing an action dismisses the alert, then runs the handler, which
    reads the text field.
  - An action sheet puts the destructive action first and cancel apart.
  - An alert the app dismisses runs no action.
  - A second cancel action raises.
- **UIStackView.**
  - A filled row: fixed widths, spacing, the rest to the last view.
  - A hidden view takes no room.
  - Fill equally and equal spacing.
  - A centered column of intrinsic sizes (a label and a `UIStepper`).
- **Small classes.**
  - `UIVisualEffectView` puts subviews in its content view.
  - The feedback generators accept requests.
  - `UIFontMetrics` at the default size, with a maximum.
  - `UIStepper` steps to its maximum, wraps both ways, clamps its value.
- **Animations.**
  - The spring and keyframe methods run their blocks and complete.
  - `UIViewPropertyAnimator` applies its animations when started and
    finishes at the end. Pausing keeps its progress, and it stops and
    finishes at the current position. A running animator completes.
- **Menus and key commands.**
  - A button's primary `UIAction` is sent by the button, and a removed
    one is not.
  - A button's menu shows as an action sheet, inline menus in line, and a
    row runs its action.
  - A long press on a view with a `UIContextMenuInteraction` shows its
    menu.
  - Command-K reaches the root controller's `UIKeyCommand`, and K alone
    does not.
- **UISearchController.**
  - From `navigationItem.searchController`, the bar sits under the
    navigation bar and the content under the bar.
  - Editing the bar activates the search, and the results controller's
    view covers the window below the bar.
  - The updater hears of each change, and cancel ends the search.
- **UILocalNotification**, against a `usernotificationsd` the test starts
  on a socket of its own:
  - A scheduled notification comes back from `scheduledLocalNotifications`
    with its body, user info and fire date, and can be cancelled.
  - One presented now, with the app in front, reaches
    `application:didReceiveLocalNotification:`.
- **Diffable data sources.**
  - A snapshot keeps sections and unique items in order. A duplicate
    raises. Items move and are deleted.
  - Applying it to a table's data source gives the sections, rows and
    cells. A collection view's works too.

It prints one PASS/FAIL line per check, then leaves a blurred band and an
alert up for six seconds, for a screenshot. It exits nonzero on any
failure. It needs a display (the Pocket host or X11).

It builds as `ios-uikit-classes.m` does (see `ios-uikit-classes.md`), also
linking `-framework AppKit`, into `ModernTest.app/ModernTest`, marked iOS.
Its `Info.plist` names the executable and holds the scene manifest:

```xml
<key>UIMainStoryboardFile</key><string>DoesNotExist</string>
<key>UIApplicationSceneManifest</key>
<dict>
	<key>UISceneConfigurations</key>
	<dict>
		<key>UIWindowSceneSessionRoleApplication</key>
		<array>
			<dict>
				<key>UISceneConfigurationName</key><string>Default Configuration</string>
				<key>UISceneDelegateClassName</key><string>ModernTest.SceneDelegate</string>
			</dict>
		</array>
	</dict>
</dict>
```

Getting it to pass needed fixes that are not obvious:

- **The spring, keyframe and transition animation methods were missing.**
  The log-and-nil fallback answered them, so their animation blocks never
  ran and their completions never came.
- **An alert controller is not a view.** Presenting one shows a UIAlertView
  or UIActionSheet instead of putting its view over the presenter's, and
  dismissing it takes that down (`-uikitPresentsItself`).
