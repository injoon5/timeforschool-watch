import SwiftUI

/// The break-time indicator: the filled row collapses to a rule drawn in the
/// gap that is already there between two rows.
///
/// It contributes no height of its own — a zero-height frame holds the rule,
/// and the negative padding absorbs the stack spacing the extra element would
/// otherwise introduce — so the rows do not shift when a break begins.
struct BreakRule: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(Palette.signal)
            .frame(height: Metrics.breakRuleHeight)
            .padding(.horizontal, Metrics.rowPadding)
            .frame(height: 0)
            .padding(.vertical, -Metrics.rowSpacing / 2)
            .accessibilityElement()
            .accessibilityLabel("쉬는 시간")
    }
}

/// The terminus dot: shown above the list before the first bell and below it
/// once the last lesson has ended.
///
/// A blank line of the subject font sets both the row's height and the dot's
/// diameter, so the marker scales with the wearer's text size and sits in the
/// period column — the day reads as a line with a stop at each end.
struct TerminusDot: View {
    enum Edge { case top, bottom }

    let edge: Edge

    var body: some View {
        Text(verbatim: " ")
            .font(Typography.subject)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Palette.signal)
                    .aspectRatio(1, contentMode: .fit)
            }
            .padding(.horizontal, Metrics.rowPadding)
            .padding(.vertical, Metrics.rowVerticalPadding)
            .accessibilityElement()
            .accessibilityLabel(edge == .top ? "수업 시작 전" : "수업 종료")
    }
}
