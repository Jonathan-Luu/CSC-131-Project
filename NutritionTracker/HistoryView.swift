import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: NutritionStore

    var body: some View {
        NavigationStack {
            List {
                if store.entries.isEmpty {
                    Text("No foods added yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.name)
                                .font(.headline)
                            Text(summaryLine(for: entry))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: store.deleteEntries)
                }
            }
            .navigationTitle("Food History")
            .toolbar {
                EditButton()
            }
        }
    }

    private func summaryLine(for entry: FoodEntry) -> String {
        let c = entry.nutrients[1008].map { String(format: "%.0f kcal", $0) }
        let p = entry.nutrients[1003].map { String(format: "%.0fg protein", $0) }
        let f = entry.nutrients[1079].map { String(format: "%.1fg fiber", $0) }
        let parts = [c, p, f].compactMap { $0 }
        if parts.isEmpty {
            return "\(entry.nutrients.count) nutrient values"
        }
        return parts.joined(separator: " · ")
    }
}
