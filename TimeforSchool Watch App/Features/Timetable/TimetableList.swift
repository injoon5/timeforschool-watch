import SwiftUI

/// Lays out one school day and keeps the active row or break marker centred.
/// Terminus dots rest at the natural top or bottom edge instead.
struct TimetableList: View {
    let presentation: TimetablePresentation
    let availability: TimetableAvailability

    /// Shared width of the teacher column, measured from the widest name so
    /// the three columns line up down the whole list.
    @State private var teacherColumnWidth: CGFloat = 0
    /// Set when the marker moves while the wearer is scrolling, and applied
    /// once they stop — recentring under a moving finger or crown would fight
    /// them for control of the list.
    @State private var deferredTarget: TimetableElement.ID?
    @State private var isScrolling = false

    private var elements: [TimetableElement] { TimetableElement.build(from: presentation) }

    var body: some View {
        ScrollViewReader { proxy in
            scrollView(proxy)
        }
    }

    private func scrollView(_ proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                centeringSlack(fraction: centeringSlackFraction)
                DayHeader(presentation: presentation)
                    .padding(.bottom, 2)
                    .id(Self.topAnchor)

                if elements.isEmpty {
                    TimetableEmptyState(availability: availability)
                } else {
                    ForEach(elements) { element in
                        row(for: element)
                    }
                }
                centeringSlack(fraction: centeringSlackFraction)
            }
            .padding(.horizontal, Metrics.pageInset)
        }
        .onScrollPhaseChange { _, phase in
            isScrolling = phase.isScrolling
            guard !isScrolling, let deferredTarget else { return }
            proxy.scrollTo(deferredTarget, anchor: scrollAnchor)
            self.deferredTarget = nil
        }
        .onChange(of: presentation.lessons, initial: true) { _, _ in
            teacherColumnWidth = 0
            positionMarker(with: proxy)
        }
        .onChange(of: presentation.scrollTargetElementID) { _, _ in
            positionMarker(with: proxy)
        }
    }

    /// The row the list rests on: the header before the first bell, the end
    /// dot once the day is over, and the live lesson or break in between.
    private static let topAnchor = "day.header"

    /// Centres active lessons and breaks, rests the end dot at the bottom, and
    /// returns to the header before the first bell.
    ///
    /// That last case still needs a scroll even though the header is the
    /// natural top: at 17:00 the same scroll view swaps today's finished day
    /// for tomorrow's, and left alone it stays parked wherever the end dot had
    /// pulled it — at the bottom of a day that has not started.
    private func positionMarker(with proxy: ScrollViewProxy) {
        let target = presentation.scrollTargetElementID ?? Self.topAnchor
        guard !isScrolling else {
            deferredTarget = target
            return
        }
        proxy.scrollTo(target, anchor: scrollAnchor)
    }

    /// Space that lets the first and last lesson rows reach the centre. Dot
    /// states set this to zero because they use the list's natural edges.
    private func centeringSlack(fraction: Double) -> some View {
        Color.clear
            .frame(height: 1)
            .containerRelativeFrame(.vertical) { height, _ in height * fraction }
            .accessibilityHidden(true)
    }

    private var centeringSlackFraction: Double {
        switch presentation.indicator {
        case .duringLesson, .duringBreak: 0.38
        case .beforeFirstLesson, .afterLastLesson: 0
        }
    }

    private var scrollAnchor: UnitPoint {
        switch presentation.indicator {
        case .beforeFirstLesson: .top
        case .afterLastLesson: .bottom
        case .duringLesson, .duringBreak: .center
        }
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
