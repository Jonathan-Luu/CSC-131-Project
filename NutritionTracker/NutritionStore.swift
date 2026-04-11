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
    private static let goalKey = "nutrition.goal"
    private static let entriesKey = "nutrition.entries"
    private static let profileKey = "nutrition.profile"

    private let recommendationPool: [RecommendedFood] = [
        RecommendedFood(name: "Greek Yogurt (1 cup)", nutrients: [1008: 130, 1003: 23, 1253: 15]),
        RecommendedFood(name: "Chicken Breast (100g)", nutrients: [1008: 165, 1003: 31, 1253: 85]),
        RecommendedFood(name: "Lentils (1 cup)", nutrients: [1008: 230, 1003: 18, 1253: 0, 1079: 16]),
        RecommendedFood(name: "Tofu (100g)", nutrients: [1008: 144, 1003: 17, 1253: 0]),
        RecommendedFood(name: "Salmon (100g)", nutrients: [1008: 208, 1003: 20, 1253: 55]),
        RecommendedFood(name: "Egg Whites (1 cup)", nutrients: [1008: 126, 1003: 27, 1253: 0]),
        RecommendedFood(name: "Cottage Cheese (1 cup)", nutrients: [1008: 206, 1003: 28, 1253: 25]),
        RecommendedFood(name: "Oatmeal (1 cup)", nutrients: [1008: 154, 1003: 6, 1253: 0, 1079: 4]),
    ]

    init() {
        self.goal = Self.loadGoal()
        self.entries = Self.loadObject(forKey: Self.entriesKey, defaultValue: [])
        self.profile = Self.loadObject(forKey: Self.profileKey, defaultValue: .default)
    }

    func addFood(name: String, nutrients: [Int: Double]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let food = FoodEntry(name: trimmed, nutrients: nutrients)
        entries.insert(food, at: 0)
    }

    func deleteEntries(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    func updateGoal(targets: [Int: Double]) {
        goal = NutritionGoal(targets: targets)
    }

    var todaysTotals: [Int: Double] {
        totals(for: entries.filter { Calendar.current.isDateInToday($0.date) })
    }

    var historyByDay: [DailySummary] {
        let grouped = Dictionary(grouping: entries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }

        return grouped
            .map { date, dayEntries in
                let t = totals(for: dayEntries)
                let met = NutrientCatalog.goalsMet(totals: t, targets: goal.targets)
                return DailySummary(
                    id: date,
                    date: date,
                    totals: t,
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
        let calorieDeficit = max((goal.targets[1008] ?? 0) - (today[1008] ?? 0), 0)
        let proteinDeficit = max((goal.targets[1003] ?? 0) - (today[1003] ?? 0), 0)
        let cholesterolOver = max((today[1253] ?? 0) - (goal.targets[1253] ?? 0), 0)

        let scored = recommendationPool.map { food in
            let cals = food.nutrients[1008] ?? 0
            let prot = food.nutrients[1003] ?? 0
            let chol = food.nutrients[1253] ?? 0
            let deficitHelp =
                min(cals, calorieDeficit) * 0.3 +
                min(prot, proteinDeficit) * 3.0
            let cholesterolPenalty = cholesterolOver > 0 ? (chol * 0.8) : 0
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

    private func totals(for foods: [FoodEntry]) -> [Int: Double] {
        foods.reduce(into: [Int: Double]()) { acc, food in
            for (k, v) in food.nutrients {
                acc[k, default: 0] += v
            }
        }
    }

    private func persist() {
        Self.saveObject(goal, forKey: Self.goalKey, defaults: defaults)
        Self.saveObject(entries, forKey: Self.entriesKey, defaults: defaults)
        Self.saveObject(profile, forKey: Self.profileKey, defaults: defaults)
    }

    private static func loadGoal() -> NutritionGoal {
        guard let data = UserDefaults.standard.data(forKey: Self.goalKey) else {
            return .default
        }
        if let g = try? JSONDecoder().decode(NutritionGoal.self, from: data) {
            return g
        }
        struct LegacyGoal: Codable {
            let calories: Double
            let protein: Double
            let cholesterol: Double
        }
        if let legacy = try? JSONDecoder().decode(LegacyGoal.self, from: data) {
            var t = NutrientCatalog.defaultGoals
            t[1008] = legacy.calories
            t[1003] = legacy.protein
            t[1253] = legacy.cholesterol
            return NutritionGoal(targets: t)
        }
        return .default
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
