import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: NutritionStore

    /// Nutrient IDs the user is actively tracking (shown in "Daily Goal").
    @State private var trackedIds: Set<Int> = []
    @State private var draft: [Int: String] = [:]
    @State private var showValidation = false
    @State private var selectedCategory: NutrientCategory = NutrientCategory.allCases.first ?? .macros
    @State private var selectedNutrientId: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if trackedIds.isEmpty {
                        Text("You have not set any daily goals yet. Choose a category and nutrient below to add one.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(NutrientCategory.allCases, id: \.self) { category in
                            let active = activeDefinitions(in: category)
                            if !active.isEmpty {
                                Text(category.rawValue)
                                    .font(.headline)
                                    .padding(.top, 4)

                                ForEach(active) { def in
                                    goalRow(def: def)
                                }
                            }
                        }
                    }

                    Button("Save Goals") {
                        saveGoal()
                    }
                } header: {
                    Text("Daily Goal")
                }

                Section {
                    if availableDefinitions.isEmpty {
                        Text("All supported nutrients already have goals. Remove one to choose a different nutrient.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(categoriesWithAvailableGoals, id: \.self) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }

                        Picker("Nutrient", selection: selectedNutrientBinding) {
                            Text("Select a nutrient").tag(Int?.none)
                            ForEach(availableDefinitions(in: selectedCategory)) { def in
                                Text(def.name).tag(Optional(def.id))
                            }
                        }

                        Button("Add Goal") {
                            guard
                                let nutrientId = selectedNutrientId,
                                let definition = NutrientCatalog.definition(for: nutrientId)
                            else { return }
                            addGoal(definition)
                        }
                        .disabled(selectedNutrientId == nil)
                    }
                } header: {
                    Text("Add a goal")
                } footer: {
                    Text("Choose a nutrient category, then select a nutrient to add with a suggested value you can edit. Remove a goal with the button beside its field.")
                        .font(.footnote)
                }

                if showValidation {
                    Section {
                        Text("Enter a valid non-negative number for each goal, or remove the goal.")
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
                syncSelectionState()
            }
            .onChange(of: store.goal.targets) { _ in
                syncFromStore()
                syncSelectionState()
            }
            .onChange(of: selectedCategory) { _ in
                updateSelectedNutrientForCurrentCategory()
            }
        }
    }

    private var availableDefinitions: [NutrientCatalog.Definition] {
        NutrientCatalog.tracked.filter { !trackedIds.contains($0.id) }
    }

    private var categoriesWithAvailableGoals: [NutrientCategory] {
        NutrientCategory.allCases.filter { !availableDefinitions(in: $0).isEmpty }
    }

    private var selectedNutrientBinding: Binding<Int?> {
        Binding(
            get: { selectedNutrientId },
            set: { selectedNutrientId = $0 }
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
        showValidation = false
        syncSelectionState()
    }

    private func removeGoal(_ id: Int) {
        trackedIds.remove(id)
        draft.removeValue(forKey: id)
        showValidation = false
        persistRemovalOfGoal(id: id)
        syncSelectionState()
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
        trackedIds = Set(store.goal.targets.filter { $0.value > 0 }.map(\.key))
        draft = draft.filter { trackedIds.contains($0.key) }
        for id in trackedIds {
            if let goal = store.goal.targets[id], goal > 0 {
                draft[id] = formatGoal(goal)
            }
        }
    }

    private func syncSelectionState() {
        let availableCategories = categoriesWithAvailableGoals
        guard !availableCategories.isEmpty else {
            selectedNutrientId = nil
            return
        }

        if !availableCategories.contains(selectedCategory) {
            selectedCategory = availableCategories[0]
        }

        updateSelectedNutrientForCurrentCategory()
    }

    private func updateSelectedNutrientForCurrentCategory() {
        let availableForCategory = availableDefinitions(in: selectedCategory)
        if availableForCategory.contains(where: { $0.id == selectedNutrientId }) {
            return
        }
        selectedNutrientId = availableForCategory.first?.id
    }

    private func formatGoal(_ goal: Double) -> String {
        if goal.rounded() == goal { return String(format: "%.0f", goal) }
        return String(format: "%.2f", goal)
    }

    private func saveGoal() {
        var targets: [Int: Double] = [:]
        for def in NutrientCatalog.tracked {
            targets[def.id] = 0
        }
        for id in trackedIds {
            let raw = draft[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !raw.isEmpty, let value = Double(raw), value >= 0 else {
                showValidation = true
                return
            }
            targets[id] = value
        }
        store.updateGoal(targets: targets)
        showValidation = false
    }
}
