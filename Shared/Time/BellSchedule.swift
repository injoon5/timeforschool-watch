import Foundation

/// Period start times for the school, parsed from the API's `day_time` field.
///
/// The API only publishes start times, so period length is a constant. Both
/// values are stored in minutes since midnight for cheap comparisons.
struct BellSchedule: Hashable, Codable, Sendable {
    /// Start time of each period, keyed by period number.
    var starts: [Int: Int]
    var lessonLength: Int

    static let lunchCutoff = 13 * 60 + 10   // 13:10 — meals roll over to tomorrow
    static let dinnerCutoff = 18 * 60 + 40  // 18:40
    static let timetableRollover = 17 * 60  // 17:00 — timetable rolls over to tomorrow

    /// Fallback used when the API omits or malforms `day_time`.
    static let standard = BellSchedule(
        starts: [1: 490, 2: 550, 3: 610, 4: 670, 5: 790, 6: 850, 7: 910, 8: 970],
        lessonLength: 50
    )

    /// Parses entries shaped like `"5(13:10)"`.
    init?(dayTime: [String]) {
        var parsed: [Int: Int] = [:]
        for entry in dayTime {
            guard let open = entry.firstIndex(of: "("), let close = entry.firstIndex(of: ")"),
                  open < close,
                  let period = Int(entry[entry.startIndex..<open].trimmingCharacters(in: .whitespaces)),
                  period > 0
            else { continue }
            let clock = entry[entry.index(after: open)..<close]
            let parts = clock.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]), (0..<24).contains(hour),
                  let minute = Int(parts[1]), (0..<60).contains(minute)
            else { continue }
            parsed[period] = hour * 60 + minute
        }
        guard !parsed.isEmpty else { return nil }
        starts = BellSchedule.standard.starts.merging(parsed) { _, parsed in parsed }
        lessonLength = BellSchedule.standard.lessonLength
    }

    init(starts: [Int: Int], lessonLength: Int) {
        self.starts = starts
        self.lessonLength = lessonLength
    }

    func start(of period: Int) -> Int? { starts[period] }

    func end(of period: Int) -> Int? { starts[period].map { $0 + lessonLength } }
}
