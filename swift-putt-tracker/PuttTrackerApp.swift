import SwiftUI
import SwiftData

@main
struct PuttTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [Round.self, HoleScore.self])
    }
}
