import Foundation
import WidgetKit

/// One moment on the meal widget's timeline.
struct MealEntry: TimelineEntry {
    let date: Date
    let presentation: MealPresentation
    let content: MealContent

    /// The menu, when there is one to draw.
    var meal: Meal? {
        guard case .menu(let meal) = content else { return nil }
        return meal
    }

    static let placeholder = MealEntry(
        date: .now,
        presentation: MealPresentation(kind: .lunch, date: SchoolDate(.now), isFutureDay: false, isTomorrow: false),
        content: .menu(Meal(
            kind: .lunch,
            day: SchoolDate(.now),
            dishes: ["기장밥", "오징어무국", "안동찜닭", "배추김치"],
            calories: 915
        ))
    )

    /// Picks the published meal the wearer is actually waiting for at `date`,
    /// using the same service-specific availability and cutoffs as the app.
    ///
    /// `availability` keeps a failed fetch from reading as a confirmed empty
    /// menu, exactly as it does on the meals screen.
    static func resolve(
        at date: Date,
        snapshot: MealSnapshot?,
        calendar: MealServiceCalendar?,
        availability: MealAvailability
    ) -> MealEntry {
        let next = MealPresentation.upcoming(now: date, calendar: calendar)
        return MealEntry(
            date: date,
            presentation: next,
            content: MealContent.resolve(
                presentation: next,
                snapshot: snapshot,
                availability: availability
            )
        )
    }
}
