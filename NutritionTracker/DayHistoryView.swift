import SwiftUI

struct DayHistoryView: View {
    let day: Date

    @EnvironmentObject private var store: NutritionStore
    @State private var detailEntry: FoodEntry?

    private var entriesForDay: [FoodEntry] {
        store.entries.filter { $0.date.isSameDay(as: day) }
    }

    var body: some View {
        List {
            if entriesForDay.isEmpty {
                Text("No foods logged on this day.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entriesForDay) { entry in
                    Button {
                        detailEntry = entry
                    } label: {
                        HistoryEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle(day.formatted(date: .complete, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !entriesForDay.isEmpty {
                EditButton()
            }
        }
        .sheet(item: $detailEntry) { entry in
            FoodEntryDetailView(entry: entry)
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.map { entriesForDay[$0].id }
        store.entries.removeAll { ids.contains($0.id) }
    }
}

private struct HistoryEntryRow: View {
    let entry: FoodEntry

    var body: some View {
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

