import SwiftUI

/// Lays out one school day and keeps the live marker centred on screen.
struct TimetableList: View {
    let presentation: TimetablePresentation
    let availability: TimetableAvailability

    /// Shared width of the teacher column, measured from the widest name so
    /// the three columns line up down the whole list.
    @State private var teacherColumnWidth: CGFloat = 0
    @State private var scrollTarget: TimetableElement.ID?
    /// Set when the marker moves while the wearer is scrolling, and applied
    /// once they stop — recentring under a moving finger or crown would fight
    /// them for control of the list.
    @State private var deferredTarget: TimetableElement.ID?
    @State private var isScrolling = false

    private var elements: [TimetableElement] { TimetableElement.build(from: presentation) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                // Slack above and below the list so *any* row can sit dead
                // centre — otherwise the first and last periods would never
                // reach the middle of the screen.
                centeringSlack
                DayHeader(presentation: presentation)
                    .padding(.bottom, 2)

                if elements.isEmpty {
                    TimetableEmptyState(availability: availability)
                } else {
                    ForEach(elements) { element in
                        row(for: element)
                    }
                }
                centeringSlack
            }
            .scrollTargetLayout()
            .padding(.horizontal, Metrics.pageInset)
        }
        .scrollPosition(id: $scrollTarget, anchor: .center)
        .onScrollPhaseChange { _, phase in
            isScrolling = phase.isScrolling
            guard !isScrolling, let deferredTarget else { return }
            scrollTarget = deferredTarget
            self.deferredTarget = nil
        }
        .onChange(of: presentation.lessons) { _, _ in
            teacherColumnWidth = 0
        }
        .onChange(of: presentation.nowElementID, initial: true) { _, target in
            guard !isScrolling else {
                deferredTarget = target
                return
            }
            scrollTarget = target
        }
    }

    /// Half a screen of empty space, sized against the page rather than a
    /// guessed constant so it holds on every watch size.
    private var centeringSlack: some View {
        Color.clear
            .frame(height: 1)
            .containerRelativeFrame(.vertical) { height, _ in height * 0.38 }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func row(for element: TimetableElement) -> some View {
        switch element {
        case .startTerminus:
            TerminusDot(edge: .top)
        case .lesson(let lesson, let isNow):
            LessonRow(lesson: lesson, isNow: isNow, teacherColumnWidth: $teacherColumnWidth)
        case .breakRule:
            BreakRule()
        case .endTerminus:
            TerminusDot(edge: .bottom)
        }
    }
}
