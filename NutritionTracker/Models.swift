import Foundation

struct NutritionGoal: Codable {
    var calories: Double
    var protein: Double
    var cholesterol: Double

    static let `default` = NutritionGoal(calories: 2000, protein: 120, cholesterol: 300)
}

struct FoodEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var cholesterol: Double
    var date: Date

    init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        protein: Double,
        cholesterol: Double,
        date: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.cholesterol = cholesterol
        self.date = date
    }
}

struct DailySummary: Identifiable {
    let id: Date
    let date: Date
    var calories: Double
    var protein: Double
    var cholesterol: Double
    var metGoal: Bool
}

struct UserProfile: Codable {
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var isMale: Bool
    var activityMultiplier: Double

    static let `default` = UserProfile(
        age: 25,
        weightKg: 70,
        heightCm: 175,
        isMale: true,
        activityMultiplier: 1.2
    )
}

struct RecommendedFood: Identifiable {
    let id = UUID()
    let name: String
    let calories: Double
    let protein: Double
    let cholesterol: Double
}
