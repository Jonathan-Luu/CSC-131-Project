import SwiftUI

/// Shared “Add Meal” sheet for both Lookup Meals and Recommendations.
/// Uses TheMealDB detail + USDA foundation matching to estimate nutrition.
struct MealDBAddMealSheet: View {
    let detail: TheMealDBClient.MealDetail
    let foodDatabase: FoundationFoodDatabase
    let onAdd: (_ name: String, _ nutrients: [Int: Double]) -> Void
    let onClose: () -> Void

    @State private var servingsText = "1"
    @State private var showServingsValidation = false
    @State private var isNutritionComputing = false
    @State private var computedPreviewText: String?
    @State private var assumedServingsPerRecipe: Double = 4

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
                    Text("Serving counts are estimated (TheMealDB doesn’t provide them). Assumed recipe yield: \(format(assumedServingsPerRecipe)) servings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            }
        }
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
            computedPreviewText = "USDA database is still loading. Please try again in a moment."
            return
        }

        isNutritionComputing = true
        defer { isNutritionComputing = false }

        let recipeTotals = MealDBNutritionEstimator.estimateNutrients(
            detail: detail,
            servings: 1.0,
            foodDatabase: foodDatabase
        )
        let assumedServings = MealRecommendationsViewModel.estimateServingsPerRecipe(fromRecipeTotals: recipeTotals)
        assumedServingsPerRecipe = assumedServings
        let perServing = MealRecommendationsViewModel.divideNutrients(recipeTotals, by: assumedServings)

        var nutrients: [Int: Double] = [:]
        nutrients.reserveCapacity(perServing.count)
        for (k, v) in perServing {
            nutrients[k] = v * servings
        }

        if let calories = nutrients[1008] {
            let protein = nutrients[1003] ?? 0
            let carbs = nutrients[1005] ?? 0
            let fat = nutrients[1004] ?? 0
            computedPreviewText = String(
                format: "Calories: %.0f kcal\nProtein: %.1f g\nCarbs: %.1f g\nFat: %.1f g",
                calories,
                protein,
                carbs,
                fat
            )
        } else {
            computedPreviewText = "Could not estimate calories from the ingredient matches."
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
}

