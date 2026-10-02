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

/// Everything a page shows instead of a menu.
///
/// A weekend, a first fetch still running, and a fetch that failed all leave
/// the same blank page, so each says which one it is rather than letting the
/// wearer read a network failure as "no lunch today".
struct MealStateMessage: View {
    let content: MealContent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.subject)
                .foregroundStyle(Palette.primaryText)
            Text(detail)
                .font(Typography.teacher)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch content {
        case .menu: ""
        case .loading: "불러오는 중"
        case .unreachable: "불러올 수 없음"
        case .unpublished: "급식 없음"
        case .unknown: "정보 없음"
        case .noService: "예정된 급식 없음"
        }
    }

    private var detail: String {
        switch content {
        case .menu: ""
        case .loading: "급식을 가져오고 있어요."
        case .unreachable: "네트워크를 확인해 주세요."
        case .unpublished: "이 날은 급식 정보가 없어요."
        case .unknown: "이 날은 아직 받아오지 못했어요."
        case .noService: "다음 급식은 아직 공개되지 않았어요."
        }
    }
}
