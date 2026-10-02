import Foundation
import Testing
@testable import TimeforSchool

@Suite("Bell schedule parsing")
struct BellScheduleTests {
    @Test("Reversed delimiters are rejected without slicing an invalid range")
    func reversedDelimiters() {
        #expect(BellSchedule(dayTime: [")1("]) == nil)
    }

    @Test("A partial response keeps standard times for missing periods")
    func partialResponse() throws {
        let schedule = try #require(BellSchedule(dayTime: ["1(09:00)", "malformed"]))

        #expect(schedule.start(of: 1) == 9 * 60)
        #expect(schedule.start(of: 7) == BellSchedule.standard.start(of: 7))
    }

    @Test("Out-of-range clock values are rejected")
    func invalidClock() {
        #expect(BellSchedule(dayTime: ["1(24:00)", "2(09:60)"]) == nil)
    }
}

@Suite("Timetable response decoding")
struct TimetableResponseTests {
    @Test("A response with no day_time falls back to the standard bells")
    func missingDayTime() throws {
        let week = try decode(#"{"timetable": [[{"period": 1, "subject": "국어"}]]}"#).makeWeek()

        #expect(week.bellSchedule == .standard)
        #expect(week.days.first?.first?.subject == "국어")
    }

    @Test("A null day_time falls back the same way")
    func nullDayTime() throws {
        let week = try decode(#"{"day_time": null, "timetable": []}"#).makeWeek()

        #expect(week.bellSchedule == .standard)
    }

    @Test("A published day_time still wins")
    func presentDayTime() throws {
        let week = try decode(#"{"day_time": ["1(09:00)"], "timetable": []}"#).makeWeek()

        #expect(week.bellSchedule.start(of: 1) == 9 * 60)
    }

    private func decode(_ json: String) throws -> TimetableResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TimetableResponse.self, from: Data(json.utf8))
    }
}

@Suite("School clock text")
struct ClockFormatTests {
    @Test("Bell times print on the school's clock, not the wearer's")
    func pinnedToTheSchoolTimeZone() throws {
        let bell = try #require(SchoolClock.calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 2, hour: 8, minute: 10)
        ))

        #expect(bell.schoolClockText == "08:10")
    }
}
