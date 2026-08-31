import Foundation
import WidgetKit

/// Builds the next-lesson timeline from the cached week.
///
/// Every transition in a school day happens on a known minute, so the timeline
/// carries one entry per bell rather than asking the system to refresh on a
/// guess. Only the Smart Stack card shows a number that moves between bells,
/// and only while the wearer is actually counting down to one — so that is the
/// only case that pays for per-minute entries.
struct NextLessonProvider: TimelineProvider {
    /// How finely a consumer of this timeline needs it cut.
    enum Cadence: Sendable {
        /// Bells only. Everything a face complication draws is fixed for the
        /// length of a lesson, so a minute entry would render pixel-identical
        /// output sixty times an hour.
        case bell
        /// Bells, plus a minute an entry while a countdown is running. The
        /// rectangular card shows minutes remaining and a marker crossing the
        /// arch; both move on the minute.
        case minute
    }

    let cadence: Cadence

    init(cadence: Cadence) {
        self.cadence = cadence
    }

    func placeholder(in context: Context) -> NextLessonEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NextLessonEntry) -> Void) {
        // The gallery renders many widgets at once; it gets the sample rather
        // than a network round trip.
        guard !context.isPreview else { return completion(.placeholder) }
        if let fresh = SchoolRepository.freshTimetable() {
            completion(NextLessonEntry.resolve(at: .now, week: fresh.week))
            return
        }
        Task {
            let week = await SchoolRepository.shared.timetable()?.week
            completion(week.map { NextLessonEntry.resolve(at: .now, week: $0) } ?? .placeholder)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NextLessonEntry>) -> Void) {
        let now = Date.now
        // A fresh cache answers without touching the network at all. When it is
        // not fresh the refresh is awaited rather than fired off after the
        // completion handler: WidgetKit suspends the extension the moment the
        // timeline is delivered, so work started there may never run — and when
        // it does, it only earns a second reload out of a metered budget.
        if let fresh = SchoolRepository.freshTimetable(now: now) {
            completion(Self.timeline(from: now, week: fresh.week, cadence: cadence))
            return
        }
        Task {
            guard let week = await SchoolRepository.shared.timetable()?.week else {
                completion(Timeline(entries: [.placeholder], policy: .after(now.addingTimeInterval(30 * 60))))
                return
            }
            completion(Self.timeline(from: now, week: week, cadence: cadence))
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

    /// How long before the bell the card starts counting in minutes. Past this
    /// the footer names a clock time instead, which does not move, and no
    /// lesson or break runs longer — so an hour covers every countdown whole.
    static let countdownHorizon: TimeInterval = 60 * 60

    static func timeline(
        from now: Date,
        week: SchoolWeek,
        cadence: Cadence
    ) -> Timeline<NextLessonEntry> {
        let midnight = SchoolClock.calendar.startOfDay(
            for: SchoolClock.calendar.date(byAdding: .day, value: 1, to: now) ?? now
        )

        var boundaries: Set<Date> = [midnight]
        for period in week.bellSchedule.starts.keys {
            if let start = week.bellSchedule.start(of: period) {
                boundaries.insert(SchoolClock.time(start, on: now))
            }
            if let end = week.bellSchedule.end(of: period) {
                boundaries.insert(SchoolClock.time(end, on: now))
            }
        }
        boundaries.insert(SchoolClock.time(BellSchedule.timetableRollover, on: now))

        let current = NextLessonEntry.resolve(at: now, week: week)

        // The moment the card is counting down to, if it is counting at all.
        // Outside a lesson or break — overnight, at the weekend, over a
        // holiday — there is no moving number, and the bells alone carry the
        // whole day.
        let countdown = cadence == .minute ? current.countdownTarget : nil

        // The minute window is cut against `now`, not just against the bell:
        // at two in the morning the run-up to first period is six hours off,
        // and building its sixty entries now only to sit on them until dawn
        // is sixty renders the watch does not need yet. The timeline stops at
        // the edge of the window instead and asks to be rebuilt there.
        var reloadAt = midnight
        if let countdown, countdown > now {
            let opens = countdown.addingTimeInterval(-countdownHorizon)
            if opens <= now {
                var minute = SchoolClock.calendar.date(
                    from: SchoolClock.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
                ) ?? now
                while minute < countdown {
                    minute.addTimeInterval(60)
                    boundaries.insert(min(minute, countdown))
                }
                reloadAt = min(countdown, midnight)
            } else {
                reloadAt = min(opens, midnight)
            }
        }

        let upcoming = boundaries.filter { $0 > now && $0 <= midnight }.sorted()
        let entries = [current]
            + upcoming.map { NextLessonEntry.resolve(at: $0, week: week) }

        return Timeline(entries: entries, policy: .after(reloadAt))
    }
}
