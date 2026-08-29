import Foundation

/// A cached timetable plus the moment it was fetched.
struct TimetableSnapshot: Codable, Sendable {
    var identity: SchoolIdentity
    var week: SchoolWeek
    var fetchedAt: Date

    /// Timetables can change during the day (substitutions), but not often.
    static let maxAge: TimeInterval = 4 * 60 * 60

    func isStale(now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > Self.maxAge
            || !SchoolClock.calendar.isDate(fetchedAt, inSameDayAs: now)
    }
}

/// A cached window of meals.
///
/// Menus are published weeks ahead and effectively never change, so the app
/// keeps a month on disk. That is what makes the meals screen work offline and
/// lets the widget answer without touching the network.
struct MealSnapshot: Codable, Sendable {
    var identity: SchoolIdentity
    var meals: [Meal]
    var windowStart: SchoolDate
    var windowEnd: SchoolDate
    var fetchedAt: Date

    static let maxAge: TimeInterval = 12 * 60 * 60
    /// Days of menu the cache tries to stay ahead of today.
    static let lookahead = 30
    /// Refresh early enough that the window never runs dry while offline.
    static let minimumLookahead = 7

    func isStale(now: Date) -> Bool {
        let today = SchoolDate(now)
        return now.timeIntervalSince(fetchedAt) > Self.maxAge
            || windowStart > today
            || windowEnd < today.adding(days: Self.minimumLookahead)
    }

    func meal(kind: MealKind, on day: SchoolDate) -> Meal? {
        meals.first { $0.kind == kind && $0.day == day }
    }

    /// Published dates by service. An empty value is meaningful: the server
    /// successfully reported that the window contains no meals.
    func serviceCalendar() -> MealServiceCalendar {
        MealServiceCalendar(meals: meals)
    }
}
