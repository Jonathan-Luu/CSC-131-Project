import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isSignedIn {
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
                    MoreView()
                        .tabItem {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                }
            } else {
                LoginView()
            }
        }
    }
}
