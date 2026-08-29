import Foundation

/// A calendar day in the school's time zone, stored as `yyyyMMdd`.
///
/// Using an integer-backed day rather than `Date` keeps meal lookups exact:
/// no time zone drift when the watch travels and no `Calendar` work in the
/// hot path of a widget timeline.
struct SchoolDate: Hashable, Codable, Sendable, Comparable, RawRepresentable {
    var rawValue: Int

    init(rawValue: Int) { self.rawValue = rawValue }

    init(_ date: Date) {
        let components = SchoolClock.calendar.dateComponents([.year, .month, .day], from: date)
        rawValue = (components.year ?? 0) * 10_000 + (components.month ?? 0) * 100 + (components.day ?? 0)
    }

    init?(compact: String) {
        guard compact.count == 8, let value = Int(compact) else { return nil }
        rawValue = value
    }

    static func < (lhs: SchoolDate, rhs: SchoolDate) -> Bool { lhs.rawValue < rhs.rawValue }

    var compactString: String { String(rawValue) }

    var dateComponents: DateComponents {
        DateComponents(year: rawValue / 10_000, month: (rawValue / 100) % 100, day: rawValue % 100)
    }

    /// Midnight at the start of this day, in the school's time zone.
    var startOfDay: Date {
        SchoolClock.calendar.date(from: dateComponents) ?? .distantPast
    }

    func adding(days: Int) -> SchoolDate {
        guard let shifted = SchoolClock.calendar.date(byAdding: .day, value: days, to: startOfDay) else {
            return self
        }
        return SchoolDate(shifted)
    }

    /// "9월 1일" — used where the weekday is already stated alongside it.
    var monthDayLabel: String {
        "\((rawValue / 100) % 100)월 \(rawValue % 100)일"
    }

    /// "9월 1일 (월)" — standalone form, for the widget where there is no
    /// weekday label next to it.
    var shortKoreanLabel: String {
        "\(monthDayLabel) (\(SchoolClock.koreanWeekdaySymbol(for: startOfDay)))"
    }
}
