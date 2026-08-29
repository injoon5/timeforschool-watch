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

    /// Picks the published meal the wearer is actually waiting for at `date`,
    /// using the same service-specific availability and cutoffs as the app.
    static func resolve(
        at date: Date,
        snapshot: MealSnapshot?,
        calendar: MealServiceCalendar?
    ) -> MealEntry {
        let next = MealPresentation.upcoming(now: date, calendar: calendar)
        return MealEntry(
            date: date,
            presentation: next,
            meal: snapshot?.meal(kind: next.kind, on: next.date)
        )
    }
}
