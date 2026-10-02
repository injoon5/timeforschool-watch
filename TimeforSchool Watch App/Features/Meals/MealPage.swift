import SwiftUI

/// One meal service on one day: every dish in a single column, with the
/// calorie count set apart at the foot of the list.
struct MealPage: View {
    let presentation: MealPresentation
    let content: MealContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                MealHeader(presentation: presentation)

                if case .menu(let meal) = content {
                    dishList(meal)
                    if let calories = meal.caloriesText {
                        CalorieChip(text: calories)
                            .padding(.top, 2)
                    }
                } else {
                    MealStateMessage(content: content)
                }
            }
            .padding(.horizontal, Metrics.pageInset + 4)
            .padding(.bottom, 28)  // clears the page indicator
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Palette.pageBackground(Palette.meal), for: .tabView)
    }

    private func dishList(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(meal.dishes.enumerated(), id: \.offset) { _, dish in
                Text(dish)
                    .font(Typography.dish)
                    .signageTracking()
                    .foregroundStyle(Palette.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
