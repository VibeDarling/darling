# UserNotifications and usernotificationsd

`ios-usernotifications.m` checks Darling's UserNotifications.framework
(`src/frameworks/UserNotifications`) and the daemon that keeps and fires
apps' notifications (`src/usernotificationsd`). It starts its own daemon on
a socket and store of its own (`USERNOTIFICATIONS_SOCKET`,
`USERNOTIFICATIONS_STORE`), and plays both the app and the presenter, the
part SpringBoard plays. Then it checks:

- **The classes.**
  - Content copies (mutable to immutable and back) with every field.
  - A request keeps its own copy of its content.
  - Requests survive secure coding.
  - Interval triggers refuse zero seconds, and repeating at under a minute.
- **When calendar triggers fire.**
  - Hour and minute, an hour alone (on the hour), and a second alone (every
    minute).
  - A weekday, a day of the month (its midnight), and February 29th (the
    next leap year).
  - A date matching now is the next one, and a date in the past never comes.
  - A repeating interval fires at whole intervals from its first date.
- **The daemon.**
  - Without it, adding a request fails with `UNErrorDomain`.
  - Pending requests come back with when they fire. Adding a request again
    replaces the pending one, and requests can be removed one at a time or
    all together.
  - A trigger that never fires is refused (`UNErrorCodeNotificationInvalidNoDate`).
  - A 1.5 s request comes due on time. With the app in the background, it goes
    straight to the presenter as a banner with sound, and into the delivered
    list.
  - Categories are kept. The presenter gets the category's actions with the
    notification.
  - What the user picks waits for the app until it sets a delegate, then
    reaches `didReceiveNotificationResponse:`. An answered notification
    leaves the delivered list.
  - With the app in front, its delegate is asked about each notification,
    which is shown as it says or not at all. Only one shown in the list is
    delivered.
  - Dismissals reach only apps whose category asks
    (`UNNotificationCategoryOptionCustomDismissAction`).
  - Removing a delivered notification withdraws it from the presenter.
  - Pending requests outlive a restart of the daemon.

It prints one PASS/FAIL line per check (37 in all) and exits nonzero on any
failure. It needs no display.

It builds as a Foundation program: compile with
`-I src/frameworks/UserNotifications/src` (for `UNLite.h`, the daemon's
protocol) and link `-framework UserNotifications -framework Foundation`.

Getting it to pass needed two fixes in Darling's CoreFoundation that are not
obvious:

- **`NSDateComponents` marked unset fields with `INT_MAX`.** On 64-bit, apps
  compare against `NSDateComponentUndefined` (`NSIntegerMax`), so every unset
  field looked set. Calendar triggers matched nothing.
- **`NSDate` did not support secure coding**, so no object holding a date
  could be archived with `requiringSecureCoding:YES`.
