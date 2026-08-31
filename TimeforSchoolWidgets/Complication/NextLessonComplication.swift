import SwiftUI
import WidgetKit

/// Watch-face complications showing the current or next lesson.
struct NextLessonComplication: Widget {
    nonisolated static let kind = "school.timefor.watch.NextLesson"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NextLessonProvider(cadence: .bell)) { entry in
            NextLessonComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .environment(\.locale, .school)
                .widgetURL(DeepLink.timetable.url)
        }
        .configurationDisplayName("다음 수업")
        .description("지금 또는 다음 교시를 보여줍니다.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}
