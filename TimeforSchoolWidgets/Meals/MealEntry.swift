import Foundation
import WidgetKit

/// One moment on the meal widget's timeline.
struct MealEntry: TimelineEntry {
    let date: Date
    let presentation: MealPresentation
    let meal: Meal?

    static let placeholder = MealEntry(
        date: .now,
        presentation: MealPresentation(kind: .lunch, date: SchoolDate(.now), isFutureDay: false, isTomorrow: false),
        meal: Meal(
            kind: .lunch,
            day: SchoolDate(.now),
            dishes: ["기장밥", "오징어무국", "안동찜닭", "배추김치"],
            calories: 915
        )
    )

    /// Picks the meal the wearer is actually waiting for at `date`, off the
    /// same cutoffs the meals screen uses: 중식 until 13:10, 석식 until 18:40,
    /// then tomorrow's 중식.
    static func resolve(at date: Date, snapshot: MealSnapshot?) -> MealEntry {
        let next = MealPresentation.upcoming(now: date, availableDays: snapshot?.servedDays() ?? [])
        return MealEntry(
            date: date,
            presentation: next,
            meal: snapshot?.meal(kind: next.kind, on: next.date)
        )
    }
}
