import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: NutritionStore
    @State private var showAllNutrientsExpanded = false
    @State private var expandedAdditionalCategories: Set<NutrientCategory> = []

    private var totals: [Int: Double] {
        store.todaysTotals
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(NutrientCategory.allCases, id: \.self) { category in
                    let defs = NutrientCatalog.tracked.filter {
                        $0.category == category && hasDailyGoal(for: $0.id)
                    }
                    if !defs.isEmpty {
                        Section(category.rawValue) {
                            ForEach(defs) { def in
                                nutrientRow(def: def, value: totals[def.id] ?? 0)
                            }
                        }
                    }
                }

                Section {
                    DisclosureGroup(
                        isExpanded: $showAllNutrientsExpanded
                    ) {
                        if untrackedDefinitions.isEmpty {
                            Text("You're currently tracking all nutrients")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(NutrientCategory.allCases, id: \.self) { category in
                                let defs = additionalDefinitions(in: category)
                                if !defs.isEmpty {
                                    DisclosureGroup(
                                        isExpanded: additionalCategoryBinding(for: category)
                                    ) {
                                        ForEach(defs) { def in
                                            nutrientRow(def: def, value: totals[def.id] ?? 0)
                                        }
                                    } label: {
                                        Text(category.rawValue)
                                            .font(.headline)
                                    }
                                }
                            }
                        }
                    } label: {
                        Text("Show Untracked Nutrients")
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
            .onChange(of: showAllNutrientsExpanded) { isExpanded in
                if !isExpanded {
                    expandedAdditionalCategories.removeAll()
                }
            }
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

    private func hasDailyGoal(for nutrientId: Int) -> Bool {
        (store.goal.targets[nutrientId] ?? 0) > 0
    }

    private func additionalDefinitions(in category: NutrientCategory) -> [NutrientCatalog.Definition] {
        untrackedDefinitions.filter { $0.category == category }
    }

    private func additionalCategoryBinding(for category: NutrientCategory) -> Binding<Bool> {
        Binding(
            get: { expandedAdditionalCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedAdditionalCategories.insert(category)
                } else {
                    expandedAdditionalCategories.remove(category)
                }
            }
        )
    }

    private var untrackedDefinitions: [NutrientCatalog.Definition] {
        NutrientCatalog.tracked.filter { !hasDailyGoal(for: $0.id) }
    }
}
