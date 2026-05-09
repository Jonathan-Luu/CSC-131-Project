import Foundation

/// Shared estimator used by both Lookup Meal and Recommendations.
/// Approach: match each MealDB ingredient to the USDA foundation database and sum scaled nutrients.
@MainActor
struct MealDBNutritionEstimator {
    static func estimateNutrients(
        detail: TheMealDBClient.MealDetail,
        servings: Double,
        foodDatabase: FoundationFoodDatabase
    ) -> [Int: Double] {
        var totalsPerRecipe: [Int: Double] = [:]

        for ingredient in detail.ingredients {
            let grams = estimateGrams(fromMeasure: ingredient.measure)
            let query = sanitizeIngredientQuery(ingredient.name)
            guard !query.isEmpty else { continue }

            guard let match = foodDatabase.search(query).first else { continue }

            let gramsToUse = grams ?? 100.0
            let scaled = FoundationFoodDatabase.scaledNutrients(match.nutrientsPer100g, grams: gramsToUse)
            for (k, v) in scaled {
                totalsPerRecipe[k, default: 0] += v
            }
        }

        var totals: [Int: Double] = [:]
        totals.reserveCapacity(totalsPerRecipe.count)
        for (k, v) in totalsPerRecipe {
            totals[k] = v * servings
        }

        if totals[1008] == nil, let computed = computeCaloriesFromMacros(nutrients: totals) {
            totals[1008] = computed
        }

        return totals
    }

    private static func computeCaloriesFromMacros(nutrients: [Int: Double]) -> Double? {
        let protein = nutrients[1003] ?? 0
        let carbs = nutrients[1005] ?? 0
        let fat = nutrients[1004] ?? 0

        if protein == 0, carbs == 0, fat == 0 { return nil }
        return protein * 4 + carbs * 4 + fat * 9
    }

    private static func sanitizeIngredientQuery(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let stopWords = ["fresh", "chopped", "diced", "minced", "sliced", "ground", "optional", "to taste"]
        var cleaned = lowered
        for w in stopWords {
            cleaned = cleaned.replacingOccurrences(of: w, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func estimateGrams(fromMeasure measureRaw: String) -> Double? {
        let m = measureRaw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if m.isEmpty { return nil }
        if m.contains("to taste") { return nil }

        func parseQuantity(_ s: String) -> Double? {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("/") {
                let parts = trimmed.split(separator: " ")
                var total: Double = 0
                for p in parts {
                    let fracParts = p.split(separator: "/")
                    if fracParts.count == 2,
                       let num = Double(fracParts[0]),
                       let den = Double(fracParts[1]),
                       den != 0 {
                        total += num / den
                    } else if let v = Double(p) {
                        total += v
                    }
                }
                return total > 0 ? total : nil
            }
            return Double(trimmed)
        }

        let tokens = m.split(separator: " ").map(String.init)
        guard let qty = tokens.first.flatMap(parseQuantity) else { return nil }
        let rest = tokens.dropFirst().joined(separator: " ")

        if rest.contains("kg") { return qty * 1000 }
        if rest.contains("g") { return qty }
        if rest.contains("ml") { return qty } // ~ water density
        if rest.contains("oz") { return qty * 28.3495 }
        if rest.contains("lb") { return qty * 453.592 }
        if rest.contains("cup") { return qty * 240 }
        if rest.contains("tbsp") || rest.contains("tablespoon") { return qty * 15 }
        if rest.contains("tsp") || rest.contains("teaspoon") { return qty * 5 }
        if rest.contains("clove") { return qty * 3 }
        if rest.contains("slice") { return qty * 25 }

        if rest.isEmpty { return qty * 100 }
        return nil
    }
}
