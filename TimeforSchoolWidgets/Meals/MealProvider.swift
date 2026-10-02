import Foundation
import WidgetKit

/// Builds the meal widget's timeline.
///
/// Menus are known weeks ahead, so the timeline only needs entries at the two
/// moments the answer changes — 13:10 and 18:40 — plus midnight.
struct MealProvider: TimelineProvider {
    func placeholder(in context: Context) -> MealEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (MealEntry) -> Void) {
        guard !context.isPreview else { return completion(.placeholder) }
        if let fresh = SchoolRepository.freshMeals() {
            completion(MealEntry.resolve(
                at: .now,
                snapshot: fresh,
                calendar: fresh.serviceCalendar(),
                availability: .loaded
            ))
            return
        }
        Task {
            let snapshot = await SchoolRepository.shared.meals()
            completion(MealEntry.resolve(
                at: .now,
                snapshot: snapshot,
                calendar: snapshot?.serviceCalendar(),
                availability: snapshot == nil ? .unavailable : .loaded
            ))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<MealEntry>) -> Void) {
        let now = Date.now
        // A fresh cache answers without touching the network. When it is not
        // fresh the refresh is awaited rather than fired off after the
        // completion handler, which WidgetKit may never let run — and which
        // only earns a second reload out of a metered budget when it does.
        if let fresh = SchoolRepository.freshMeals(now: now) {
            completion(Self.timeline(from: now, snapshot: fresh))
            return
        }
        Task {
            let snapshot = await SchoolRepository.shared.meals()
            completion(Self.timeline(from: now, snapshot: snapshot))
        }
    }

    /// Pushes the menu into the Smart Stack in the run-up to each service.
    func relevance() async -> WidgetRelevance<Void> {
        let now = Date.now
        let day = SchoolClock.schoolDayOnOrAfter(now)
        let attributes = [
            (11 * 60, BellSchedule.lunchCutoff),
            (17 * 60, BellSchedule.dinnerCutoff),
        ].map { window in
            WidgetRelevanceAttribute<Void>(
                context: .date(
                    interval: DateInterval(
                        start: SchoolClock.time(window.0, on: day),
                        end: SchoolClock.time(window.1, on: day)
                    ),
                    kind: .scheduled
                )
            )
        }
        return WidgetRelevance(attributes)
    }

    static func timeline(from now: Date, snapshot: MealSnapshot?) -> Timeline<MealEntry> {
        let calendar = snapshot?.serviceCalendar()
        let availability: MealAvailability = snapshot == nil ? .unavailable : .loaded
        let midnight = SchoolClock.calendar.startOfDay(
            for: SchoolClock.calendar.date(byAdding: .day, value: 1, to: now) ?? now
        )
        let boundaries = [
            SchoolClock.time(BellSchedule.lunchCutoff, on: now),
            SchoolClock.time(BellSchedule.dinnerCutoff, on: now),
            midnight,
        ]
        .filter { $0 > now }
        .sorted()

        let entries = [MealEntry.resolve(at: now, snapshot: snapshot, calendar: calendar, availability: availability)]
            + boundaries.map {
                MealEntry.resolve(at: $0, snapshot: snapshot, calendar: calendar, availability: availability)
            }

        return Timeline(entries: entries, policy: .after(midnight))
    }
}
