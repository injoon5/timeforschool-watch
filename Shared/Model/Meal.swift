import Foundation

/// The meal services the app surfaces. Raw values match NEIS `MMEAL_SC_CODE`.
enum MealKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case breakfast = "1"
    case lunch = "2"
    case dinner = "3"

    var id: String { rawValue }

    /// Korean title shown on the meal page and in the widget.
    var title: String {
        switch self {
        case .breakfast: "조식"
        case .lunch: "중식"
        case .dinner: "석식"
        }
    }
}

/// One served meal on one day.
struct Meal: Hashable, Codable, Sendable, Identifiable {
    var kind: MealKind
    /// Calendar day the meal is served, normalised to the school's time zone.
    var day: SchoolDate
    var dishes: [String]
    var calories: Double?

    var id: String { "\(day.rawValue)-\(kind.rawValue)" }

    var caloriesText: String? {
        guard let calories else { return nil }
        return "\(Int(calories.rounded())) kcal"
    }
}
