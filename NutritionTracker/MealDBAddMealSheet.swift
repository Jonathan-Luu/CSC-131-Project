import SwiftUI

/// Shared “Add Meal” sheet for both Lookup Meals and Recommendations.
/// Uses TheMealDB detail + USDA foundation matching to estimate nutrition.
struct MealDBAddMealSheet: View {
    let detail: TheMealDBClient.MealDetail
    let foodDatabase: FoundationFoodDatabase
    let onAdd: (_ name: String, _ nutrients: [Int: Double]) -> Void
    let onClose: () -> Void

    @EnvironmentObject private var store: NutritionStore

    @State private var servingsText = "1"
    @State private var showServingsValidation = false
    @State private var isNutritionComputing = false
    @State private var computedPreviewText: String?
    @State private var assumedServingsPerRecipe: Double?
    @State private var recipeTotals: [Int: Double]?

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    Text(detail.strMeal)
                        .font(.body)
                    if !detail.ingredientLines.isEmpty {
                        Text(detail.ingredientLines.joined(separator: "\n"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Servings") {
                    TextField("Servings", text: $servingsText)
                        .keyboardType(.decimalPad)
                    if let assumed = assumedServingsPerRecipe {
                        Text("Serving counts are estimated (TheMealDB doesn’t provide them). Assumed recipe yield: \(format(assumed)) servings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Serving counts are estimated (TheMealDB doesn’t provide them).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("We’ll estimate nutrition by matching ingredients to the USDA foundation database and scaling by servings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if showServingsValidation {
                    Section {
                        Text("Enter a valid servings amount (e.g. 1, 2, 0.5).")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                if let preview = computedPreviewText {
                    Section("Estimated nutrition (total)") {
                        Text(preview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(isNutritionComputing ? "Calculating…" : "Add to log") {
                        Task { await addToLog() }
                    }
                    .disabled(isNutritionComputing || foodDatabase.isLoading)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onClose()
                    }
                }
            }
            .onChange(of: servingsText) { _ in
                showServingsValidation = false
                Task { await recomputePreview() }
            }
            .task {
                await recomputePreview()
            }
        }
    }

    @MainActor
    private func recomputePreview() async {
        let servingsRaw = servingsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let servings = Double(servingsRaw), servings > 0 else {
            computedPreviewText = nil
            return
        }

        guard !foodDatabase.isLoading else {
            computedPreviewText = "USDA database is still loading. Please try again in a moment."
            return
        }

        isNutritionComputing = true
        defer { isNutritionComputing = false }

        if recipeTotals == nil {
            recipeTotals = MealDBNutritionEstimator.estimateNutrients(
                detail: detail,
                servings: 1.0,
                foodDatabase: foodDatabase
            )
        }
        guard let recipeTotals else { return }

        let assumed = MealRecommendationsViewModel.estimateServingsPerRecipe(fromRecipeTotals: recipeTotals)
        assumedServingsPerRecipe = assumed
        let perServing = MealRecommendationsViewModel.divideNutrients(recipeTotals, by: assumed)

        var nutrients: [Int: Double] = [:]
        nutrients.reserveCapacity(perServing.count)
        for (k, v) in perServing {
            nutrients[k] = v * servings
        }

        computedPreviewText = nutritionPreviewText(for: nutrients)
    }

    @MainActor
    private func addToLog() async {
        let servingsRaw = servingsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let servings = Double(servingsRaw), servings > 0 else {
            showServingsValidation = true
            return
        }
        showServingsValidation = false

        guard !foodDatabase.isLoading else {
            return
        }

        if recipeTotals == nil || assumedServingsPerRecipe == nil || computedPreviewText == nil {
            await recomputePreview()
        }
        guard let recipeTotals else { return }

        let assumed = assumedServingsPerRecipe ?? MealRecommendationsViewModel.estimateServingsPerRecipe(fromRecipeTotals: recipeTotals)
        let perServing = MealRecommendationsViewModel.divideNutrients(recipeTotals, by: assumed)

        var nutrients: [Int: Double] = [:]
        nutrients.reserveCapacity(perServing.count)
        for (k, v) in perServing {
            nutrients[k] = v * servings
        }

        guard nutrients[1008] != nil else { return }

        onAdd("\(detail.strMeal) (\(servingsRaw) servings)", nutrients)
        onClose()
    }

    private func format(_ v: Double) -> String {
        if v.rounded() == v { return String(format: "%.0f", v) }
        if v >= 10 { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }

    private func nutritionPreviewText(for nutrients: [Int: Double]) -> String {
        let activeGoalDefinitions = NutrientCatalog.tracked.filter {
            (store.goal.targets[$0.id] ?? 0) > 0
        }

        guard !activeGoalDefinitions.isEmpty else {
            return "No nutrition goals are currently active."
        }

        let rows = activeGoalDefinitions.compactMap { def -> String? in
            guard let value = nutrients[def.id], value.isFinite else { return nil }
            return "\(def.name): \(formattedNutrientAmount(value, unit: def.unit))"
        }

        if rows.isEmpty {
            return "Could not estimate nutrition for your active goals from the ingredient matches."
        }

        return rows.joined(separator: "\n")
    }

    private func formattedNutrientAmount(_ value: Double, unit: String) -> String {
        let number: String
        if unit == "kcal" || value >= 100 {
            number = String(format: "%.0f", value)
        } else if value >= 10 {
            number = String(format: "%.1f", value)
        } else {
            number = String(format: "%.2f", value)
        }

        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUnit.isEmpty ? number : "\(number) \(trimmedUnit)"
    }
}
