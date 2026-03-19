import SwiftUI

@main
struct NutritionTrackerApp: App {
    @StateObject private var store = NutritionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
