import SwiftUI

/// The app's colour vocabulary: NYCTA route bullets, adjusted for an OLED
/// watch display where the ground is always pure black.
///
/// Each colour carries one meaning and appears nowhere else — blue is "now",
/// yellow is "not today", orange and violet identify the two meal services.
enum Palette {
    /// A/C/E blue, lifted off the printed #0039A6 so it holds up at 8pt.
    static let signal = Color(red: 0.04, green: 0.24, blue: 1.00)
    /// 4/5/6 green, lifted off the printed #00933C — the meals section.
    static let meal = Color(red: 0.00, green: 0.66, blue: 0.29)
    /// N/Q/R/W yellow, used the way the MTA uses it: for advisories.
    static let advisory = Color(red: 0.99, green: 0.80, blue: 0.04)

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.38)
    /// Text drawn on top of a filled signal bar.
    static let onSignal = Color.white
    static let onSignalSecondary = Color.white.opacity(0.75)

    /// The backdrop behind a paged screen: a short wash of the page's own
    /// colour that reaches black by the top third, so it identifies the page
    /// without competing with the text sitting on it.
    static func pageBackground(_ color: Color) -> some ShapeStyle {
        LinearGradient(
            stops: [
                .init(color: color.opacity(0.38), location: 0),
                .init(color: color.opacity(0.10), location: 0.18),
                .init(color: .black, location: 0.42),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
