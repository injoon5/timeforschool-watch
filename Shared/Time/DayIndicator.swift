import Foundation

/// Where "now" sits relative to the lessons on screen.
///
/// The timetable draws this as a filled row, a rule between two rows, or a dot
/// above/below the list — the single piece of state the whole screen keys off.
enum DayIndicator: Hashable, Sendable {
    /// Before the first bell — a dot sits above the list.
    case beforeFirstLesson
    /// Inside a lesson — that row is filled.
    case duringLesson(period: Int)
    /// Between two lessons — a rule is drawn after `period`.
    case duringBreak(afterPeriod: Int)
    /// After the last bell — a dot sits below the list.
    case afterLastLesson

    /// Resolves the indicator for `time` against the lessons of a single day.
    ///
    /// - Parameter minutes: minutes since midnight, school time zone.
    static func resolve(minutes: Int, lessons: [Lesson], schedule: BellSchedule) -> DayIndicator {
        let periods = lessons.map(\.period).sorted()
        guard let first = periods.first, let last = periods.last,
              let dayStart = schedule.start(of: first), let dayEnd = schedule.end(of: last)
        else { return .beforeFirstLesson }

        if minutes < dayStart { return .beforeFirstLesson }
        if minutes >= dayEnd { return .afterLastLesson }

        for period in periods {
            guard let start = schedule.start(of: period), let end = schedule.end(of: period) else { continue }
            if minutes >= start && minutes < end { return .duringLesson(period: period) }
        }
        // Between two lessons: find the last one that has already finished.
        let finished = periods.last { schedule.end(of: $0).map { minutes >= $0 } ?? false }
        return .duringBreak(afterPeriod: finished ?? first)
    }
}
