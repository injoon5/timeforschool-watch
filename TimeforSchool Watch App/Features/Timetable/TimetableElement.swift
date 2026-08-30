import Foundation

/// One drawable row of the timetable.
///
/// Flattening the day into a single array — lessons plus, at most, one
/// indicator — means the list has exactly one element to scroll to and the
/// view never has to reason about "now" while laying rows out.
enum TimetableElement: Hashable, Identifiable, Sendable {
    /// The dot above the list, shown before the first bell.
    case startTerminus
    case lesson(Lesson, isNow: Bool)
    /// The rule drawn between two lessons during a break.
    case breakRule(afterPeriod: Int)
    /// The dot below the list, shown once the day is over.
    case endTerminus

    var id: String {
        switch self {
        case .startTerminus: "terminus.start"
        case .lesson(let lesson, _): "lesson.\(lesson.period)"
        case .breakRule(let period): "break.\(period)"
        case .endTerminus: "terminus.end"
        }
    }

    static func build(from presentation: TimetablePresentation) -> [TimetableElement] {
        let lessons = presentation.lessons.sorted { $0.period < $1.period }
        guard !lessons.isEmpty else { return [] }

        var elements: [TimetableElement] = []
        elements.reserveCapacity(lessons.count + 1)

        if presentation.indicator == .beforeFirstLesson {
            elements.append(.startTerminus)
        }
        for lesson in lessons {
            elements.append(.lesson(lesson, isNow: presentation.indicator == .duringLesson(period: lesson.period)))
            if presentation.indicator == .duringBreak(afterPeriod: lesson.period) {
                elements.append(.breakRule(afterPeriod: lesson.period))
            }
        }
        if presentation.indicator == .afterLastLesson {
            elements.append(.endTerminus)
        }
        return elements
    }
}

extension TimetablePresentation {
    /// The row or marker the screen positions when it opens. Before the first
    /// bell the list stays at its natural top edge, so the header and start dot
    /// remain together rather than forcing the dot into the vertical centre.
    var scrollTargetElementID: TimetableElement.ID? {
        switch indicator {
        case .beforeFirstLesson: nil
        case .duringLesson(let period): "lesson.\(period)"
        case .duringBreak(let period): "break.\(period)"
        case .afterLastLesson: TimetableElement.endTerminus.id
        }
    }
}
