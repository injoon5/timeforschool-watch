import SwiftUI

/// A filled yellow flag. Reserved for "this is not today" — the one thing the
/// wearer must not misread — where it sits alone and has to carry itself.
struct AdvisoryTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typography.label)
            .labelTracking()
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Palette.advisory, in: .capsule)
    }
}

/// The same flag set as plain text, for use beside something already filled —
/// two solid shapes next to each other read as two competing titles.
struct AdvisoryLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typography.label)
            .labelTracking()
            .foregroundStyle(Palette.advisory)
    }
}
