# Settings

iOS's Settings app (bundle identifier `com.apple.Preferences`, executable
`Preferences`), written on Darling's own Preferences.framework
(`src/private-frameworks/Preferences`). It installs to
`libexec/darling/Applications/Preferences.app`, so SpringBoard-lite lists it.

| File | What it is |
| --- | --- |
| `Settings.m` | the pages (Settings, General, About), PreferenceLoader support, the app delegate |
| `Info.plist`, `AppIcon60x60*.png` | the bundle; `make-icon.py` redraws the icon |

## Pages

- **Settings:** General, then a Tweaks group with a row per PreferenceLoader
  entry, sorted by label.
- **General > About:** device name, iOS version (14.0), model, kernel,
  architecture, and the home file system's capacity and free space.

## Tweaks' settings

As with PreferenceLoader on iOS, a tweak installs a plist into
`/Library/PreferenceLoader/Preferences` (or, rootless,
`/var/jb/Library/PreferenceLoader/Preferences`). Its `entry` dictionary is
the row:

- with `bundle` (and `isController`), the row opens that bundle from
  `/Library/PreferenceBundles` when tapped, and the bundle's principal
  class (a `PSListController` subclass) is the page;
- without it, the plist's own `items` are the page (`PLCustomListController`).

The icon is `entry`'s `icon`, from the bundle or next to the plist, scaled
to 29 points; rows without one get a gray letter tile.
