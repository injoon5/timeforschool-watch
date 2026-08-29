import SwiftUI

/// Shown when the day has no lessons, or before anything has ever loaded.
struct TimetableEmptyState: View {
    let availability: TimetableAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.subject)
                .foregroundStyle(Palette.primaryText)
            Text(detail)
                .font(Typography.teacher)
                .foregroundStyle(Palette.secondaryText)
        }
        .padding(.horizontal, Metrics.rowPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch availability {
        case .loading: "불러오는 중"
        case .unavailable: "불러올 수 없음"
        case .loaded: "수업 없음"
        }
    }

    private var detail: String {
        switch availability {
        case .loading: "시간표를 가져오고 있어요."
        case .unavailable: "네트워크를 확인해 주세요."
        case .loaded: "이 날은 시간표가 없어요."
        }
    }
}
