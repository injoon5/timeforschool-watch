import SwiftUI

/// The app's two screens, switched by the toolbar control or a widget link.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SchoolStore.self) private var store

    @State private var page: RootPage = .timetable

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(Palette.pageBackground(page.accent))
                    .ignoresSafeArea()

                currentPage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(page)
                    .transition(.opacity)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        page = page.next
                    } label: {
                        Label(page.switchLabel, systemImage: page.switchSymbol)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityValue(page == .timetable ? "시간표" : "급식")
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: page)
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

    @ViewBuilder
    private var currentPage: some View {
        switch page {
        case .timetable:
            TimetableScreen()
        case .meals:
            MealsScreen()
        }
    }
}

enum RootPage: Hashable {
    case timetable
    case meals

    var next: Self {
        switch self {
        case .timetable: .meals
        case .meals: .timetable
        }
    }

    var accent: Color {
        switch self {
        case .timetable: Palette.signal
        case .meals: Palette.meal
        }
    }

    var switchSymbol: String {
        switch next {
        case .timetable: "calendar"
        case .meals: "fork.knife"
        }
    }

    var switchLabel: String {
        switch next {
        case .timetable: "시간표 보기"
        case .meals: "급식 보기"
        }
    }
}
