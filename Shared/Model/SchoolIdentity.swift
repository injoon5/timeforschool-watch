import Foundation

/// Identifies the class whose timetable and meals the app displays.
///
/// The app ships pre-configured for a single class; keeping the values in one
/// value type means adding a settings screen later only touches the storage,
/// not the networking or view layers.
struct SchoolIdentity: Hashable, Codable, Sendable {
    var schoolCode: String
    var grade: Int
    var classNumber: Int

    static let `default` = SchoolIdentity(schoolCode: "7010208", grade: 1, classNumber: 3)
}
