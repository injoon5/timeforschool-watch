import Foundation
import Testing
@testable import TimeforSchool

@Suite("Meal presentation")
struct MealPresentationTests {
    @Test("A lunch-only day does not invent dinner")
    func lunchOnlyDay() throws {
        let now = try date(year: 2026, month: 8, day: 3, hour: 14)
        let today = SchoolDate(now)
        let nextLunch = today.adding(days: 1)
        let calendar = MealServiceCalendar(meals: [
            meal(.lunch, on: today),
            meal(.lunch, on: nextLunch),
        ])

        let upcoming = MealPresentation.upcoming(now: now, calendar: calendar)

        #expect(upcoming.kind == .lunch)
        #expect(upcoming.date == nextLunch)
        #expect(upcoming.isFutureDay)
    }

    @Test("A known empty response does not claim tomorrow has food")
    func knownEmptyCalendar() throws {
        let now = try date(year: 2026, month: 8, day: 3, hour: 14)
        let today = SchoolDate(now)

        let pages = MealPresentation.pages(
            now: now,
            calendar: MealServiceCalendar(meals: [])
        )

        #expect(pages.allSatisfy { $0.date == today })
        #expect(pages.allSatisfy { !$0.isFutureDay })
    }

    @Test("Lunch leads after dinner when both services are next served together")
    func lunchLeadsAfterDinner() throws {
        let now = try date(year: 2026, month: 8, day: 3, hour: 19)
        let tomorrow = SchoolDate(now).adding(days: 1)
        let calendar = MealServiceCalendar(meals: [
            meal(.lunch, on: tomorrow),
            meal(.dinner, on: tomorrow),
        ])

        let pages = MealPresentation.pages(now: now, calendar: calendar)

        #expect(pages.first?.kind == .lunch)
        #expect(pages.first?.date == tomorrow)
    }

    @Test("A published meal more than seven days away is still selected")
    func longVacation() throws {
        let now = try date(year: 2026, month: 8, day: 3, hour: 14)
        let nextService = SchoolDate(now).adding(days: 10)
        let calendar = MealServiceCalendar(meals: [meal(.lunch, on: nextService)])

        let pages = MealPresentation.pages(now: now, calendar: calendar)

        #expect(pages.first?.kind == .lunch)
        #expect(pages.first?.date == nextService)
    }

    @Test("A calendar with nothing left to serve does not reoffer a served meal")
    func nothingLeftToServe() throws {
        // Friday evening: lunch was served and published, dinner never was, and
        // the calendar names no later date.
        let now = try date(year: 2026, month: 8, day: 7, hour: 19)
        let today = SchoolDate(now)
        let calendar = MealServiceCalendar(meals: [meal(.lunch, on: today)])

        let upcoming = MealPresentation.upcoming(now: now, calendar: calendar)

        #expect(!upcoming.hasService)
        #expect(!upcoming.isFutureDay)
        #expect(MealPresentation.pages(now: now, calendar: calendar).allSatisfy { !$0.hasService })
    }

    @Test("A page with no service to come shows that, not the day's menu")
    func noServiceBeatsAServedMenu() throws {
        let now = try date(year: 2026, month: 8, day: 7, hour: 19)
        let today = SchoolDate(now)
        let served = meal(.lunch, on: today)
        let snapshot = snapshot(meals: [served], from: today, to: today.adding(days: 30))

        let page = MealPresentation.upcoming(now: now, calendar: snapshot.serviceCalendar())
        let content = MealContent.resolve(presentation: page, snapshot: snapshot, availability: .loaded)

        #expect(content == .noService)
    }

    @Test("A first fetch still running is not a confirmed empty menu")
    func loadingIsNotEmpty() throws {
        let page = MealPresentation(
            kind: .lunch,
            date: SchoolDate(try date(year: 2026, month: 8, day: 3, hour: 9)),
            isFutureDay: false,
            isTomorrow: false
        )

        #expect(MealContent.resolve(presentation: page, snapshot: nil, availability: .loading) == .loading)
        #expect(MealContent.resolve(presentation: page, snapshot: nil, availability: .unavailable) == .unreachable)
    }

    @Test("A day the cached window never covered is unknown, not empty")
    func uncoveredDayIsUnknown() throws {
        let today = SchoolDate(try date(year: 2026, month: 8, day: 3, hour: 9))
        let covered = snapshot(meals: [], from: today, to: today.adding(days: 3))

        let inside = MealContent.resolve(
            presentation: page(.lunch, on: today),
            snapshot: covered,
            availability: .loaded
        )
        let outside = MealContent.resolve(
            presentation: page(.lunch, on: today.adding(days: 10)),
            snapshot: covered,
            availability: .loaded
        )

        #expect(inside == .unpublished)
        #expect(outside == .unknown)
    }

    @Test("A published menu is returned as itself")
    func publishedMenu() throws {
        let today = SchoolDate(try date(year: 2026, month: 8, day: 3, hour: 9))
        let served = meal(.lunch, on: today)

        let content = MealContent.resolve(
            presentation: page(.lunch, on: today),
            snapshot: snapshot(meals: [served], from: today, to: today.adding(days: 30)),
            availability: .loaded
        )

        #expect(content == .menu(served))
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) throws -> Date {
        try #require(SchoolClock.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        ))
    }

    private func meal(_ kind: MealKind, on day: SchoolDate) -> Meal {
        Meal(kind: kind, day: day, dishes: ["메뉴"], calories: nil)
    }

    private func page(_ kind: MealKind, on day: SchoolDate) -> MealPresentation {
        MealPresentation(kind: kind, date: day, isFutureDay: false, isTomorrow: false)
    }

    private func snapshot(
        meals: [Meal],
        from start: SchoolDate,
        to end: SchoolDate
    ) -> MealSnapshot {
        MealSnapshot(
            identity: .default,
            meals: meals,
            windowStart: start,
            windowEnd: end,
            fetchedAt: .now
        )
    }
}
