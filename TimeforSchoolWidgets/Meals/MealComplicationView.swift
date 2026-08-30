import SwiftUI
import WidgetKit

/// Renders meal content only in the inline watch-face complication family.
struct MealComplicationView: View {
    let entry: MealEntry

    var body: some View {
        Text("\(serviceText) \(dishSummary)")
            .accessibilityLabel("\(serviceText), \(dishSummary)")
    }

    private var serviceText: String {
        let kind = entry.presentation.kind.title
        return entry.presentation.isFutureDay ? "내일 \(kind)" : kind
    }

    private var dishSummary: String {
        guard let dishes = entry.meal?.dishes, !dishes.isEmpty else { return "급식 없음" }
        return dishes.joined(separator: ", ")
    }
}

#if DEBUG
struct MealComplicationViewPreviews: PreviewProvider {
    static var previews: some View {
        MealComplicationView(entry: .placeholder)
            .containerBackground(.fill.tertiary, for: .widget)
            .environment(\.locale, .school)
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            .previewDisplayName("Meal · Complication view")
    }
}
#endif
