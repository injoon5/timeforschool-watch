import Foundation

extension Date {
    /// "09:10" — a fixed 24-hour clock.
    ///
    /// Bell times are printed this way on every Korean school timetable, and
    /// `.shortened` would follow the watch's locale instead: "9:10 AM" on an
    /// English watch, "오전 9:10" on a Korean one. Neither belongs beside a
    /// period number.
    var schoolClockText: String {
        formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(.school)
        )
    }
}
