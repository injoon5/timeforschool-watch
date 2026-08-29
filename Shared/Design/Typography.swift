import SwiftUI

/// Type styles for the app.
///
/// Transit signage reads at a glance because it uses very few sizes, heavy
/// weights, and tight tracking. All styles are built from Dynamic Type text
/// styles so they still respond to the wearer's text size setting.
enum Typography {
    /// Subject names — the thing the wearer is actually looking for.
    static let subject = Font.system(.body, weight: .semibold)
    /// Period numbers. Tabular figures keep the column from twitching.
    static let period = Font.system(.body, weight: .bold).monospacedDigit()
    /// Teacher names, one step down and one weight lighter.
    static let teacher = Font.system(.footnote, weight: .medium)
    /// Dish names on the meals screen.
    static let dish = Font.system(.body, weight: .medium)
    /// The 중식 / 석식 page title.
    static let pageTitle = Font.system(.title3, weight: .bold)
    /// Small all-caps-feeling labels: weekday, "내일", kcal.
    static let label = Font.system(.caption2, weight: .bold)
}

extension View {
    /// Signage tracking: slightly tightened, the way Helvetica is set on the
    /// subway's station signs.
    func signageTracking() -> some View { tracking(-0.2) }

    /// Opened-up tracking for the small label styles.
    func labelTracking() -> some View { tracking(0.5) }
}
