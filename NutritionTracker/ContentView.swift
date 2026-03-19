import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }
            AddFoodView()
                .tabItem {
                    Label("Add Food", systemImage: "plus.circle")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
            RecommendationsView()
                .tabItem {
                    Label("Suggestions", systemImage: "lightbulb")
                }
            BMRCalculatorView()
                .tabItem {
                    Label("BMR", systemImage: "figure.walk")
                }
        }
    }
}
