import Foundation

final class NutritionStore: ObservableObject {
    @Published var goal: NutritionGoal {
        didSet { persist() }
    }
    @Published var entries: [FoodEntry] {
        didSet { persist() }
    }
    @Published var profile: UserProfile {
        didSet { persist() }
    }

    private let defaults = UserDefaults.standard
    private let goalKey = "nutrition.goal"
    private let entriesKey = "nutrition.entries"
    private let profileKey = "nutrition.profile"

    private let recommendationPool: [RecommendedFood] = [
        RecommendedFood(name: "Greek Yogurt (1 cup)", calories: 130, protein: 23, cholesterol: 15),
        RecommendedFood(name: "Chicken Breast (100g)", calories: 165, protein: 31, cholesterol: 85),
        RecommendedFood(name: "Lentils (1 cup)", calories: 230, protein: 18, cholesterol: 0),
        RecommendedFood(name: "Tofu (100g)", calories: 144, protein: 17, cholesterol: 0),
        RecommendedFood(name: "Salmon (100g)", calories: 208, protein: 20, cholesterol: 55),
        RecommendedFood(name: "Egg Whites (1 cup)", calories: 126, protein: 27, cholesterol: 0),
        RecommendedFood(name: "Cottage Cheese (1 cup)", calories: 206, protein: 28, cholesterol: 25),
        RecommendedFood(name: "Oatmeal (1 cup)", calories: 154, protein: 6, cholesterol: 0)
    ]

    init() {
        self.goal = Self.loadObject(forKey: goalKey, defaultValue: .default)
        self.entries = Self.loadObject(forKey: entriesKey, defaultValue: [])
        self.profile = Self.loadObject(forKey: profileKey, defaultValue: .default)
    }

    func addFood(name: String, calories: Double, protein: Double, cholesterol: Double) {
        let food = FoodEntry(name: name, calories: calories, protein: protein, cholesterol: cholesterol)
        entries.insert(food, at: 0)
    }

    func deleteEntries(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    func updateGoal(calories: Double, protein: Double, cholesterol: Double) {
        goal = NutritionGoal(calories: calories, protein: protein, cholesterol: cholesterol)
    }

    var todaysTotals: (calories: Double, protein: Double, cholesterol: Double) {
        totals(for: entries.filter { Calendar.current.isDateInToday($0.date) })
    }

    var historyByDay: [DailySummary] {
        let grouped = Dictionary(grouping: entries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }

        return grouped
            .map { date, dayEntries in
                let t = totals(for: dayEntries)
                let met = t.calories >= goal.calories && t.protein >= goal.protein && t.cholesterol <= goal.cholesterol
                return DailySummary(
                    id: date,
                    date: date,
                    calories: t.calories,
                    protein: t.protein,
                    cholesterol: t.cholesterol,
                    metGoal: met
                )
            }
            .sorted(by: { $0.date > $1.date })
    }

    var consistencyPercent: Double {
        let days = historyByDay
        guard !days.isEmpty else { return 0 }
        let metCount = Double(days.filter(\.metGoal).count)
        return (metCount / Double(days.count)) * 100
    }

    func recommendedFoods() -> [RecommendedFood] {
        let today = todaysTotals
        let calorieDeficit = max(goal.calories - today.calories, 0)
        let proteinDeficit = max(goal.protein - today.protein, 0)
        let cholesterolOver = max(today.cholesterol - goal.cholesterol, 0)

        let scored = recommendationPool.map { food in
            let deficitHelp =
                min(food.calories, calorieDeficit) * 0.3 +
                min(food.protein, proteinDeficit) * 3.0
            let cholesterolPenalty = cholesterolOver > 0 ? (food.cholesterol * 0.8) : 0
            let score = deficitHelp - cholesterolPenalty
            return (food, score)
        }

        return scored
            .sorted(by: { $0.1 > $1.1 })
            .prefix(5)
            .map(\.0)
    }

    func calculateBMR() -> Double {
        let base: Double
        if profile.isMale {
            base = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) + 5
        } else {
            base = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) - 161
        }
        return base * profile.activityMultiplier
    }

    private func totals(for foods: [FoodEntry]) -> (calories: Double, protein: Double, cholesterol: Double) {
        foods.reduce((0, 0, 0)) { partial, food in
            (
                partial.calories + food.calories,
                partial.protein + food.protein,
                partial.cholesterol + food.cholesterol
            )
        }
    }

    private func persist() {
        Self.saveObject(goal, forKey: goalKey, defaults: defaults)
        Self.saveObject(entries, forKey: entriesKey, defaults: defaults)
        Self.saveObject(profile, forKey: profileKey, defaults: defaults)
    }

    private static func loadObject<T: Codable>(forKey key: String, defaultValue: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key) else { return defaultValue }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
    }

    private static func saveObject<T: Codable>(_ value: T, forKey key: String, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
