import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                }

                Section("Tools") {
                    NavigationLink {
                        BMRCalculatorView()
                    } label: {
                        Label("BMR Calculator", systemImage: "figure.walk")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}
