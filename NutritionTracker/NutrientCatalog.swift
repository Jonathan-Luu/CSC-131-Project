import Foundation

enum NutrientCategory: String, CaseIterable {
    case macros = "Energy & Macros"
    case fiber = "Fiber"
    case vitamins = "Vitamins"
    case minerals = "Minerals"
}

/// USDA FoodData Central nutrient IDs used for tracking (amounts per serving as stored on `FoodEntry`).
struct NutrientCatalog {
    struct Definition: Identifiable, Hashable {
        let id: Int
        let name: String
        let unit: String
        let category: NutrientCategory
        /// Default daily target; `0` means “not used in goal streak by default.”
        let defaultGoal: Double
        /// If true, meeting the goal means staying at or below the target (e.g. cholesterol, sodium).
        let goalIsMaximum: Bool
    }

    /// Ordered nutrients shown in dashboards and goal editors.
    static let tracked: [Definition] = [
        // Macros
        Definition(id: 1008, name: "Calories", unit: "kcal", category: .macros, defaultGoal: 2000, goalIsMaximum: false),
        Definition(id: 1003, name: "Protein", unit: "g", category: .macros, defaultGoal: 120, goalIsMaximum: false),
        Definition(id: 1005, name: "Carbohydrate", unit: "g", category: .macros, defaultGoal: 275, goalIsMaximum: false),
        Definition(id: 1004, name: "Total fat", unit: "g", category: .macros, defaultGoal: 78, goalIsMaximum: true),
        Definition(id: 1253, name: "Cholesterol", unit: "mg", category: .macros, defaultGoal: 300, goalIsMaximum: true),
        Definition(id: 1093, name: "Sodium", unit: "mg", category: .macros, defaultGoal: 2300, goalIsMaximum: true),
        // Fiber
        Definition(id: 1079, name: "Fiber, total dietary", unit: "g", category: .fiber, defaultGoal: 28, goalIsMaximum: false),
        // Vitamins
        Definition(id: 1106, name: "Vitamin A (RAE)", unit: "µg", category: .vitamins, defaultGoal: 900, goalIsMaximum: false),
        Definition(id: 1162, name: "Vitamin C", unit: "mg", category: .vitamins, defaultGoal: 90, goalIsMaximum: false),
        Definition(id: 1114, name: "Vitamin D (D2 + D3)", unit: "µg", category: .vitamins, defaultGoal: 20, goalIsMaximum: false),
        Definition(id: 1110, name: "Vitamin D (IU)", unit: "IU", category: .vitamins, defaultGoal: 800, goalIsMaximum: false),
        Definition(id: 1109, name: "Vitamin E (alpha-tocopherol)", unit: "mg", category: .vitamins, defaultGoal: 15, goalIsMaximum: false),
        Definition(id: 1185, name: "Vitamin K", unit: "µg", category: .vitamins, defaultGoal: 120, goalIsMaximum: false),
        Definition(id: 1167, name: "Thiamin", unit: "mg", category: .vitamins, defaultGoal: 1.2, goalIsMaximum: false),
        Definition(id: 1166, name: "Riboflavin", unit: "mg", category: .vitamins, defaultGoal: 1.3, goalIsMaximum: false),
        Definition(id: 1165, name: "Niacin", unit: "mg", category: .vitamins, defaultGoal: 16, goalIsMaximum: false),
        Definition(id: 1168, name: "Pantothenic acid", unit: "mg", category: .vitamins, defaultGoal: 5, goalIsMaximum: false),
        Definition(id: 1175, name: "Vitamin B-6", unit: "mg", category: .vitamins, defaultGoal: 1.7, goalIsMaximum: false),
        Definition(id: 1176, name: "Vitamin B-12", unit: "µg", category: .vitamins, defaultGoal: 2.4, goalIsMaximum: false),
        Definition(id: 1177, name: "Folate, total", unit: "µg", category: .vitamins, defaultGoal: 400, goalIsMaximum: false),
        Definition(id: 1180, name: "Choline, total", unit: "mg", category: .vitamins, defaultGoal: 550, goalIsMaximum: false),
        // Minerals
        Definition(id: 1087, name: "Calcium", unit: "mg", category: .minerals, defaultGoal: 1300, goalIsMaximum: false),
        Definition(id: 1089, name: "Iron", unit: "mg", category: .minerals, defaultGoal: 18, goalIsMaximum: false),
        Definition(id: 1090, name: "Magnesium", unit: "mg", category: .minerals, defaultGoal: 420, goalIsMaximum: false),
        Definition(id: 1091, name: "Phosphorus", unit: "mg", category: .minerals, defaultGoal: 1250, goalIsMaximum: false),
        Definition(id: 1092, name: "Potassium", unit: "mg", category: .minerals, defaultGoal: 4700, goalIsMaximum: false),
        Definition(id: 1095, name: "Zinc", unit: "mg", category: .minerals, defaultGoal: 11, goalIsMaximum: false),
        Definition(id: 1098, name: "Copper", unit: "mg", category: .minerals, defaultGoal: 0.9, goalIsMaximum: false),
        Definition(id: 1101, name: "Manganese", unit: "mg", category: .minerals, defaultGoal: 2.3, goalIsMaximum: false),
        Definition(id: 1103, name: "Selenium", unit: "µg", category: .minerals, defaultGoal: 55, goalIsMaximum: false),
    ]

    static func definition(for id: Int) -> Definition? {
        tracked.first { $0.id == id }
    }

    /// Defaults for new installs: only a few macronutrient-style targets are active (others are 0 = ignored for streaks).
    static var defaultGoals: [Int: Double] {
        var d = [Int: Double]()
        for def in tracked {
            d[def.id] = 0
        }
        d[1008] = 2000
        d[1003] = 120
        d[1253] = 300
        d[1093] = 2300
        d[1079] = 28
        return d
    }

    static func goalsMet(totals: [Int: Double], targets: [Int: Double]) -> Bool {
        for def in tracked {
            let g = targets[def.id] ?? 0
            guard g > 0 else { continue }
            let v = totals[def.id] ?? 0
            if def.goalIsMaximum {
                if v > g { return false }
            } else {
                if v < g { return false }
            }
        }
        return true
    }
}
