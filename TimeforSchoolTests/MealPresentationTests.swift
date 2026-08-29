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

    private func date(year: Int, month: Int, day: Int, hour: Int) throws -> Date {
        try #require(SchoolClock.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        ))
    }

    private func meal(_ kind: MealKind, on day: SchoolDate) -> Meal {
        Meal(kind: kind, day: day, dishes: ["메뉴"], calories: nil)
    }
}
