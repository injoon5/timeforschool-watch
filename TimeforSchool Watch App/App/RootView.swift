import SwiftUI

/// The app's two screens, stacked as vertical pages and turned with the crown.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SchoolStore.self) private var store

    @State private var page: RootPage = .timetable

    var body: some View {
        TabView(selection: $page) {
            Tab(value: RootPage.timetable) {
                TimetableScreen()
            }
            Tab(value: RootPage.meals) {
                MealsScreen()
            }
        }
        .tabViewStyle(.verticalPage)
        .environment(\.locale, .school)
        .onAppear { store.refresh() }
        .onOpenURL { url in
            switch DeepLink(url: url) {
            case .timetable: page = .timetable
            case .meals: page = .meals
            case nil: break
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refresh() }
        }
    }
}

enum RootPage: Hashable {
    case timetable
    case meals
}
