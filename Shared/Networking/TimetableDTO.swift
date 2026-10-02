import Foundation

/// Wire format of `GET /timetable`.
struct TimetableResponse: Decodable, Sendable {
    var dayTime: [String]
    var timetable: [[LessonDTO]]
    var updateDate: String?

    /// Maps the wire format onto the app's model, falling back to the standard
    /// bell schedule when `day_time` is missing or malformed.
    func makeWeek() -> SchoolWeek {
        SchoolWeek(
            days: timetable.map { $0.map(\.lesson) },
            bellSchedule: BellSchedule(dayTime: dayTime) ?? .standard,
            updatedAt: updateDate
        )
    }

    private enum CodingKeys: String, CodingKey {
        case dayTime, timetable, updateDate
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // A missing or null `day_time` must reach `BellSchedule(dayTime:)` as an
        // empty list so the standard bell schedule takes over. Requiring the
        // field instead fails the whole timetable before that fallback runs.
        dayTime = (try? container.decodeIfPresent([String].self, forKey: .dayTime)) ?? []
        timetable = try container.decode([[LessonDTO]].self, forKey: .timetable)
        updateDate = try? container.decodeIfPresent(String.self, forKey: .updateDate)
    }
}

struct LessonDTO: Decodable, Sendable {
    var period: Int
    var subject: String
    var teacher: String
    var replaced: Bool
    var original: String?

    var lesson: Lesson {
        Lesson(
            period: period,
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            teacher: teacher.trimmingCharacters(in: .whitespacesAndNewlines),
            isReplaced: replaced,
            originalSubject: original
        )
    }

    private enum CodingKeys: String, CodingKey {
        case period, subject, teacher, replaced, original
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decodeIfPresent(Int.self, forKey: .period) ?? 0
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? ""
        teacher = try container.decodeIfPresent(String.self, forKey: .teacher) ?? ""
        replaced = try container.decodeIfPresent(Bool.self, forKey: .replaced) ?? false
        // `original` is null in practice but its type is not documented, so a
        // surprise shape must not fail the whole timetable.
        original = try? container.decodeIfPresent(String.self, forKey: .original)
    }
}
