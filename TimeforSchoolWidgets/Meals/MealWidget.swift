import SwiftUI
import WidgetKit

/// A Smart Stack card showing whichever meal is coming up next.
struct MealWidget: Widget {
    nonisolated static let kind = "school.timefor.watch.Meal"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: MealProvider()) { entry in
            MealWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .environment(\.locale, .school)
                .widgetURL(DeepLink.meals.url)
        }
        .configurationDisplayName("급식")
        .description("다음 중식 또는 석식 메뉴를 보여줍니다.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct MealWidgetPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            widgetPreview(entry: .previewLunch)
                .previewDisplayName("Smart Stack · 중식")
            widgetPreview(entry: .previewTomorrowDinner)
                .previewDisplayName("Smart Stack · 내일 석식")
        }
    }

    private static func widgetPreview(entry: MealEntry) -> some View {
        MealWidgetView(entry: entry)
            .containerBackground(.fill.tertiary, for: .widget)
            .environment(\.locale, .school)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }

}

private extension MealEntry {
    static let previewLunch = MealEntry(
        date: .now,
        presentation: MealPresentation(
            kind: .lunch,
            date: SchoolDate(.now),
            isFutureDay: false,
            isTomorrow: false
        ),
        meal: Meal(
            kind: .lunch,
            day: SchoolDate(.now),
            dishes: ["기장밥", "오징어무국", "안동찜닭", "배추김치"],
            calories: 915
        )
    )

    static let previewTomorrowDinner = MealEntry(
        date: .now,
        presentation: MealPresentation(
            kind: .dinner,
            date: SchoolDate(.now).adding(days: 1),
            isFutureDay: true,
            isTomorrow: true
        ),
        meal: Meal(
            kind: .dinner,
            day: SchoolDate(.now).adding(days: 1),
            dishes: ["차조밥", "된장찌개", "소불고기", "깍두기", "차조밥", "된장찌개", "소불고기", "깍두기"],
            calories: 802
        )
    )
}
