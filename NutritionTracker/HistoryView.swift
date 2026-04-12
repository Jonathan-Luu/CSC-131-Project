import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: NutritionStore
    @State private var detailEntry: FoodEntry?

    var body: some View {
        NavigationStack {
            List {
                if store.entries.isEmpty {
                    Text("No foods added yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.entries) { entry in
                        Button {
                            detailEntry = entry
                        } label: {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: store.deleteEntries)
                }
            }
            .navigationTitle("Food History")
            .toolbar {
                EditButton()
            }
            .sheet(item: $detailEntry) { entry in
                FoodEntryDetailView(entry: entry)
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
