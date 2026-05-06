import Foundation

struct MealRecommendation: Identifiable, Hashable {
    let id: String
    let name: String
    let thumbURL: URL?
    /// The nutrients this recommendation was primarily chosen to help satisfy.
    let focusNutrientIds: [Int]
    /// Estimated nutrient totals **per 1 serving**.
    let estimatedNutrientsPerServing: [Int: Double]
    /// How many servings we assumed the recipe makes (TheMealDB does not provide this).
    let assumedServingsPerRecipe: Double
}

/// Recommends TheMealDB meals based on which nutrition goals the user is currently missing.
@MainActor
final class MealRecommendationsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var recommendations: [MealRecommendation] = []
    @Published var focusDeficits: [(nutrientId: Int, deficit: Double)] = []

    private let client = TheMealDBClient()

    func refresh(store: NutritionStore, foodDatabase: FoundationFoodDatabase) async {
        errorMessage = nil
        recommendations = []

        let deficits = Self.computeDeficits(goalTargets: store.goal.targets, todayTotals: store.todaysTotals)
        focusDeficits = deficits

        guard !deficits.isEmpty else { return }
        guard !foodDatabase.isLoading else {
            errorMessage = "USDA database is still loading. Try again in a moment."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            recommendations = try await buildRecommendations(
                deficits: deficits,
                goalTargets: store.goal.targets,
                todayTotals: store.todaysTotals,
                foodDatabase: foodDatabase
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildRecommendations(
        deficits: [(nutrientId: Int, deficit: Double)],
        goalTargets: [Int: Double],
        todayTotals: [Int: Double],
        foodDatabase: FoundationFoodDatabase
    ) async throws -> [MealRecommendation] {
        // Query TheMealDB by "proxy ingredients" that commonly contain the missing nutrient.
        let top = Array(deficits.prefix(2)).map(\.nutrientId)
        let ingredientQueries = top.flatMap { Self.proxyIngredients(forNutrientId: $0) }
        let uniqueQueries = Array(NSOrderedSet(array: ingredientQueries)).compactMap { $0 as? String }

        var mealMap: [String: TheMealDBClient.Meal] = [:]
        for q in uniqueQueries.prefix(6) {
            let meals = try await client.filterMealsByIngredient(q)
            for m in meals.prefix(20) {
                mealMap[m.idMeal] = m
            }
            if mealMap.count >= 60 { break }
        }

        // Fallback: if ingredient filters yield nothing, broaden to a simple name search.
        if mealMap.isEmpty {
            let fallbackMeals = try await client.searchMealsByName("chicken")
            for m in fallbackMeals.prefix(40) {
                mealMap[m.idMeal] = m
            }
        }

        // Score meals by how well they cover the deficits, using the same
        // USDA ingredient matching approach as the Add Food MealDB flow.
        var scored: [(MealRecommendation, Double)] = []
        scored.reserveCapacity(min(mealMap.count, 30))

        let deficitWeights = Self.deficitWeights(deficits: deficits, targets: goalTargets)
        let maxNutrients = NutrientCatalog.tracked.filter(\.goalIsMaximum).map(\.id)
        let maxOverages: [Int: Double] = Dictionary(
            uniqueKeysWithValues: maxNutrients.map { id in
                let goal = goalTargets[id] ?? 0
                let v = todayTotals[id] ?? 0
                return (id, max(v - goal, 0))
            }
        )

        for meal in mealMap.values.prefix(30) {
            let detail = try await client.lookupMealDetail(idMeal: meal.idMeal)
            let recipeTotals = MealDBNutritionEstimator.estimateNutrients(
                detail: detail,
                servings: 1.0,
                foodDatabase: foodDatabase
            )
            let assumedServings = Self.estimateServingsPerRecipe(fromRecipeTotals: recipeTotals)
            let perServing = Self.divideNutrients(recipeTotals, by: assumedServings)

            var score: Double = 0
            for (nutrientId, deficit) in deficits {
                guard deficit > 0 else { continue }
                let v = perServing[nutrientId] ?? 0
                if v <= 0 { continue }
                let coverage = min(v / deficit, 1.0)
                score += (deficitWeights[nutrientId] ?? 0) * coverage
            }

            // Small penalty if the user is already over some "maximum" goals (cholesterol/sodium/fat).
            var penalty: Double = 0
            for (id, over) in maxOverages where over > 0 {
                let v = perServing[id] ?? 0
                penalty += v * 0.0005
            }
            score -= penalty

            let focusIds = top
            let rec = MealRecommendation(
                id: meal.idMeal,
                name: meal.strMeal,
                thumbURL: meal.strMealThumb.flatMap(URL.init(string:)),
                focusNutrientIds: focusIds,
                estimatedNutrientsPerServing: perServing,
                assumedServingsPerRecipe: assumedServings
            )
            scored.append((rec, score))
        }

        return scored
            .sorted(by: { $0.1 > $1.1 })
            .prefix(8)
            .map(\.0)
    }

    /// Computes unmet "minimum" goals (ignores maximum-type goals).
    static func computeDeficits(goalTargets: [Int: Double], todayTotals: [Int: Double]) -> [(nutrientId: Int, deficit: Double)] {
        let defs = NutrientCatalog.tracked.filter { !$0.goalIsMaximum }
        var deficits: [(Int, Double)] = []
        deficits.reserveCapacity(defs.count)
        for def in defs {
            let goal = goalTargets[def.id] ?? 0
            guard goal > 0 else { continue }
            let today = todayTotals[def.id] ?? 0
            let d = max(goal - today, 0)
            if d > 0 {
                deficits.append((def.id, d))
            }
        }
        return deficits.sorted { a, b in
            let ga = goalTargets[a.0] ?? 1
            let gb = goalTargets[b.0] ?? 1
            return (a.1 / max(ga, 1e-9)) > (b.1 / max(gb, 1e-9))
        }
    }

    /// Weight nutrients by deficit percentage so the biggest misses matter most.
    static func deficitWeights(deficits: [(nutrientId: Int, deficit: Double)], targets: [Int: Double]) -> [Int: Double] {
        var weights: [Int: Double] = [:]
        var total: Double = 0
        for (id, d) in deficits {
            let g = targets[id] ?? 0
            let w = g > 0 ? (d / g) : 0
            weights[id] = w
            total += w
        }
        if total <= 0 { return weights }
        for (k, v) in weights {
            weights[k] = v / total
        }
        return weights
    }

    /// Maps a nutrient deficit to likely ingredient searches for TheMealDB.
    /// These are heuristics because TheMealDB does not provide nutrient facts directly.
    static func proxyIngredients(forNutrientId id: Int) -> [String] {
        switch id {
        case 1087: // Calcium
            return ["milk", "cheese", "yogurt", "sardines", "kale", "spinach"]
        case 1089: // Iron
            return ["spinach", "lentils", "beef", "chickpeas", "liver"]
        case 1162: // Vitamin C
            return ["orange", "lemon", "pepper", "broccoli", "strawberries"]
        case 1079: // Fiber
            return ["beans", "lentils", "chickpeas", "oats", "kale"]
        case 1003: // Protein
            return ["chicken", "tuna", "salmon", "beans", "eggs"]
        case 1092: // Potassium
            return ["banana", "potato", "spinach", "beans", "tomato"]
        case 1090: // Magnesium
            return ["spinach", "almonds", "beans", "peanut", "oats"]
        case 1095: // Zinc
            return ["beef", "pork", "chicken", "beans", "oysters"]
        default:
            // Generic balanced options.
            return ["chicken", "beans", "spinach"]
        }
    }

    static func divideNutrients(_ nutrients: [Int: Double], by divisor: Double) -> [Int: Double] {
        guard divisor > 0 else { return nutrients }
        var out: [Int: Double] = [:]
        out.reserveCapacity(nutrients.count)
        for (k, v) in nutrients {
            out[k] = v / divisor
        }
        return out
    }

    /// Heuristic: estimate how many servings a recipe yields from its total calories.
    /// We pick a typical "meal serving" calorie target and clamp to a reasonable range.
    static func estimateServingsPerRecipe(fromRecipeTotals nutrients: [Int: Double]) -> Double {
        let calories = nutrients[1008] ?? 0
        if calories <= 0 { return 4 } // fallback when we can't estimate energy

        // Typical dinner serving ~500–700 kcal. We use 600 kcal as a midpoint.
        let targetPerServing: Double = 600
        let raw = max(1, calories / targetPerServing)

        // Clamp to avoid absurd values from noisy ingredient matching.
        let clamped = min(max(raw, 1), 8)

        // Snap to halves for readability.
        return (clamped * 2).rounded() / 2
    }
}

