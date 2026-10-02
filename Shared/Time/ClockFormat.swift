import Foundation

extension Date {
    /// "09:10" — a fixed 24-hour clock, always on the school's wall clock.
    ///
    /// Bell times are printed this way on every Korean school timetable, and
    /// `.shortened` would follow the watch's locale instead: "9:10 AM" on an
    /// English watch, "오전 9:10" on a Korean one. Neither belongs beside a
    /// period number.
    ///
    /// The time zone is pinned for the same reason every schedule calculation
    /// is: the schedule stays in Seoul, so a travelling watch must not print
    /// 08:10 as 04:10.
    var schoolClockText: String {
        var style = Date.FormatStyle.dateTime
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .locale(.school)
        style.timeZone = SchoolClock.timeZone
        return formatted(style)
    }
}
