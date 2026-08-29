import Foundation
import WidgetKit

/// One moment on the complication's timeline.
struct NextLessonEntry: TimelineEntry {
    /// How the lesson relates to the wearer's current position in the day.
    enum Status: String, Sendable {
        /// The lesson happening right now.
        case current
        /// The lesson that starts after this break.
        case upcoming
        /// The first lesson of a later school day.
        case future
        /// Lessons are over and the next day has not rolled in yet.
        case finished
    }

    let date: Date
    let lesson: Lesson?
    let status: Status
    /// When the shown lesson begins, used as a fallback subtitle.
    let startsAt: Date?
    /// When it ends. With `startsAt` this gives the span shown for any lesson
    /// that is not the one in progress.
    let endsAt: Date?
    /// The moment the countdown runs to: the end of the lesson in progress, or
    /// the start of the one after this break. `nil` once neither applies, so
    /// the widget never counts down to something the wearer is not waiting for.
    let countdownTarget: Date?

    static let placeholder = NextLessonEntry(
        date: .now,
        lesson: Lesson(period: 2, subject: "국어", teacher: "신영*", isReplaced: false, originalSubject: nil),
        status: .current,
        startsAt: nil,
        endsAt: nil,
        countdownTarget: .now.addingTimeInterval(23 * 60)
    )

    /// Reads the entry for a given instant out of a week of lessons.
    static func resolve(at date: Date, week: SchoolWeek) -> NextLessonEntry {
        let presentation = TimetablePresentation.resolve(now: date, week: week)
        let lesson = presentation.upcomingLesson()

        let status: Status
        switch presentation.indicator {
        case .duringLesson: status = .current
        case .duringBreak: status = .upcoming
        case .beforeFirstLesson: status = presentation.isFutureDay ? .future : .upcoming
        case .afterLastLesson: status = .finished
        }

        let startsAt = lesson
            .flatMap { week.bellSchedule.start(of: $0.period) }
            .map { SchoolClock.time($0, on: presentation.date) }
        let endsAt = lesson
            .flatMap { week.bellSchedule.end(of: $0.period) }
            .map { SchoolClock.time($0, on: presentation.date) }

        let countdownTarget: Date? = switch status {
        case .current: endsAt
        case .upcoming: startsAt
        case .future, .finished: nil
        }

        return NextLessonEntry(
            date: date,
            lesson: lesson,
            status: status,
            startsAt: startsAt,
            endsAt: endsAt,
            countdownTarget: countdownTarget
        )
    }
}
