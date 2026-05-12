import SwiftUI

struct AllEntriesHistoryView: View {
    @EnvironmentObject private var store: NutritionStore
    @State private var detailEntry: FoodEntry?

    var body: some View {
        List {
            if store.entries.isEmpty {
                Text("No foods added yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.entries) { entry in
                    Button {
                        detailEntry = entry
                    } label: {
                        HistoryEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: store.deleteEntries)
            }
        }
        .navigationTitle("All Entries")
        .toolbar {
            if !store.entries.isEmpty {
                EditButton()
            }
        }
        .sheet(item: $detailEntry) { entry in
            FoodEntryDetailView(entry: entry)
        }
    }
}
