import Foundation
import Testing
@testable import TimeforSchool

@Suite("Timetable scroll target")
struct TimetableScrollTargetTests {
    @Test("The start dot leaves the list at its natural top edge")
    func startDotDoesNotScroll() {
        let presentation = timetable(indicator: .beforeFirstLesson)

        #expect(presentation.scrollTargetElementID == nil)
    }

    @Test("Active rows and breaks remain explicit scroll targets")
    func activeMarkersScroll() {
        #expect(timetable(indicator: .duringLesson(period: 2)).scrollTargetElementID == "lesson.2")
        #expect(timetable(indicator: .duringBreak(afterPeriod: 2)).scrollTargetElementID == "break.2")
    }

    @Test("The end dot remains a scroll target for bottom-edge positioning")
    func endDotScrolls() {
        let presentation = timetable(indicator: .afterLastLesson)

        #expect(presentation.scrollTargetElementID == TimetableElement.endTerminus.id)
    }

    private func timetable(indicator: DayIndicator) -> TimetablePresentation {
        TimetablePresentation(
            date: .now,
            lessons: [],
            indicator: indicator,
            isFutureDay: false,
            isTomorrow: false
        )
    }
}
