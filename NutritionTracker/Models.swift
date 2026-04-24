import Foundation

struct NutritionGoal: Codable, Equatable {
    /// Daily targets keyed by USDA nutrient id. Zero means the nutrient is ignored for goal streaks.
    var targets: [Int: Double]

    static let `default` = NutritionGoal(targets: NutrientCatalog.defaultGoals)
}

struct FoodEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    /// Amounts consumed for this entry (same units as USDA per-portion scaling).
    var nutrients: [Int: Double]
    var date: Date

    init(id: UUID = UUID(), name: String, nutrients: [Int: Double], date: Date = Date()) {
        self.id = id
        self.name = name
        self.nutrients = NutrientNormalization.canonicalizeNutrients(nutrients)
        self.date = date
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, nutrients, date
        case legacyCalories, legacyProtein, legacyCholesterol
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        date = try c.decode(Date.self, forKey: .date)
        if let n = try c.decodeIfPresent([Int: Double].self, forKey: .nutrients) {
            nutrients = NutrientNormalization.canonicalizeNutrients(n)
        } else {
            let calories = try c.decode(Double.self, forKey: .legacyCalories)
            let protein = try c.decode(Double.self, forKey: .legacyProtein)
            let cholesterol = try c.decode(Double.self, forKey: .legacyCholesterol)
            nutrients = NutrientNormalization.canonicalizeNutrients([
                NutrientNormalization.energyKcalId: calories,
                1003: protein,
                1253: cholesterol,
            ])
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(date, forKey: .date)
        try c.encode(nutrients, forKey: .nutrients)
    }
}

struct DailySummary: Identifiable {
    let id: Date
    let date: Date
    var totals: [Int: Double]
    var metGoal: Bool
}

struct UserProfile: Codable {
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var isMale: Bool
    var activityMultiplier: Double
    /// Persisted UI inputs from the BMR screen (so users see what they typed).
    /// These are redundant with metric fields but avoid rounding drift.
    var lastWeightLb: Double?
    var lastHeightFeet: Int?
    var lastHeightInches: Int?

    static let `default` = UserProfile(
        age: 25,
        weightKg: 70,
        heightCm: 175,
        isMale: true,
        activityMultiplier: 1.2,
        lastWeightLb: nil,
        lastHeightFeet: nil,
        lastHeightInches: nil
    )
}

struct RecommendedFood: Identifiable {
    let id = UUID()
    let name: String
    let nutrients: [Int: Double]
}
