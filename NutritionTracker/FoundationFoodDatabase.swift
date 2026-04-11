import Foundation
import Combine

// MARK: - USDA JSON (FoodData Central foundation_food_json)

private struct FoodDataCentralFile: Decodable {
    let foundationFoods: [FDCFood]

    enum CodingKeys: String, CodingKey {
        case foundationFoods = "FoundationFoods"
    }
}

private struct FDCFood: Decodable {
    let description: String
    let foodNutrients: [FDCFoodNutrient]
}

private struct FDCFoodNutrient: Decodable {
    let nutrient: FDCNutrient
    let amount: Double?
    /// Some FDC rows publish only `median` (e.g. lab aggregates) instead of `amount`.
    let median: Double?

    var resolvedAmount: Double? {
        if let amount { return amount }
        return median
    }
}

private struct FDCNutrient: Decodable {
    let id: Int
    let name: String
    let unitName: String
}

/// One foundation food with nutrient amounts **per 100 g** edible portion (USDA standard).
struct FoundationFoodItem: Identifiable, Hashable {
    let id: Int
    let description: String
    /// USDA nutrient id → amount per 100 g
    let nutrientsPer100g: [Int: Double]
}

@MainActor
final class FoundationFoodDatabase: ObservableObject {
    @Published private(set) var items: [FoundationFoodItem] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?

    private static let bundleName = "FoodData_Central_foundation_food_json_2025-12-18"

    init() {
        Task { await load() }
    }

    func search(_ query: String) -> [FoundationFoodItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.description.localizedCaseInsensitiveContains(q) }
    }

    /// Scale per-100 g values to the given gram amount.
    static func scaledNutrients(_ per100g: [Int: Double], grams: Double) -> [Int: Double] {
        let factor = grams / 100.0
        var out: [Int: Double] = [:]
        for (k, v) in per100g {
            out[k] = v * factor
        }
        return out
    }

    private func load() async {
        isLoading = true
        loadError = nil
        guard let url = Bundle.main.url(forResource: Self.bundleName, withExtension: "json") else {
            loadError = "Food database file missing from app bundle."
            isLoading = false
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(FoodDataCentralFile.self, from: data)
            items = decoded.foundationFoods.enumerated().map { index, food in
                var dict: [Int: Double] = [:]
                for fn in food.foodNutrients {
                    if let amt = fn.resolvedAmount {
                        dict[fn.nutrient.id] = amt
                    }
                }
                let canonical = NutrientNormalization.canonicalizeNutrients(dict)
                return FoundationFoodItem(id: index, description: food.description, nutrientsPer100g: canonical)
            }
            isLoading = false
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }
}
