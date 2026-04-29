import SwiftUI

/// Nutrient breakdown for a logged `FoodEntry`, shown from history (sheet pattern matches `AddFoodView` portion flow).
struct FoodEntryDetailView: View {
    let entry: FoodEntry
    @Environment(\.dismiss) private var dismiss

    private static let macroNutrientIds: [Int] = [1008, 1003, 1005, 1004]
    private static let macroIdSet = Set(macroNutrientIds)

    private var trackedIdSet: Set<Int> {
        Set(NutrientCatalog.tracked.map(\.id))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(entry.name)
                        .font(.body)
                    LabeledContent("Logged") {
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Section("Energy & macros") {
                    ForEach(Self.macroNutrientIds, id: \.self) { nutrientId in
                        macroRow(nutrientId: nutrientId)
                    }
                }

                ForEach(NutrientCategory.allCases, id: \.self) { category in
                    let defs = NutrientCatalog.tracked.filter { def in
                        !Self.macroIdSet.contains(def.id) && def.category == category && entry.nutrients[def.id] != nil
                    }
                    if !defs.isEmpty {
                        Section(category.rawValue) {
                            ForEach(defs) { def in
                                if let value = entry.nutrients[def.id] {
                                    labeledNutrientRow(def: def, value: value)
                                }
                            }
                        }
                    }
                }

                /* let unknownIds = entry.nutrients.keys.filter { !trackedIdSet.contains($0) }.sorted()
                if !unknownIds.isEmpty {
                    Section("Other nutrients") {
                        ForEach(unknownIds, id: \.self) { id in
                            if let value = entry.nutrients[id] {
                                HStack {
                                    Text("Nutrient ID \(id)")
                                    Spacer()
                                    Text(format(value))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } */
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func macroRow(nutrientId: Int) -> some View {
        let def = NutrientCatalog.definition(for: nutrientId)
        let name = def?.name ?? "Nutrient \(nutrientId)"
        let unit = def?.unit ?? ""
        HStack {
            Text(name)
            Spacer()
            if let v = entry.nutrients[nutrientId] {
                Text(formattedAmount(v, unit: unit))
                    .foregroundStyle(.secondary)
            } else {
                Text("Not recorded")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func labeledNutrientRow(def: NutrientCatalog.Definition, value: Double) -> some View {
        HStack {
            Text(def.name)
            Spacer()
            Text(formattedAmount(value, unit: def.unit))
                .foregroundStyle(.secondary)
        }
    }

    private func formattedAmount(_ value: Double, unit: String) -> String {
        let n = format(value)
        let u = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return u.isEmpty ? n : "\(n) \(u)"
    }

    private func format(_ x: Double) -> String {
        if x >= 100 { return String(format: "%.0f", x) }
        if x >= 10 { return String(format: "%.1f", x) }
        return String(format: "%.2f", x)
    }
}
