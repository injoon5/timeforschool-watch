import Testing
@testable import TimeforSchool

@Suite("Timetable wire format")
struct TimetableDTOTests {
    @Test("A split class keeps one spelling whichever way the feed writes it")
    func splitClassIsUpperCased() {
        #expect(LessonDTO.subjectName("사회b") == "사회B")
        #expect(LessonDTO.subjectName("사회B") == "사회B")
    }

    @Test("Korean survives the conversion, and the name is trimmed")
    func koreanIsUntouched() {
        #expect(LessonDTO.subjectName("  창의적 체험활동 ") == "창의적 체험활동")
    }
}
