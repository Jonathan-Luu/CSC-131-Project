import SwiftUI

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NutritionStore

    @State private var searchText = ""
    @State private var expandedCategories: Set<NutrientCategory> = []
    @State private var selectedNutrientId: Int?
    @State private var targetText = ""
    @State private var errorMessage: String?
    @State private var showingGoalPrompt = false

    var body: some View {
        Form {
            nutrientSelectionSection
        }
        .navigationTitle("Add Goal")
        .searchable(text: $searchText, prompt: "Search nutrients")
        .onChange(of: searchText) { _ in
            expandRelevantCategories()
        }
        .onChange(of: targetText) { _ in
            errorMessage = nil
        }
        .alert("Set Daily Goal", isPresented: $showingGoalPrompt) {
            TextField("Target amount", text: $targetText)
                .keyboardType(.decimalPad)

            Button("Cancel", role: .cancel) {
                errorMessage = nil
            }

            Button("Save") {
                saveGoal()
            }
        } message: {
            if let definition = selectedDefinition {
                Text(alertMessage(for: definition))
            } else {
                Text("Enter a target amount for this nutrient.")
            }
        }
    }

    private var nutrientSelectionSection: some View {
        Section(header: Text("Choose a nutrient")) {
            if filteredAvailableDefinitions.isEmpty {
                Text(emptyStateMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(NutrientCategory.allCases, id: \.self) { category in
                    categoryDisclosureGroup(for: category)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryDisclosureGroup(for category: NutrientCategory) -> some View {
        let defs = filteredDefinitions(in: category)
        if !defs.isEmpty {
            DisclosureGroup(
                isExpanded: expansionBinding(for: category)
            ) {
                ForEach(defs) { def in
                    nutrientRow(for: def)
                }
            } label: {
                Text(category.rawValue)
                    .font(.headline)
            }
        }
    }

    private func nutrientRow(for def: NutrientCatalog.Definition) -> some View {
        Button {
            select(def)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(def.name) (\(def.unit))")
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var selectedDefinition: NutrientCatalog.Definition? {
        guard let selectedNutrientId = selectedNutrientId else { return nil }
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
        errorMessage = nil
        showingGoalPrompt = true
    }

    private func saveGoal() {
        guard
            let definition = selectedDefinition,
            let target = Double(targetText.trimmingCharacters(in: .whitespacesAndNewlines)),
            target > 0
        else {
            errorMessage = "Enter a valid target amount greater than zero"
            DispatchQueue.main.async {
                showingGoalPrompt = true
            }
            return
        }

        var targets = store.goal.targets
        targets[definition.id] = target
        store.updateGoal(targets: targets)
        showingGoalPrompt = false
        errorMessage = nil
        dismiss()
    }

    private func alertMessage(for definition: NutrientCatalog.Definition) -> String {
        let prompt = "Enter a target amount for \(definition.name) (\(definition.unit))"
        guard let errorMessage else { return prompt }
        return "\(errorMessage)\n\n\(prompt)"
    }

    private func expandRelevantCategories() {
        let matchingCategories = Set(filteredAvailableDefinitions.map(\.category))
        if matchingCategories.isEmpty {
            expandedCategories = []
        } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            expandedCategories = []
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
