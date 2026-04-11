import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: NutritionStore

    /// Nutrient IDs the user is actively tracking (shown in “Your goals”).
    @State private var trackedIds: Set<Int> = []
    @State private var draft: [Int: String] = [:]
    @State private var showValidation = false

    /// Which category disclosure groups are expanded under “Your goals”.
    @State private var expandedYourCategories: Set<NutrientCategory> = []
    /// Which category disclosure groups are expanded under “Add a goal”.
    @State private var expandedAddCategories: Set<NutrientCategory> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if trackedIds.isEmpty {
                        Text("You have not set any goals yet. Expand a category under “Add a goal” and choose a nutrient.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(NutrientCategory.allCases, id: \.self) { category in
                            let active = activeDefinitions(in: category)
                            if !active.isEmpty {
                                DisclosureGroup(
                                    isExpanded: isExpandedYour(category)
                                ) {
                                    ForEach(active) { def in
                                        goalRow(def: def)
                                    }
                                } label: {
                                    Text(category.rawValue)
                                        .font(.headline)
                                }
                            }
                        }
                    }

                    Button("Save Goals") {
                        saveGoal()
                    }
                } header: {
                    Text("Your goals")
                }

                Section {
                    ForEach(NutrientCategory.allCases, id: \.self) { category in
                        let available = availableDefinitions(in: category)
                        if !available.isEmpty {
                            DisclosureGroup(
                                isExpanded: isExpandedAdd(category)
                            ) {
                                ForEach(available) { def in
                                    Button {
                                        addGoal(def)
                                    } label: {
                                        HStack {
                                            Text(def.name)
                                            Spacer()
                                            Text("Add")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } label: {
                                Text(category.rawValue)
                                    .font(.headline)
                            }
                        }
                    }
                } header: {
                    Text("Add a goal")
                } footer: {
                    Text("Choosing a nutrient adds it with a suggested value you can edit. Remove a goal with the button beside its field.")
                        .font(.footnote)
                }

                if showValidation {
                    Section {
                        Text("Enter a valid non‑negative number for each goal, or remove the goal.")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section("Current streak rule") {
                    Text("A day counts when every active goal is met: minimums reached (or maximums not exceeded for cholesterol, sodium, and total fat).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Consistency") {
                    Text("You have met your goals on \(store.consistencyPercent, specifier: "%.1f")% of logged days.")
                }
            }
            .navigationTitle("Goals")
            .onAppear {
                syncFromStore()
            }
            .onChange(of: store.goal.targets) { _ in
                syncFromStore()
            }
        }
    }

    private func isExpandedYour(_ category: NutrientCategory) -> Binding<Bool> {
        Binding(
            get: { expandedYourCategories.contains(category) },
            set: { isOn in
                if isOn {
                    expandedYourCategories.insert(category)
                } else {
                    expandedYourCategories.remove(category)
                }
            }
        )
    }

    private func isExpandedAdd(_ category: NutrientCategory) -> Binding<Bool> {
        Binding(
            get: { expandedAddCategories.contains(category) },
            set: { isOn in
                if isOn {
                    expandedAddCategories.insert(category)
                } else {
                    expandedAddCategories.remove(category)
                }
            }
        )
    }

    private func activeDefinitions(in category: NutrientCategory) -> [NutrientCatalog.Definition] {
        NutrientCatalog.tracked.filter { $0.category == category && trackedIds.contains($0.id) }
    }

    private func availableDefinitions(in category: NutrientCategory) -> [NutrientCatalog.Definition] {
        NutrientCatalog.tracked.filter { $0.category == category && !trackedIds.contains($0.id) }
    }

    private func goalRow(def: NutrientCatalog.Definition) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(def.name)
                    .font(.subheadline)
                Text(def.unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            TextField("Goal", text: Binding(
                get: { draft[def.id] ?? "" },
                set: { draft[def.id] = $0 }
            ))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 88)

            Button(role: .destructive) {
                removeGoal(def.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .imageScale(.medium)
                    .accessibilityLabel("Remove goal")
            }
            .buttonStyle(.borderless)
        }
    }

    private func addGoal(_ def: NutrientCatalog.Definition) {
        trackedIds.insert(def.id)
        if draft[def.id] == nil || draft[def.id]?.isEmpty == true {
            draft[def.id] = formatGoal(def.defaultGoal)
        }
        expandedYourCategories.insert(def.category)
        showValidation = false
    }

    private func removeGoal(_ id: Int) {
        trackedIds.remove(id)
        draft.removeValue(forKey: id)
        if let cat = NutrientCatalog.definition(for: id)?.category {
            if activeDefinitions(in: cat).isEmpty {
                expandedYourCategories.remove(cat)
            }
        }
        showValidation = false
        persistRemovalOfGoal(id: id)
    }

    /// Writes zero for the removed id so streak logic updates immediately.
    private func persistRemovalOfGoal(id: Int) {
        var targets: [Int: Double] = [:]
        for def in NutrientCatalog.tracked {
            targets[def.id] = store.goal.targets[def.id] ?? 0
        }
        targets[id] = 0
        store.updateGoal(targets: targets)
    }

    private func syncFromStore() {
        let fromStore = Set(store.goal.targets.filter { $0.value > 0 }.map(\.key))
        trackedIds = fromStore.union(trackedIds)
        for id in trackedIds {
            if let g = store.goal.targets[id], g > 0 {
                draft[id] = formatGoal(g)
            }
        }
    }

    private func formatGoal(_ g: Double) -> String {
        if g.rounded() == g { return String(format: "%.0f", g) }
        return String(format: "%.2f", g)
    }

    private func saveGoal() {
        var targets: [Int: Double] = [:]
        for def in NutrientCatalog.tracked {
            targets[def.id] = 0
        }
        for id in trackedIds {
            let raw = draft[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !raw.isEmpty, let v = Double(raw), v >= 0 else {
                showValidation = true
                return
            }
            targets[id] = v
        }
        store.updateGoal(targets: targets)
        showValidation = false
    }
}
