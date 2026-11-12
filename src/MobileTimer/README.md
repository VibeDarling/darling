# Clock

iOS's Clock app (bundle identifier `com.apple.mobiletimer`, executable
`MobileTimer`). It installs to `libexec/darling/Applications/MobileTimer.app`.

| Tab | What it does |
| --- | --- |
| World Clock | Cities with their time, day and offset from here. **Edit** deletes them; **+** picks one from the time zones, with a search field. |
| Alarm | Alarms with a switch each. **+** or a tap edits one: time, repeat days, label, snooze. |
| Stopwatch | Start and Stop, and Lap and Reset, with the laps listed. |
| Timer | Hours, minutes and seconds. Start, Pause and Resume, and Cancel. |

Alarms and the timer are local notifications (UserNotifications), so they go
off with Clock closed:

- usernotificationsd fires them, and SpringBoard rings them as alerts that
  ring until answered (their sounds are critical).
- An alarm that allows snoozing has **Snooze**, which wakes Clock in the
  background to schedule it again nine minutes later.
- A one-time alarm turns itself off once it has gone off.

Everything else is kept in the app's defaults (`com.apple.mobiletimer`). The
stopwatch and timer keep counting from their saved dates while Clock is
closed.

`make-icon.py` redraws the icon.
