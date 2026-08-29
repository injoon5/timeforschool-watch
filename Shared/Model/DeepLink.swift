import Foundation

/// Routes a tap on a widget to the screen that widget is about.
///
/// Without this, tapping either widget in the Smart Stack drops the wearer on
/// whichever page the app happened to be left on.
enum DeepLink: String, Sendable {
    case timetable
    case meals

    static let scheme = "timeforschool"

    var url: URL? { URL(string: "\(Self.scheme)://\(rawValue)") }

    init?(url: URL) {
        guard url.scheme == Self.scheme, let link = DeepLink(rawValue: url.host() ?? "") else { return nil }
        self = link
    }
}
