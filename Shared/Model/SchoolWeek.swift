import Foundation

/// One week of lessons plus the bell times that drive the "now" indicator.
struct SchoolWeek: Hashable, Codable, Sendable {
    /// Lessons indexed by weekday, Monday first. The API returns five days.
    var days: [[Lesson]]
    var bellSchedule: BellSchedule
    /// Server-reported time the timetable was last edited, when available.
    var updatedAt: String?

    static let empty = SchoolWeek(days: [], bellSchedule: .standard, updatedAt: nil)

    /// Lessons for `date`, or an empty array on weekends and out-of-range days.
    func lessons(on date: Date) -> [Lesson] {
        guard let index = SchoolClock.weekdayIndex(for: date), days.indices.contains(index) else {
            return []
        }
        return days[index]
    }
}
