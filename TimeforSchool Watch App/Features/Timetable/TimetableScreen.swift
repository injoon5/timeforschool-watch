import SwiftUI

/// The timetable page: every lesson of the relevant school day, with one live
/// marker showing where the wearer is in it.
struct TimetableScreen: View {
    @Environment(SchoolStore.self) private var store

    var body: some View {
        // Re-resolving once a minute is enough: every boundary in a school day
        // falls on a whole minute, and the view is cheap to rebuild.
        TimelineView(.everyMinute) { context in
            TimetableList(
                presentation: TimetablePresentation.resolve(now: SchoolClock.displayDate(context.date), week: store.week),
                availability: store.availability
            )
        }
        .containerBackground(Palette.pageBackground(Palette.signal), for: .tabView)
    }
}
