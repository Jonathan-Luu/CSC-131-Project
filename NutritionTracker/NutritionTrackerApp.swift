import SwiftUI

@main
struct NutritionTrackerApp: App {
    @StateObject private var store = NutritionStore()
    @StateObject private var foodDatabase = FoundationFoodDatabase()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(foodDatabase)
        }
    }
}
