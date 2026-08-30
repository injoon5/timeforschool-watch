import SwiftUI
import WidgetKit

/// Renders next-lesson content only in watch-face complication families.
struct NextLessonComplicationView: View {
    @Environment(\.widgetFamily) private var family

    let entry: NextLessonEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            corner
        default:
            Text(inlineText)
        }
    }

    private var circular: some View {
        VStack(spacing: -1) {
            Text(shortSubject)
                .font(.system(.headline, weight: .bold))
                .minimumScaleFactor(0.7)
                .widgetAccentable()

            if !circularSubtext.isEmpty {
                Text(circularSubtext)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.6)
            }
        }
        .lineLimit(1)
        .padding(2)
        .accessibilityLabel(accessibilityLabel)
    }

    private var corner: some View {
        Text(subject)
            .font(.system(.body, weight: .semibold))
            .widgetLabel { Text(cornerLabel) }
            .accessibilityLabel(accessibilityLabel)
    }

    private var subject: String {
        entry.lesson?.subject ?? "수업 없음"
    }

    private var shortSubject: String {
        entry.lesson.map { String($0.subject.prefix(2)) } ?? "종료"
    }

    private var inlineText: String {
        guard let lesson = entry.lesson else { return "수업 없음" }
        let prefix = entry.status == .future ? "내일 " : ""
        return "\(prefix)\(lesson.period)교시 \(lesson.subject)"
    }

    private var circularSubtext: String {
        guard let lesson = entry.lesson else { return "" }
        if entry.status == .future { return "내일" }
        return lesson.teacher.isEmpty ? "\(lesson.period)교시" : lesson.teacher
    }

    private var cornerLabel: String {
        entry.lesson.map { "\($0.period)교시" } ?? "수업 없음"
    }

    private var accessibilityLabel: Text {
        guard let lesson = entry.lesson else { return Text("남은 수업 없음") }
        var parts: [String] = []
        if entry.status == .future { parts.append("내일") }
        parts.append("\(lesson.period)교시")
        parts.append(lesson.subject)
        if lesson.hasTeacher { parts.append(lesson.teacher) }
        return Text(parts.joined(separator: ", "))
    }
}

#if DEBUG
struct NextLessonComplicationViewPreviews: PreviewProvider {
    static var previews: some View {
        NextLessonComplicationView(entry: .placeholder)
            .containerBackground(.fill.tertiary, for: .widget)
            .environment(\.locale, .school)
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Next lesson · Complication view")
    }
}
#endif
