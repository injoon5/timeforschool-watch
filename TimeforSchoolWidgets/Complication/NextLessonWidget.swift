import SwiftUI
import WidgetKit

/// A complication showing the lesson the wearer is in, or the one coming next.
struct NextLessonWidget: Widget {
    nonisolated static let kind = "school.timefor.watch.NextLesson"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NextLessonProvider()) { entry in
            NextLessonView(entry: entry)
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
            .accessoryRectangular,
        ])
    }
}
