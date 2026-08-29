import SwiftUI

@main
struct TimeforSchoolApp: App {
    @State private var store = SchoolStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
