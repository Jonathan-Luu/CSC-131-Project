import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: NutritionStore

    private var totals: [Int: Double] {
        store.todaysTotals
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(NutrientCategory.allCases, id: \.self) { category in
                    let defs = NutrientCatalog.tracked.filter { $0.category == category }
                    if !defs.isEmpty {
                        Section(category.rawValue) {
                            ForEach(defs) { def in
                                nutrientRow(def: def, value: totals[def.id] ?? 0)
                            }
                        }
                    }
                }

                Section("Goal Consistency") {
                    HStack {
                        Text("Days goals met")
                        Spacer()
                        Text("\(store.consistencyPercent, specifier: "%.1f")%")
                            .fontWeight(.semibold)
                    }
                    ProgressView(value: store.consistencyPercent, total: 100)
                }
            }
            .navigationTitle("Nutrition Tracker")
        }
    }

    private func nutrientRow(def: NutrientCatalog.Definition, value: Double) -> some View {
        let goal = store.goal.targets[def.id] ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(def.name)
                Spacer()
                if goal > 0 {
                    Text("\(format(value)) / \(format(goal)) \(def.unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(format(value)) \(def.unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if goal > 0 {
                if def.goalIsMaximum {
                    ProgressView(value: normalizedProgress(value: value, goal: goal))
                        .tint(value > goal ? .red : .yellow)
                } else {
                    ProgressView(value: normalizedProgress(value: value, goal: goal))
                        .tint(value > goal ? .green : .gray)
                }
            }
        }
    }

    private func format(_ x: Double) -> String {
        if x >= 100 { return String(format: "%.0f", x) }
        if x >= 10 { return String(format: "%.1f", x) }
        return String(format: "%.2f", x)
    }

    private func normalizedProgress(value: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1)
    }
}
