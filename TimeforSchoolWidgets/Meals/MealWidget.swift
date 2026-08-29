import SwiftUI
import WidgetKit

/// A Smart Stack card showing whichever meal is coming up next.
struct MealWidget: Widget {
    static let kind = "school.timefor.watch.Meal"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: MealProvider()) { entry in
            MealWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .environment(\.locale, .school)
                .widgetURL(DeepLink.meals.url)
        }
        .configurationDisplayName("급식")
        .description("다음 중식 또는 석식 메뉴를 보여줍니다.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
