import Foundation

/// What the timetable screen should show right now.
struct TimetablePresentation: Hashable, Sendable {
    var date: Date
    var lessons: [Lesson]
    var indicator: DayIndicator
    /// `true` once the day has rolled over to a future school day.
    var isFutureDay: Bool
    /// `true` only when the shown day is literally tomorrow.
    var isTomorrow: Bool

    /// Chooses the day and resolves the live indicator.
    ///
    /// After 17:00 — and all weekend — the screen jumps ahead to the next
    /// school day, where the indicator settles on `beforeFirstLesson`.
    static func resolve(now: Date, week: SchoolWeek) -> TimetablePresentation {
        let minutes = SchoolClock.minutesSinceMidnight(now)
        let rollsOver = !SchoolClock.isSchoolDay(now) || minutes >= BellSchedule.timetableRollover
        let target = rollsOver ? SchoolClock.nextSchoolDay(after: now) : now
        let lessons = week.lessons(on: target)

        let indicator: DayIndicator = rollsOver
            ? .beforeFirstLesson
            : .resolve(minutes: minutes, lessons: lessons, schedule: week.bellSchedule)

        return TimetablePresentation(
            date: target,
            lessons: lessons,
            indicator: indicator,
            isFutureDay: rollsOver,
            isTomorrow: SchoolDate(target) == SchoolDate(now).adding(days: 1)
        )
    }

    /// The lesson that starts next, used by the complication.
    func upcomingLesson() -> Lesson? {
        switch indicator {
        case .beforeFirstLesson:
            lessons.min { $0.period < $1.period }
        case .duringLesson(let period):
            lessons.first { $0.period == period }
        case .duringBreak(let period):
            lessons.filter { $0.period > period }.min { $0.period < $1.period }
        case .afterLastLesson:
            nil
        }
    }
}

/// What one meal page should show, and in which order the pages sit.
struct MealPresentation: Hashable, Sendable, Identifiable {
    var kind: MealKind
    var date: SchoolDate
    /// `true` when the shown day is not today — the page shows a "내일" flag.
    var isFutureDay: Bool
    /// `true` only when the shown day is literally tomorrow.
    var isTomorrow: Bool

    var id: MealKind { kind }

    /// Resolves both pages plus their order for `now`.
    ///
    /// 중식 rolls over at 13:10 and 석식 at 18:40. A service missing today rolls
    /// over immediately, and the earliest actually published service leads.
    static func pages(now: Date, calendar: MealServiceCalendar?) -> [MealPresentation] {
        let minutes = SchoolClock.minutesSinceMidnight(now)
        let today = SchoolDate(now)

        let lunch = page(
            kind: .lunch,
            rolledOver: calendar.map { !$0.serves(.lunch, on: today) } ?? false
                || minutes >= BellSchedule.lunchCutoff,
            today: today,
            calendar: calendar
        )
        let dinner = page(
            kind: .dinner,
            rolledOver: calendar.map { !$0.serves(.dinner, on: today) } ?? false
                || minutes >= BellSchedule.dinnerCutoff,
            today: today,
            calendar: calendar
        )

        return upcoming(now: now, calendar: calendar).kind == .dinner
            ? [dinner, lunch]
            : [lunch, dinner]
    }

    /// The single meal a glance should be about: the next service that has not
    /// been served yet.
    ///
    /// Availability is service-specific: a lunch-only day must not invent a
    /// dinner, and a long holiday skips directly to the next published date.
    static func upcoming(now: Date, calendar: MealServiceCalendar?) -> MealPresentation {
        let minutes = SchoolClock.minutesSinceMidnight(now)
        let today = SchoolDate(now)

        guard let calendar else {
            if minutes < BellSchedule.lunchCutoff { return current(.lunch, on: today) }
            if minutes < BellSchedule.dinnerCutoff { return current(.dinner, on: today) }
            return future(.lunch, on: today.adding(days: 1), relativeTo: today)
        }

        if minutes < BellSchedule.lunchCutoff, calendar.serves(.lunch, on: today) {
            return current(.lunch, on: today)
        }
        if minutes < BellSchedule.dinnerCutoff, calendar.serves(.dinner, on: today) {
            return current(.dinner, on: today)
        }

        let candidates = [MealKind.lunch, .dinner].compactMap { kind -> MealPresentation? in
            guard let date = calendar.nextDay(for: kind, after: today) else { return nil }
            return future(kind, on: date, relativeTo: today)
        }
        return candidates.min(by: comesBefore) ?? current(.lunch, on: today)
    }

    private static func page(
        kind: MealKind,
        rolledOver: Bool,
        today: SchoolDate,
        calendar: MealServiceCalendar?
    ) -> MealPresentation {
        guard rolledOver else {
            return current(kind, on: today)
        }
        if let target = calendar?.nextDay(for: kind, after: today) {
            return future(kind, on: target, relativeTo: today)
        }
        // With no snapshot, tomorrow is the best provisional answer. A known
        // empty calendar stays on today rather than claiming an unpublished
        // meal exists tomorrow.
        guard calendar == nil else { return current(kind, on: today) }
        return future(kind, on: today.adding(days: 1), relativeTo: today)
    }

    private static func current(_ kind: MealKind, on date: SchoolDate) -> MealPresentation {
        MealPresentation(kind: kind, date: date, isFutureDay: false, isTomorrow: false)
    }

    private static func future(
        _ kind: MealKind,
        on date: SchoolDate,
        relativeTo today: SchoolDate
    ) -> MealPresentation {
        MealPresentation(
            kind: kind,
            date: date,
            isFutureDay: true,
            isTomorrow: date == today.adding(days: 1)
        )
    }

    private static func comesBefore(_ lhs: MealPresentation, _ rhs: MealPresentation) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        return lhs.kind.rawValue < rhs.kind.rawValue
    }
}
