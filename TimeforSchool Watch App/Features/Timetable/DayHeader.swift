import SwiftUI

/// The line above the timetable: which day is on screen, and whether it is
/// still today.
struct DayHeader: View {
    let presentation: TimetablePresentation

    var body: some View {
        HStack(spacing: 6) {
            Text(weekdayText)
                .font(Typography.label)
                .labelTracking()
                .foregroundStyle(Palette.secondaryText)

            if presentation.isFutureDay {
                AdvisoryTag(text: futureTagText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.rowPadding)
        .accessibilityElement(children: .combine)
    }

    private var weekdayText: String {
        "\(SchoolClock.koreanWeekdaySymbol(for: presentation.date))요일"
    }

    /// The weekday is already stated to the left, so the tag never repeats it.
    private var futureTagText: String {
        presentation.isTomorrow ? "내일" : SchoolDate(presentation.date).monthDayLabel
    }
}
