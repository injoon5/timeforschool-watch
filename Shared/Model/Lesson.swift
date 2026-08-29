import Foundation

/// A single period on a school day.
struct Lesson: Hashable, Codable, Sendable, Identifiable {
    var period: Int
    var subject: String
    var teacher: String
    /// `true` when the school replaced the originally scheduled lesson.
    var isReplaced: Bool
    var originalSubject: String?

    var id: Int { period }

    /// Teacher names arrive masked ("서지*") and are occasionally empty.
    var hasTeacher: Bool { !teacher.isEmpty }
}
