// When a TimelineView's content is next due: its graph updates at its schedule's next date. A view
// that is no longer shown is not evaluated, so it schedules no further updates.
import Foundation

/// Updates come no more often than this, whatever the schedule asks.
private let shortestTimelineInterval = 1.0 / 12
private var pendingTimelines = Set<String>()

func scheduleTimelineUpdate<Schedule: TimelineSchedule>(_ graph: ViewGraph, identity: String, after now: Date, schedule: Schedule) {
    guard !pendingTimelines.contains(identity) else { return }
    var next: Date?
    for (index, date) in schedule.entries(from: now, mode: .normal).enumerated() {
        if date.timeIntervalSince(now) > 0.001 { next = date; break }
        if index > 10_000 { break }
    }
    guard let due = next else { return }
    pendingTimelines.insert(identity)
    DispatchQueue.main.asyncAfter(deadline: .now() + max(due.timeIntervalSince(now), shortestTimelineInterval)) { [weak graph] in
        pendingTimelines.remove(identity)
        graph?.invalidate("timeline")
    }
}
