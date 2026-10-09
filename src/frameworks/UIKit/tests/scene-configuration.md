# UISceneConfiguration value regression

Implements the name/role/sceneClass/delegateClass value object and the
documented application session role constant. It creates no scenes, sessions,
windows or delegates; UIWindowScene and UIApplicationMain remain absent.

Clean-room rung 3 specifications:

- [UISceneConfiguration](https://developer.apple.com/documentation/uikit/uisceneconfiguration):
  name, role, sceneClass, delegateClass, initializer and factory.
- [UIWindowSceneSessionRoleApplication](https://developer.apple.com/documentation/uikit/uiscenesession/role/windowapplication)
  and the Info.plist UIApplicationSceneManifest documentation, which uses the
  role names as plist keys.

Deliberately NOT defined: UIWindowSceneSessionRoleExternalDisplayNonInteractive and
UIWindowSceneSessionRoleAssistiveAccessApplication. No public specification of their
values could be fetched (DocC pages are script-rendered), and the symbol names are not
evidence of the strings; they stay unresolved imports.
Rung 6, local policy: a nil role raises NSInvalidArgumentException;
the storyboard property is omitted because UIStoryboard does not exist here.
Name and role are copied at initialization; copies duplicate all four values.
