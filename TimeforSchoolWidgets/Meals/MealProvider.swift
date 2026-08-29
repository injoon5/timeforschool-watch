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
        Task {
            let snapshot = await SchoolRepository.shared.meals()
            completion(MealEntry.resolve(at: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<MealEntry>) -> Void) {
        Task {
            let now = Date.now
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

        let entries = [MealEntry.resolve(at: now, snapshot: snapshot)]
            + boundaries.map { MealEntry.resolve(at: $0, snapshot: snapshot) }

        return Timeline(entries: entries, policy: .after(midnight))
    }
}
