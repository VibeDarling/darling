# UIDevice

Specification, rung 3 (DocC JSON fetched 2026-10-09):
https://developer.apple.com/documentation/uikit/uidevice and its member pages
(name, systemVersion, model, orientation, isMultitaskingSupported,
isGeneratingDeviceOrientationNotifications, begin/endGeneratingDeviceOrientationNotifications,
orientationDidChangeNotification, UIDeviceOrientation). Skeleton, orientation enum order
and notification string: Chameleon UIDevice.h/.m (BSD-3-Clause, LICENSE.Chameleon).

Behaviour and where each value comes from:

| member | value | basis |
|--------|-------|-------|
| currentDevice | process singleton | docs: "object that represents the current device" |
| name | same as model ("Mac") | rung 6: docs give a generic, model-like name to callers without the user-assigned-name entitlement (iOS 16+); the hostname would leak the host |
| systemVersion | host OS version, "major.minor[.patch]" | docs say "current version of the operating system"; format not specified, dotted decimal chosen (rung 6) |
| model | "Mac" | docs only give "iPhone", "iPod touch" as examples; "Mac" from Chameleon (rung 6) |
| orientation | UIDeviceOrientationUnknown | no sensor; Chameleon returns Portrait, which would assert a fact nobody measured |
| isMultitaskingSupported | YES | rung 6: Chameleon; no documented counterexample |
| isGeneratingDeviceOrientationNotifications | NO always | no accelerometer; begin/end calls are accepted and have no effect, so the property stays NO instead of claiming a source exists |

Unresolved, deliberately not implemented (a call fails with unrecognized selector instead of
returning an invented value):

- systemName: docs give no string; Darling's NSProcessInfo operatingSystemName returns
  "NS...OperatingSystem" enum names, not a platform name.
- userInterfaceIdiom and UIUserInterfaceIdiom: the enum constants' integer values and
  the idiom Darling should report are not on the public pages; Chameleon's enum differs
  from Apple's (Desktop = 2).
- localizedModel, identifierForVendor, battery and proximity members, playInputClick.
- UIDeviceOrientationDidChangeNotification string value equals the symbol name
  (Chameleon); Apple's value is unverified.
