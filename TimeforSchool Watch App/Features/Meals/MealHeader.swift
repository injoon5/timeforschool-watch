import SwiftUI

/// The plate at the top of a meal page: which service, and which day.
struct MealHeader: View {
    let presentation: MealPresentation

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(presentation.kind.title)
                .font(Typography.pageTitle)
                .signageTracking()
                .foregroundStyle(Palette.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(
                    .regular.tint(Palette.meal.opacity(0.55)),
                    in: .capsule
                )

            if presentation.isFutureDay {
                AdvisoryLabel(text: presentation.isTomorrow ? "내일" : presentation.date.shortKoreanLabel)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The calorie count, set in glass so it reads as a footnote to the menu
/// rather than another dish in it.
struct CalorieChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typography.label)
            .labelTracking()
            .foregroundStyle(Palette.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .glassEffect(.regular, in: .capsule)
    }
}

/// Weekends, holidays, and days the school has not published yet.
struct MealEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("급식 없음")
                .font(Typography.subject)
                .foregroundStyle(Palette.primaryText)
            Text("이 날은 급식 정보가 없어요.")
                .font(Typography.teacher)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
