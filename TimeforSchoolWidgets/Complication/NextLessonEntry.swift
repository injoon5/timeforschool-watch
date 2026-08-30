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

    /// How many slots the Smart Stack card lays out. The lesson in focus
    /// always holds the middle one.
    static let slotCount = 3

    let date: Date
    let lesson: Lesson?
    let status: Status
    /// The three slots drawn on the rectangular card. The focus sits in the
    /// middle one and its neighbours flank it, so the crest of the arch never
    /// moves. At either end of the day the outer slot is simply empty — that
    /// gap is the edge of the day, and worth showing.
    let slots: [Lesson?]
    /// When the shown lesson begins, used as a fallback subtitle.
    let startsAt: Date?
    /// When it ends. With `startsAt` this gives the span shown for any lesson
    /// that is not the one in progress.
    let endsAt: Date?
    /// When the break before an upcoming lesson began, so the card can fill a
    /// progress track across the break the same way it does across a lesson.
    let breakStartedAt: Date?
    /// `true` when the focused lesson closes the day.
    let isLastLesson: Bool
    /// "내일", "월요일" — set only when the card has jumped to a later day.
    let dayLabel: String?
    /// How far through the day the focus sits, 0 at the first period and 1 at
    /// the last. The card's colour warms across it.
    let dayProgress: CGFloat
    /// The moment the countdown runs to: the end of the lesson in progress, or
    /// the start of the one after this break. `nil` once neither applies, so
    /// the widget never counts down to something the wearer is not waiting for.
    let countdownTarget: Date?

    init(
        date: Date,
        lesson: Lesson?,
        status: Status,
        slots: [Lesson?] = [],
        startsAt: Date?,
        endsAt: Date?,
        breakStartedAt: Date? = nil,
        isLastLesson: Bool = false,
        dayLabel: String? = nil,
        dayProgress: CGFloat = 0.5,
        countdownTarget: Date?
    ) {
        self.date = date
        self.lesson = lesson
        self.status = status
        self.slots = slots.isEmpty ? [nil, lesson, nil] : slots
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.breakStartedAt = breakStartedAt
        self.isLastLesson = isLastLesson
        self.dayLabel = dayLabel
        self.dayProgress = dayProgress
        self.countdownTarget = countdownTarget
    }

    static let placeholder = NextLessonEntry(
        date: .now,
        lesson: Lesson(period: 2, subject: "국어", teacher: "신영*", isReplaced: false, originalSubject: nil),
        status: .current,
        slots: [
            Lesson(period: 1, subject: "체육", teacher: "임건*", isReplaced: false, originalSubject: nil),
            Lesson(period: 2, subject: "국어", teacher: "신영*", isReplaced: false, originalSubject: nil),
            Lesson(period: 3, subject: "수학", teacher: "최민*", isReplaced: false, originalSubject: nil),
        ],
        startsAt: .now.addingTimeInterval(-27 * 60),
        endsAt: .now.addingTimeInterval(23 * 60),
        countdownTarget: .now.addingTimeInterval(23 * 60)
    )

    /// Reads the entry for a given instant out of a week of lessons.
    static func resolve(at date: Date, week: SchoolWeek) -> NextLessonEntry {
        let presentation = TimetablePresentation.resolve(now: date, week: week)
        let lesson = presentation.upcomingLesson()
        let lessons = presentation.lessons.sorted { $0.period < $1.period }

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

        let breakStartedAt: Date? = switch presentation.indicator {
        case .duringBreak(let period):
            week.bellSchedule.end(of: period).map { SchoolClock.time($0, on: presentation.date) }
        default:
            nil
        }

        let countdownTarget: Date? = switch status {
        case .current: endsAt
        case .upcoming: startsAt
        case .future, .finished: nil
        }

        return NextLessonEntry(
            date: date,
            lesson: lesson,
            status: status,
            slots: slots(around: lesson, in: lessons),
            startsAt: startsAt,
            endsAt: endsAt,
            breakStartedAt: breakStartedAt,
            isLastLesson: lesson != nil && lesson?.period == lessons.last?.period,
            dayLabel: presentation.isFutureDay ? dayLabel(for: presentation) : nil,
            dayProgress: dayProgress(of: lesson, in: lessons),
            countdownTarget: countdownTarget
        )
    }

    /// The focus and its two neighbours, focus in the middle.
    ///
    /// The first period of a day has nothing to its left and the last has
    /// nothing to its right; those slots stay empty rather than sliding the
    /// focus off centre. Once the day is over there is no focus at all, so the
    /// card settles on the lesson that closed it.
    static func slots(around focus: Lesson?, in lessons: [Lesson]) -> [Lesson?] {
        guard !lessons.isEmpty else { return [] }
        let centre = focus
            .flatMap { current in lessons.firstIndex { $0.period == current.period } }
            ?? lessons.count - 1
        return (-1...1).map { offset in
            let index = centre + offset
            return lessons.indices.contains(index) ? lessons[index] : nil
        }
    }

    /// Where the focus sits between the first period and the last. With the
    /// day over there is no focus, and the day has run its full length.
    static func dayProgress(of focus: Lesson?, in lessons: [Lesson]) -> CGFloat {
        guard lessons.count > 1 else { return 0.5 }
        let index = focus
            .flatMap { current in lessons.firstIndex { $0.period == current.period } }
            ?? lessons.count - 1
        return CGFloat(index) / CGFloat(lessons.count - 1)
    }

    private static func dayLabel(for presentation: TimetablePresentation) -> String {
        presentation.isTomorrow
            ? "내일"
            : "\(SchoolClock.koreanWeekdaySymbol(for: presentation.date))요일"
    }
}
