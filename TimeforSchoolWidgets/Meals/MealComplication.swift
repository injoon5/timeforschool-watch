import SwiftUI
import WidgetKit

/// The compact watch-face version of the upcoming meal.
struct MealComplication: Widget {
    nonisolated static let kind = "school.timefor.watch.MealComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: MealProvider()) { entry in
            MealComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .environment(\.locale, .school)
                .widgetURL(DeepLink.meals.url)
        }
        .configurationDisplayName("급식 컴플리케이션")
        .description("워치페이스에 다음 급식을 보여줍니다.")
        .supportedFamilies([.accessoryInline])
    }
}
