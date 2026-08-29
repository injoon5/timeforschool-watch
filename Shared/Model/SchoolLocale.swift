import Foundation

extension Locale {
    /// Every string in this app is Korean, so dates and relative times are
    /// formatted in Korean too — otherwise a watch set to English would render
    /// "23 min" beside a hand-written "남음".
    static let school = Locale(identifier: "ko_KR")
}
