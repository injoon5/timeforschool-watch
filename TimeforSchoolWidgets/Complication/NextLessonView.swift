import SwiftUI
import WidgetKit

/// Renders the lesson complication for each family it supports.
///
/// The lesson itself is the content — there is no "지금"/"다음" caption, because
/// the entry already answers that by showing the lesson in progress during a
/// period and the one about to start during a break. The only state worth
/// naming is a lesson that belongs to a *later* day, which is flagged so a
/// glance can never read tomorrow's first period as the next one today.
struct NextLessonView: View {
    @Environment(\.widgetFamily) private var family

    let entry: NextLessonEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            corner
        default:
            rectangular
        }
    }

    // MARK: - Families

    /// Subject over teacher. The subject is clipped to two characters — enough
    /// to tell 체육 from 정보 at this size, where a full name would be unreadable.
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

    /// Subject, teacher, then the one line that changes with the clock:
    /// minutes left while the lesson is running, its span otherwise.
    ///
    /// `stacked` puts that line under the teacher, which needs three lines of
    /// height — more than a watch face gives. The flat variant tucks it beside
    /// the subject instead, so nothing is lost where the container is short.
    private func details(stacked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(subject)
                    .font(.system(.headline, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()

                if !stacked, let status = statusText(stacked: false) {
                    Spacer(minLength: 4)
                    statusLabel(status)
                }
            }

            Text(subtitle)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if stacked, let status = statusText(stacked: true) {
                statusLabel(status)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
    }

    /// The one line that follows the clock.
    ///
    /// Minutes left only while the lesson is actually running — a countdown to
    /// a lesson you are not in answers a question nobody asked. Otherwise the
    /// span, which a watch face has no room for: there it shrinks to the only
    /// part that would surprise the wearer, that this is not today's lesson.
    private func statusText(stacked: Bool) -> String? {
        switch entry.status {
        case .current:
            remainingText
        case .future:
            stacked ? spanText.map { "내일 · \($0)" } ?? "내일" : "내일"
        case .upcoming:
            stacked ? spanText : nil
        case .finished:
            nil
        }
    }

    /// "09:10 – 10:00"
    private var spanText: String? {
        guard let start = entry.startsAt, let end = entry.endsAt else { return nil }
        return "\(start.schoolClockText) – \(end.schoolClockText)"
    }

    /// The period number, then the subject and teacher beside it — the same
    /// reading order as a row in the app.
    private var rectangular: some View {
        // Baseline-aligned, so the number reads as the first word of the
        // subject line rather than as a separate column beside the block.
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            periodNumber

            ViewThatFits(in: .vertical) {
                details(stacked: true)
                details(stacked: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Set at the subject's own size and weight; colour alone marks it as the
    /// label rather than the content. Tabular figures and a minimum width keep
    /// the subjects lined up when the period reaches two digits.
    private var periodNumber: some View {
        Text(periodText)
            .font(.system(.headline, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 14, alignment: .center)
    }

    /// Whole minutes left, measured from the entry's own timestamp rather than
    /// the clock, so each timeline entry reads correctly when it is shown.
    ///
    /// Deliberately not `Text(_:style: .relative)` — that ticks seconds, which
    /// is noise on a glanceable row.
    private var remainingText: String? {
        guard let target = entry.countdownTarget else { return nil }
        let minutes = Int((target.timeIntervalSince(entry.date) / 60).rounded(.up))
        guard minutes > 0 else { return "곧" }
        guard minutes >= 60 else { return "\(minutes)분 남음" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)시간 남음" : "\(hours)시간 \(rest)분 남음"
    }

    // MARK: - Content

    private var subject: String {
        entry.lesson?.subject ?? "수업 없음"
    }

    /// Two characters is the most the circular family can set legibly, and
    /// two is also what the end-of-day state needs.
    private var shortSubject: String {
        entry.lesson.map { String($0.subject.prefix(2)) } ?? "종료"
    }

    private var periodText: String {
        entry.lesson.map(\.period).map(String.init) ?? "—"
    }

    private var inlineText: String {
        guard let lesson = entry.lesson else { return "수업 없음" }
        let prefix = entry.status == .future ? "내일 " : ""
        return "\(prefix)\(lesson.period)교시 \(lesson.subject)"
    }

    /// Teacher when there is one, otherwise when the lesson starts. The day is
    /// left to the status line so the two never say "내일" at once.
    private var subtitle: String {
        if let teacher = entry.lesson?.teacher, !teacher.isEmpty { return teacher }
        return entry.startsAt?.schoolClockText ?? ""
    }

    /// The circle has room for one short line under the subject — dropped
    /// entirely when there is nothing worth putting there.
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

