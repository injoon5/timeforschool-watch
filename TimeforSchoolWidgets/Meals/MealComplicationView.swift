import SwiftUI
import WidgetKit

/// Renders meal content only in the inline watch-face complication family.
struct MealComplicationView: View {
    let entry: MealEntry

    var body: some View {
        Text("\(serviceText) \(dishSummary)")
            .accessibilityLabel("\(serviceText), \(dishSummary)")
    }

    /// The service, with the day it falls on when that is not today. After a
    /// weekend or a long holiday the next meal is not tomorrow's, so the date
    /// itself stands in rather than a flat "내일".
    private var serviceText: String {
        let kind = entry.presentation.kind.title
        guard entry.presentation.isFutureDay else { return kind }
        let day = entry.presentation.isTomorrow ? "내일" : entry.presentation.date.shortKoreanLabel
        return "\(day) \(kind)"
    }

    private var dishSummary: String {
        entry.content.briefText
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
