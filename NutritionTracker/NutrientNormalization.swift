import Foundation

/// Maps USDA FoodData Central nutrient variants into the canonical IDs used by `NutrientCatalog`.
///
/// Foundation foods often omit nutrient **1008** (Energy, kcal) and instead publish:
/// - **2048** — Energy (Atwater Specific Factors), kcal
/// - **2047** — Energy (Atwater General Factors), kcal
/// - **1062** — Energy, kJ (convert with ÷ 4.184)
///
/// The app tracks calories only as **1008**. Without normalization, foods like raw chicken breast
/// can show protein (1003) but **0 kcal** because energy lives only under 2047/2048.
enum NutrientNormalization {
    /// Canonical “Calories” id in `NutrientCatalog` (Energy, kcal).
    static let energyKcalId = 1008

    private static let energyKilojoulesId = 1062
    private static let energyAtwaterGeneralId = 2047
    private static let energyAtwaterSpecificId = 2048

    /// Aliases that must not be summed with `energyKcalId` or energy is double-counted.
    private static let energyAliasIds: Set<Int> = [
        energyKilojoulesId,
        energyAtwaterGeneralId,
        energyAtwaterSpecificId,
    ]

    /// kJ → kcal (USDA / FDC convention).
    private static let kilojoulesPerKilocalorie = 4.184

    /// Merge energy variants into **1008** and drop alias keys so daily totals stay correct.
    static func canonicalizeNutrients(_ raw: [Int: Double]) -> [Int: Double] {
        var m = raw

        let primary = m[energyKcalId]
        let needsFill = primary == nil || primary == 0

        if needsFill {
            let kcal: Double?
            if let s = m[energyAtwaterSpecificId], s > 0 {
                kcal = s
            } else if let g = m[energyAtwaterGeneralId], g > 0 {
                kcal = g
            } else if let kj = m[energyKilojoulesId], kj > 0 {
                kcal = kj / kilojoulesPerKilocalorie
            } else {
                kcal = nil
            }
            if let kcal {
                m[energyKcalId] = kcal
            }
        }

        for id in energyAliasIds {
            m.removeValue(forKey: id)
        }
        return m
    }
}
