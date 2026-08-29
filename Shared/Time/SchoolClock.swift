import Foundation

/// Calendar helpers pinned to the school's time zone.
///
/// Everything schedule-related resolves through here so a travelling watch
/// still shows the school day correctly, and so widget timelines and the app
/// agree on what "today" means.
enum SchoolClock {
    static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }()

    /// Minutes elapsed since midnight, in the school's time zone.
    static func minutesSinceMidnight(_ date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// Monday-based index (Mon = 0 … Fri = 4). `nil` on weekends.
    static func weekdayIndex(for date: Date) -> Int? {
        let weekday = calendar.component(.weekday, from: date)  // Sunday == 1
        let index = weekday - 2
        return (0...4).contains(index) ? index : nil
    }

    static func isSchoolDay(_ date: Date) -> Bool { weekdayIndex(for: date) != nil }

    /// The first school day strictly after `date`.
    static func nextSchoolDay(after date: Date) -> Date {
        var candidate = date
        repeat {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        } while !isSchoolDay(candidate)
        return candidate
    }

    /// `date` itself when it is a school day, otherwise the next one.
    static func schoolDayOnOrAfter(_ date: Date) -> Date {
        isSchoolDay(date) ? date : nextSchoolDay(after: date)
    }

    /// A `Date` for `minutes` past midnight on the day containing `date`.
    static func time(_ minutes: Int, on date: Date) -> Date {
        let midnight = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: minutes, to: midnight) ?? midnight
    }

    static func koreanWeekdaySymbol(for date: Date) -> String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let weekday = calendar.component(.weekday, from: date)
        return symbols[max(0, min(6, weekday - 1))]
    }
}

#if DEBUG
extension SchoolClock {
    /// Shifts "now" by `TFS_TIME_OFFSET_MINUTES` so every state of the day —
    /// mid-lesson, break, before the first bell, after the last — can be
    /// exercised in the simulator without waiting for the clock.
    static func debugAdjusted(_ date: Date) -> Date {
        guard let raw = ProcessInfo.processInfo.environment["TFS_TIME_OFFSET_MINUTES"],
              let minutes = Int(raw)
        else { return date }
        return date.addingTimeInterval(TimeInterval(minutes) * 60)
    }
}
#endif

extension SchoolClock {
    /// The instant the UI should render, honouring the debug offset.
    static func displayDate(_ date: Date) -> Date {
        #if DEBUG
        debugAdjusted(date)
        #else
        date
        #endif
    }
}
