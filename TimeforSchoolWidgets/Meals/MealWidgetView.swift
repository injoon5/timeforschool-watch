import SwiftUI
import WidgetKit

/// Renders the rectangular meal Smart Stack card independently from its
/// watch-face complication.
struct MealWidgetView: View {
    let entry: MealEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(headerText)
                    .font(.system(.caption2, weight: .bold))
                    .widgetAccentable()
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let calories = entry.meal?.caloriesText {
                    Text(calories)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(-1)
                }
            }

            Text(dishSummary)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(entry.meal?.dishes.isEmpty == false ? .primary : .secondary)
                .lineLimit(6)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(headerText), \(dishSummary)")
    }

    private var headerText: String {
        let kind = entry.presentation.kind.title
        guard entry.presentation.isFutureDay else { return kind }
        let day = entry.presentation.isTomorrow ? "내일" : entry.presentation.date.shortKoreanLabel
        return "\(kind) · \(day)"
    }

    private var dishSummary: String {
        guard let dishes = entry.meal?.dishes, !dishes.isEmpty else { return "급식 없음" }
        return dishes.joined(separator: ", ")
    }
}

#if DEBUG
struct MealWidgetViewPreviews: PreviewProvider {
    static var previews: some View {
        MealWidgetView(entry: .placeholder)
            .containerBackground(.fill.tertiary, for: .widget)
            .environment(\.locale, .school)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Meal · Smart Stack view")
    }
}
#endif
