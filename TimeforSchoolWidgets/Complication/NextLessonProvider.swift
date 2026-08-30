import Foundation
import WidgetKit

/// Builds the complication's timeline from the cached week.
///
/// Every transition in a school day happens on a known minute, so the timeline
/// carries one entry per bell rather than asking the system to refresh on a
/// guess. That keeps the complication exact and costs almost no budget.
struct NextLessonProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextLessonEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NextLessonEntry) -> Void) {
        // The gallery renders many widgets at once; it gets the sample rather
        // than a network round trip.
        guard !context.isPreview else { return completion(.placeholder) }
        if let cached = SchoolRepository.cachedTimetable() {
            completion(NextLessonEntry.resolve(at: .now, week: cached.week))
            refresh(after: cached.fetchedAt)
            return
        }
        Task {
            let week = await SchoolRepository.shared.timetable()?.week
            completion(week.map { NextLessonEntry.resolve(at: .now, week: $0) } ?? .placeholder)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NextLessonEntry>) -> Void) {
        let now = Date.now
        if let cached = SchoolRepository.cachedTimetable() {
            completion(Self.timeline(from: now, week: cached.week))
            refresh(after: cached.fetchedAt)
            return
        }
        Task {
            guard let week = await SchoolRepository.shared.timetable()?.week else {
                completion(Timeline(entries: [.placeholder], policy: .after(now.addingTimeInterval(30 * 60))))
                return
            }
            completion(Self.timeline(from: now, week: week))
        }
    }

    /// Return cached content first, then ask WidgetKit to rebuild only if the
    /// background refresh actually produced a newer snapshot.
    private func refresh(after fetchedAt: Date) {
        Task {
            guard let fresh = await SchoolRepository.shared.timetable(),
                  fresh.fetchedAt != fetchedAt
            else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: NextLessonComplication.kind)
            WidgetCenter.shared.reloadTimelines(ofKind: NextLessonWidget.kind)
        }
    }

    /// Surfaces the lesson widget in the Smart Stack around the school day.
    func relevance() async -> WidgetRelevance<Void> {
        let now = Date.now
        let day = SchoolClock.schoolDayOnOrAfter(now)
        let start = SchoolClock.time(7 * 60 + 30, on: day)
        let end = SchoolClock.time(BellSchedule.timetableRollover, on: day)
        let window = DateInterval(start: start, end: end)
        return WidgetRelevance([WidgetRelevanceAttribute(context: .date(interval: window, kind: .scheduled))])
    }

    /// How far ahead the per-minute entries run before the widget reloads.
    private static let countdownHorizon = 60

    static func timeline(from now: Date, week: SchoolWeek) -> Timeline<NextLessonEntry> {
        let midnight = SchoolClock.calendar.startOfDay(
            for: SchoolClock.calendar.date(byAdding: .day, value: 1, to: now) ?? now
        )

        var boundaries: Set<Date> = [midnight]

        // The row shows whole minutes remaining, so it needs an entry a
        // minute. An hour of them is enough to cover any gap between bells,
        // and the reload below tops the window back up.
        let thisMinute = SchoolClock.calendar.date(
            from: SchoolClock.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        ) ?? now
        for minute in 1...countdownHorizon {
            boundaries.insert(thisMinute.addingTimeInterval(TimeInterval(minute) * 60))
        }
        for period in week.bellSchedule.starts.keys {
            if let start = week.bellSchedule.start(of: period) {
                boundaries.insert(SchoolClock.time(start, on: now))
            }
            if let end = week.bellSchedule.end(of: period) {
                boundaries.insert(SchoolClock.time(end, on: now))
            }
        }
        boundaries.insert(SchoolClock.time(BellSchedule.timetableRollover, on: now))

        let upcoming = boundaries.filter { $0 > now }.sorted()
        let entries = [NextLessonEntry.resolve(at: now, week: week)]
            + upcoming.map { NextLessonEntry.resolve(at: $0, week: week) }

        let reloadAt = min(midnight, thisMinute.addingTimeInterval(TimeInterval(countdownHorizon - 5) * 60))
        return Timeline(entries: entries, policy: .after(reloadAt))
    }
}
