import SwiftUI

/// The meals page: 중식 and 석식 as two horizontal pages.
///
/// Which day each page shows, and which of the two leads, both follow the
/// clock — 중식 rolls over at 13:10, 석식 at 18:40 — so the meal the wearer is
/// most likely to care about is always the one already on screen.
struct MealsScreen: View {
    @Environment(SchoolStore.self) private var store

    @State private var selection: MealKind = .lunch

    var body: some View {
        TimelineView(.everyMinute) { context in
            let pages = MealPresentation.pages(
                now: SchoolClock.displayDate(context.date),
                calendar: store.mealCalendar
            )

            TabView(selection: $selection) {
                ForEach(pages) { page in
                    Tab(value: page.kind) {
                        MealPage(presentation: page, content: store.content(for: page))
                    }
                }
            }
            .tabViewStyle(.page)
            .onChange(of: pages.first?.kind, initial: true) { _, leading in
                guard let leading else { return }
                selection = leading
            }
        }
    }
}
