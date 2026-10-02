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
    /// `false` when the loaded calendar holds no service of this kind still to
    /// come: every published date is behind us. The page then has a day on it
    /// only so it has something to key on — there is nothing left to serve, and
    /// falling back to a meal already eaten would claim otherwise.
    var hasService: Bool = true

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
        // Nothing published from today onwards: both services have rolled over
        // and the calendar names no later date. There is no next meal to point
        // at, and today's lunch is not it.
        return candidates.min(by: comesBefore) ?? exhausted(.lunch, on: today)
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
        // calendar with nothing left to serve says so rather than falling back
        // to today's service, which has already been served by definition —
        // this branch only runs once that service has rolled over.
        guard calendar == nil else { return exhausted(kind, on: today) }
        return future(kind, on: today.adding(days: 1), relativeTo: today)
    }

    private static func current(_ kind: MealKind, on date: SchoolDate) -> MealPresentation {
        MealPresentation(kind: kind, date: date, isFutureDay: false, isTomorrow: false)
    }

    private static func exhausted(_ kind: MealKind, on date: SchoolDate) -> MealPresentation {
        MealPresentation(
            kind: kind,
            date: date,
            isFutureDay: false,
            isTomorrow: false,
            hasService: false
        )
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

/// Whether the meal snapshot has anything to say yet.
enum MealAvailability: Sendable {
    case loading
    case loaded
    /// Nothing cached and the network could not supply anything either.
    case unavailable
}

/// What a meal surface actually knows about one service on one day.
///
/// "No menu" and "no answer" look identical on screen unless they are kept
/// apart here: a failed first fetch, a day the cached window never covered, and
/// a day the school genuinely serves nothing are three different facts, and
/// only the last of them is "급식 없음".
enum MealContent: Hashable, Sendable {
    /// A published menu.
    case menu(Meal)
    /// Nothing cached yet, and the first fetch is still running.
    case loading
    /// Nothing cached and the fetch failed.
    case unreachable
    /// The cached window covers this day and the school serves nothing on it.
    case unpublished
    /// The cached window stops short of this day, so nothing is known about it.
    case unknown
    /// The calendar holds no service of this kind still to come.
    case noService

    static func resolve(
        presentation: MealPresentation,
        snapshot: MealSnapshot?,
        availability: MealAvailability
    ) -> MealContent {
        guard presentation.hasService else { return .noService }
        guard let snapshot else {
            return availability == .unavailable ? .unreachable : .loading
        }
        if let meal = snapshot.meal(kind: presentation.kind, on: presentation.date),
           !meal.dishes.isEmpty {
            return .menu(meal)
        }
        // A day the window never reached says nothing about that day. Only a
        // covered day can report an empty menu as fact.
        guard snapshot.covers(presentation.date) else { return .unknown }
        return .unpublished
    }

    /// The whole state in one line, for surfaces with room for nothing else.
    var briefText: String {
        switch self {
        case .menu(let meal): meal.dishes.joined(separator: ", ")
        case .loading: "불러오는 중"
        case .unreachable: "불러올 수 없음"
        case .unpublished: "급식 없음"
        case .unknown: "정보 없음"
        case .noService: "예정된 급식 없음"
        }
    }
}
