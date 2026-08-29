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
    /// 중식 rolls over at 13:10 and 석식 at 18:40; whichever meal has already
    /// rolled over sinks below the one still ahead of the wearer.
    static func pages(now: Date, availableDays: Set<SchoolDate>) -> [MealPresentation] {
        let minutes = SchoolClock.minutesSinceMidnight(now)
        let today = SchoolDate(now)

        // A day the school serves nothing — a weekend or a holiday — has
        // nothing to wait for, so both pages move on rather than showing two
        // empty screens until 18:40.
        let servesToday = availableDays.isEmpty || availableDays.contains(today)

        let lunch = page(
            kind: .lunch,
            rolledOver: !servesToday || minutes >= BellSchedule.lunchCutoff,
            today: today,
            availableDays: availableDays
        )
        let dinner = page(
            kind: .dinner,
            rolledOver: !servesToday || minutes >= BellSchedule.dinnerCutoff,
            today: today,
            availableDays: availableDays
        )

        return minutes < BellSchedule.lunchCutoff ? [lunch, dinner] : [dinner, lunch]
    }

    /// The single meal a glance should be about: the next service that has not
    /// been served yet.
    ///
    /// This is not simply the first of `pages`. Between 13:10 and 18:40 the
    /// pages lead with 석식 because 중식 has already been eaten — but once 석식
    /// has been served too, the next thing anyone is waiting for is *tomorrow's
    /// 중식*, not tomorrow's 석식, which is a whole day away.
    static func upcoming(now: Date, availableDays: Set<SchoolDate>) -> MealPresentation {
        let minutes = SchoolClock.minutesSinceMidnight(now)
        let today = SchoolDate(now)
        let servesToday = availableDays.isEmpty || availableDays.contains(today)

        if servesToday {
            if minutes < BellSchedule.lunchCutoff {
                return MealPresentation(kind: .lunch, date: today, isFutureDay: false, isTomorrow: false)
            }
            if minutes < BellSchedule.dinnerCutoff {
                return MealPresentation(kind: .dinner, date: today, isFutureDay: false, isTomorrow: false)
            }
        }
        return page(kind: .lunch, rolledOver: true, today: today, availableDays: availableDays)
    }

    private static func page(
        kind: MealKind,
        rolledOver: Bool,
        today: SchoolDate,
        availableDays: Set<SchoolDate>
    ) -> MealPresentation {
        guard rolledOver else {
            return MealPresentation(kind: kind, date: today, isFutureDay: false, isTomorrow: false)
        }
        let tomorrow = today.adding(days: 1)
        // Skip weekends and holidays so the page lands on a day that has food.
        let target = (1...7)
            .lazy
            .map { today.adding(days: $0) }
            .first { availableDays.contains($0) } ?? tomorrow

        return MealPresentation(
            kind: kind,
            date: target,
            isFutureDay: true,
            isTomorrow: target == tomorrow
        )
    }
}
