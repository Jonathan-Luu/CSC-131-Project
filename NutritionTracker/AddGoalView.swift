import SwiftUI

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NutritionStore

    @State private var searchText = ""
    @State private var expandedCategories = Set(NutrientCategory.allCases)
    @State private var selectedNutrientId: Int?
    @State private var targetText = ""
    @State private var showValidation = false

    var body: some View {
        Form {
            Section("Choose a nutrient") {
                if filteredAvailableDefinitions.isEmpty {
                    Text(emptyStateMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(NutrientCategory.allCases, id: \.self) { category in
                        let defs = filteredDefinitions(in: category)
                        if !defs.isEmpty {
                            DisclosureGroup(
                                isExpanded: expansionBinding(for: category)
                            ) {
                                ForEach(defs) { def in
                                    Button {
                                        select(def)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(def.name)
                                                    .foregroundStyle(.primary)
                                                Text(def.unit)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if selectedNutrientId == def.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.tint)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            } label: {
                                Text(category.rawValue)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }

            Section("New Goal") {
                if let selectedDefinition {
                    LabeledContent("Nutrient", value: selectedDefinition.name)
                    LabeledContent("Unit", value: selectedDefinition.unit)

                    TextField("Target amount", text: $targetText)
                        .keyboardType(.decimalPad)
                } else {
                    Text("Select a nutrient above to set a daily goal.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Save") {
                    saveGoal()
                }
                .disabled(selectedDefinition == nil)
            } footer: {
                Text("Choose a nutrient, enter a target amount, then save to add it to Daily Goals.")
                    .font(.footnote)
            }

            if showValidation {
                Section {
                    Text("Enter a valid target amount greater than zero.")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Add Goal")
        .searchable(text: $searchText, prompt: "Search nutrients")
        .onAppear {
            expandRelevantCategories()
        }
        .onChange(of: searchText) { _ in
            expandRelevantCategories()
        }
    }

    private var selectedDefinition: NutrientCatalog.Definition? {
        guard let selectedNutrientId else { return nil }
        return filteredAvailableDefinitions.first(where: { $0.id == selectedNutrientId })
            ?? availableDefinitions.first(where: { $0.id == selectedNutrientId })
    }

    private var activeGoalIds: Set<Int> {
        Set(store.goal.targets.compactMap { key, value in
            value > 0 ? key : nil
        })
    }

    private var availableDefinitions: [NutrientCatalog.Definition] {
        NutrientCatalog.tracked.filter { !activeGoalIds.contains($0.id) }
    }

    private var filteredAvailableDefinitions: [NutrientCatalog.Definition] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return availableDefinitions }

        return availableDefinitions.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    private var emptyStateMessage: String {
        if availableDefinitions.isEmpty {
            return "All supported nutrients already have goals."
        }
        return "No nutrients match your search."
    }

    private func filteredDefinitions(in category: NutrientCategory) -> [NutrientCatalog.Definition] {
        filteredAvailableDefinitions.filter { $0.category == category }
    }

    private func expansionBinding(for category: NutrientCategory) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategories.insert(category)
                } else {
                    expandedCategories.remove(category)
                }
            }
        )
    }

    private func select(_ def: NutrientCatalog.Definition) {
        selectedNutrientId = def.id
        targetText = formatGoal(def.defaultGoal)
        showValidation = false
    }

    private func saveGoal() {
        guard
            let definition = selectedDefinition,
            let target = Double(targetText.trimmingCharacters(in: .whitespacesAndNewlines)),
            target > 0
        else {
            showValidation = true
            return
        }

        var targets = store.goal.targets
        targets[definition.id] = target
        store.updateGoal(targets: targets)
        dismiss()
    }

    private func expandRelevantCategories() {
        let matchingCategories = Set(filteredAvailableDefinitions.map(\.category))
        if matchingCategories.isEmpty {
            expandedCategories = []
        } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            expandedCategories = Set(NutrientCategory.allCases)
        } else {
            expandedCategories = matchingCategories
        }
    }

    private func formatGoal(_ goal: Double) -> String {
        if goal.rounded() == goal {
            return String(format: "%.0f", goal)
        }
        return String(format: "%.2f", goal)
    }
}
