import SwiftUI
import WidgetKit

/// Renders the meal card. The header carries the service and, when the menu
/// has rolled over, the day — so a glance can never mistake tomorrow's dinner
/// for tonight's.
struct MealWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MealEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(headerText) \(dishSummary)")
        default:
            rectangular
        }
    }

    /// The rectangular family is three short lines tall, so the calorie count
    /// shares the header line rather than claiming a fourth — that space is
    /// worth more to the menu itself.
    private var rectangular: some View {
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

            dishes
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(headerText), \(dishSummary)")
    }

    /// Set at caption2, and allowed to tighten by a fifth.
    ///
    /// Neither is cosmetic: the container decides how many lines actually show,
    /// and a Smart Stack card leaves room for about 2.8 of them. Without the
    /// headroom to shrink, the third line is dropped and half the menu goes
    /// with it. The line limit is only an upper bound.
    private var dishes: some View {
        Text(dishSummary)
            .font(.system(.caption2, weight: .medium))
            .foregroundStyle(entry.meal?.dishes.isEmpty == false ? .primary : .secondary)
            .lineLimit(6)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
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
