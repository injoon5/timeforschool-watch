import SwiftUI

/// One period: number, subject, teacher.
///
/// The current lesson is filled solid blue across the row, the way a route
/// bullet is filled on a subway sign — the row is the indicator, not a badge
/// bolted onto it.
struct LessonRow: View {
    let lesson: Lesson
    let isNow: Bool
    /// Shared width of the teacher column, raised to fit the widest name in
    /// the day so all three columns line up down the list.
    @Binding var teacherColumnWidth: CGFloat

    var body: some View {
        HStack(spacing: Metrics.columnGap) {
            Text(lesson.period, format: .number)
                .font(Typography.period)
                .foregroundStyle(isNow ? Palette.onSignalSecondary : Palette.tertiaryText)
                .fixedSize()

            Text(lesson.subject)
                .font(Typography.subject)
                .signageTracking()
                .foregroundStyle(subjectColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, alignment: .leading)

            teacherColumn
        }
        .padding(.horizontal, Metrics.rowPadding)
        .padding(.vertical, Metrics.rowVerticalPadding)
        .background(isNow ? Palette.signal : .clear, in: .rect(cornerRadius: Metrics.rowCornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var teacherColumn: some View {
        Text(lesson.teacher)
            .font(Typography.teacher)
            .foregroundStyle(isNow ? Palette.onSignalSecondary : Palette.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: resolvedTeacherWidth, alignment: .trailing)
            .background(alignment: .trailing) { teacherMeasure }
    }

    /// An unconstrained copy of the same text, drawn nowhere, whose natural
    /// width is what the column negotiates over. Measuring the visible label
    /// instead would make its own frame the thing being measured.
    private var teacherMeasure: some View {
        Text(lesson.teacher)
            .font(Typography.teacher)
            .fixedSize()
            .hidden()
            .accessibilityHidden(true)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                teacherColumnWidth = max(teacherColumnWidth, width)
            }
    }

    /// `nil` until the first measurement lands, so the column is never briefly
    /// laid out at zero width.
    private var resolvedTeacherWidth: CGFloat? {
        teacherColumnWidth > 0 ? min(teacherColumnWidth, Metrics.maxTeacherColumnWidth) : nil
    }

    /// A replaced lesson is called out in advisory yellow, never by moving it.
    private var subjectColor: Color {
        if isNow { return Palette.onSignal }
        return lesson.isReplaced ? Palette.advisory : Palette.primaryText
    }

    private var accessibilityLabel: Text {
        var parts = ["\(lesson.period)교시", lesson.subject]
        if lesson.hasTeacher { parts.append(lesson.teacher) }
        if lesson.isReplaced { parts.append("변경됨") }
        if isNow { parts.append("현재 수업") }
        return Text(parts.joined(separator: ", "))
    }
}
