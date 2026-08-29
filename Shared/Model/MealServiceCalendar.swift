import Foundation

/// Published meal dates, kept separately for each service.
///
/// The calendar itself is optional at call sites: `nil` means no snapshot has
/// loaded yet, while a non-optional empty calendar is a known "no meals"
/// response from the server.
struct MealServiceCalendar: Hashable, Sendable {
    private var datesByKind: [MealKind: Set<SchoolDate>]

    init(meals: [Meal]) {
        var datesByKind: [MealKind: Set<SchoolDate>] = [:]
        for meal in meals where meal.kind != .breakfast && !meal.dishes.isEmpty {
            datesByKind[meal.kind, default: []].insert(meal.day)
        }
        self.datesByKind = datesByKind
    }

    func serves(_ kind: MealKind, on day: SchoolDate) -> Bool {
        datesByKind[kind]?.contains(day) == true
    }

    func nextDay(for kind: MealKind, after day: SchoolDate) -> SchoolDate? {
        datesByKind[kind]?.filter { $0 > day }.min()
    }
}
