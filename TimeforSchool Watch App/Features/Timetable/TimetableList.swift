import SwiftUI

/// Lays out one school day and keeps the live marker centred on screen.
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
            .padding(.horizontal, Metrics.pageInset)
        }
        .onScrollPhaseChange { _, phase in
            isScrolling = phase.isScrolling
            guard !isScrolling, let deferredTarget else { return }
            proxy.scrollTo(deferredTarget, anchor: .center)
            self.deferredTarget = nil
        }
        .onChange(of: presentation.lessons, initial: true) { _, _ in
            teacherColumnWidth = 0
            // On a first launch there is no cache, so the marker is aimed at
            // while the list is still empty and there is nothing to scroll to.
            // The lessons arriving is the moment to aim again, and the marker's
            // id does not change between those two moments — which is why this
            // is an imperative scroll rather than a `scrollPosition` binding:
            // assigning a binding the value it already holds does nothing.
            centre(with: proxy)
        }
        .onChange(of: presentation.nowElementID) { _, _ in
            centre(with: proxy)
        }
    }

    /// Scrolls the live marker to the middle of the screen, unless the wearer
    /// is scrolling — in which case it waits until they stop.
    private func centre(with proxy: ScrollViewProxy) {
        let target = presentation.nowElementID
        guard !isScrolling else {
            deferredTarget = target
            return
        }
        proxy.scrollTo(target, anchor: .center)
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
