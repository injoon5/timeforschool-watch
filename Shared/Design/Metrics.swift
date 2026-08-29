import Foundation

/// Layout constants shared by the timetable and meal screens.
enum Metrics {
    /// Inset from the edge of a page to its content.
    static let pageInset: CGFloat = 4
    /// Padding inside a timetable row, inside its filled bar.
    static let rowPadding: CGFloat = 8
    static let rowVerticalPadding: CGFloat = 5
    static let rowSpacing: CGFloat = 2
    static let rowCornerRadius: CGFloat = 9
    /// Gap between the period number and the subject.
    static let columnGap: CGFloat = 8
    /// Ceiling on the teacher column so a long name can never crowd out the
    /// subject, which matters more.
    static let maxTeacherColumnWidth: CGFloat = 62
    /// Thickness of the break-time rule drawn between two rows.
    static let breakRuleHeight: CGFloat = 2
}
