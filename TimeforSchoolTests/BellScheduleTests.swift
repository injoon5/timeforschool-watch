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
