import SwiftUI
import WidgetKit

/// The independently configurable Smart Stack card for lesson information.
struct NextLessonWidget: Widget {
    nonisolated static let kind = "school.timefor.watch.NextLessonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NextLessonProvider(cadence: .minute)) { entry in
            // The view owns its own container background: the Smart Stack card
            // is a full-colour design, and a face renders it tinted instead.
            NextLessonWidgetView(entry: entry)
                .environment(\.locale, .school)
                .widgetURL(DeepLink.timetable.url)
        }
        .configurationDisplayName("다음 수업 카드")
        .description("스마트 스택에서 지금 또는 다음 교시를 보여줍니다.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
        // The Smart Stack strips container backgrounds by default, which
        // leaves the arch floating on black instead of its own field.
        .containerBackgroundRemovable(false)
    }
}

struct NextLessonWidgetPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            widgetPreview(entry: .previewCurrent)
                .previewDisplayName("Smart Stack · 수업 중")
            widgetPreview(entry: .previewFirst)
                .previewDisplayName("Smart Stack · 1교시 전")
            widgetPreview(entry: .previewLast)
                .previewDisplayName("Smart Stack · 마지막 교시")
            widgetPreview(entry: .previewFinished)
                .previewDisplayName("Smart Stack · 수업 끝")
            widgetPreview(entry: .previewTomorrow)
                .previewDisplayName("Smart Stack · 내일")
            widgetPreview(entry: .previewBreak)
                .previewDisplayName("Smart Stack · 쉬는 시간")
            widgetPreview(entry: .previewEmptyWeek)
                .previewDisplayName("Smart Stack · 빈 주")
        }
    }

    private static func widgetPreview(entry: NextLessonEntry) -> some View {
        NextLessonWidgetView(entry: entry)
            .environment(\.locale, .school)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }

}

private extension Lesson {
    static func sample(_ period: Int, _ subject: String, _ teacher: String) -> Lesson {
        Lesson(period: period, subject: subject, teacher: teacher, isReplaced: false, originalSubject: nil)
    }
}

private extension NextLessonEntry {
    static let day: [Lesson] = [
        .sample(1, "체육", "임건*"),
        .sample(2, "음악", "임서*"),
        .sample(3, "수학", "최민*"),
        .sample(4, "국어", "신영*"),
        .sample(5, "정보", "김선*"),
    ]

    static let previewCurrent = NextLessonEntry(
        date: .now,
        lesson: day[1],
        status: .current,
        slots: [day[0], day[1], day[2]],
        startsAt: .now.addingTimeInterval(-27 * 60),
        endsAt: .now.addingTimeInterval(23 * 60),
        dayProgress: 0.25,
        countdownTarget: .now.addingTimeInterval(23 * 60)
    )

    /// Nothing precedes the first period, so the left slot stays empty and
    /// the lesson keeps the crest.
    static let previewFirst = NextLessonEntry(
        date: .now,
        lesson: day[0],
        status: .upcoming,
        slots: [nil, day[0], day[1]],
        startsAt: .now.addingTimeInterval(12 * 60),
        endsAt: .now.addingTimeInterval(62 * 60),
        dayProgress: 0,
        countdownTarget: .now.addingTimeInterval(12 * 60)
    )

    /// …and nothing follows the last one, so the right slot stays empty.
    static let previewLast = NextLessonEntry(
        date: .now,
        lesson: day[4],
        status: .current,
        slots: [day[3], day[4], nil],
        startsAt: .now.addingTimeInterval(-40 * 60),
        endsAt: .now.addingTimeInterval(10 * 60),
        isLastLesson: true,
        dayProgress: 1,
        countdownTarget: .now.addingTimeInterval(10 * 60)
    )

    static let previewFinished = NextLessonEntry(
        date: .now,
        lesson: nil,
        status: .finished,
        slots: [day[3], day[4], nil],
        startsAt: nil,
        endsAt: nil,
        dayProgress: 1,
        countdownTarget: nil
    )

    /// Between two lessons: the marker hovers at the seam and the footer
    /// names the break before it counts to the bell.
    static let previewBreak = NextLessonEntry(
        date: .now,
        lesson: day[2],
        status: .upcoming,
        slots: [day[1], day[2], day[3]],
        startsAt: .now.addingTimeInterval(6 * 60),
        endsAt: .now.addingTimeInterval(56 * 60),
        breakStartedAt: .now.addingTimeInterval(-4 * 60),
        dayProgress: 0.5,
        countdownTarget: .now.addingTimeInterval(6 * 60)
    )

    /// Nothing on the timetable at all — a fetched week with no lessons.
    static let previewEmptyWeek = NextLessonEntry(
        date: .now,
        lesson: nil,
        status: .upcoming,
        startsAt: nil,
        endsAt: nil,
        countdownTarget: nil
    )

    static let previewTomorrow = NextLessonEntry(
        date: .now,
        lesson: day[0],
        status: .future,
        slots: [nil, day[0], day[1]],
        startsAt: .now.addingTimeInterval(24 * 60 * 60),
        endsAt: .now.addingTimeInterval((24 * 60 + 50) * 60),
        dayLabel: "내일",
        dayProgress: 0,
        countdownTarget: nil
    )
}
