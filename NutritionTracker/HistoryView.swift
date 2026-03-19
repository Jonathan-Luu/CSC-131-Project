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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                                .font(.headline)
                            Text("\(entry.calories, specifier: "%.0f") kcal | \(entry.protein, specifier: "%.0f")g protein | \(entry.cholesterol, specifier: "%.0f")mg cholesterol")
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
}
