import SwiftUI

@main
struct NutritionTrackerApp: App {
    @StateObject private var tracker = NutritionTrackerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tracker)
        }
    }
}

// MARK: - Models

struct NutritionGoals: Codable {
    var calories: Double = 2200
    var protein: Double = 140
    var carbs: Double = 250
    var fat: Double = 70
    var cholesterol: Double = 300
}

struct FoodEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var cholesterol: Double
    var date: Date

    init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        cholesterol: Double,
        date: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.cholesterol = cholesterol
        self.date = date
    }
}

struct RecommendedFood: Identifiable {
    let id = UUID()
    let name: String
    let reason: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let cholesterol: Double
}

enum BiologicalSex: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary = "Sedentary (little or no exercise)"
    case lightlyActive = "Lightly active (1-3 days/week)"
    case moderatelyActive = "Moderately active (3-5 days/week)"
    case veryActive = "Very active (6-7 days/week)"
    case extraActive = "Extra active (hard training)"

    var id: String { rawValue }
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }
}

// MARK: - Store

@MainActor
final class NutritionTrackerStore: ObservableObject {
    @Published var goals = NutritionGoals()
    @Published var entries: [FoodEntry] = []

    @Published var draftFoodName = ""
    @Published var draftCalories = ""
    @Published var draftProtein = ""
    @Published var draftCarbs = ""
    @Published var draftFat = ""
    @Published var draftCholesterol = ""

    private let recommendationsDB: [RecommendedFood] = [
        RecommendedFood(name: "Grilled Chicken Breast", reason: "High protein with low carbs.", calories: 165, protein: 31, carbs: 0, fat: 3.6, cholesterol: 85),
        RecommendedFood(name: "Greek Yogurt", reason: "Protein-rich snack with moderate calories.", calories: 120, protein: 17, carbs: 6, fat: 0, cholesterol: 10),
        RecommendedFood(name: "Oatmeal", reason: "Great source of healthy carbs and fiber.", calories: 150, protein: 5, carbs: 27, fat: 3, cholesterol: 0),
        RecommendedFood(name: "Salmon", reason: "Protein plus healthy fats.", calories: 206, protein: 22, carbs: 0, fat: 12, cholesterol: 63),
        RecommendedFood(name: "Avocado", reason: "Nutrient-dense healthy fat option.", calories: 160, protein: 2, carbs: 9, fat: 15, cholesterol: 0),
        RecommendedFood(name: "Egg Whites", reason: "Lean protein source with low fat.", calories: 52, protein: 11, carbs: 1, fat: 0.2, cholesterol: 0),
        RecommendedFood(name: "Brown Rice", reason: "Complex carbs for sustained energy.", calories: 216, protein: 5, carbs: 45, fat: 1.8, cholesterol: 0),
        RecommendedFood(name: "Tofu", reason: "Plant protein with moderate fat.", calories: 144, protein: 17, carbs: 3, fat: 9, cholesterol: 0)
    ]

    var todayEntries: [FoodEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return entries.filter { Calendar.current.startOfDay(for: $0.date) == today }
    }

    var todayTotals: FoodEntry {
        FoodEntry(
            name: "Total",
            calories: todayEntries.reduce(0) { $0 + $1.calories },
            protein: todayEntries.reduce(0) { $0 + $1.protein },
            carbs: todayEntries.reduce(0) { $0 + $1.carbs },
            fat: todayEntries.reduce(0) { $0 + $1.fat },
            cholesterol: todayEntries.reduce(0) { $0 + $1.cholesterol }
        )
    }

    var totalDaysLogged: Int {
        Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    var daysMetGoals: Int {
        dailySummaries().filter { isGoalMet(totals: $0.totals) }.count
    }

    var consistencyPercent: Double {
        guard totalDaysLogged > 0 else { return 0 }
        return (Double(daysMetGoals) / Double(totalDaysLogged)) * 100
    }

    func currentStreak() -> Int {
        let summaries = dailySummaries()
        let sorted = summaries.sorted { $0.date > $1.date }
        guard !sorted.isEmpty else { return 0 }

        var streak = 0
        var expectedDate = Calendar.current.startOfDay(for: Date())

        for day in sorted {
            if Calendar.current.startOfDay(for: day.date) != expectedDate { break }
            if isGoalMet(totals: day.totals) {
                streak += 1
                guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: expectedDate) else { break }
                expectedDate = previousDay
            } else {
                break
            }
        }
        return streak
    }

    func addFoodFromDraft() -> Bool {
        guard
            let calories = Double(draftCalories),
            let protein = Double(draftProtein),
            let carbs = Double(draftCarbs),
            let fat = Double(draftFat),
            let cholesterol = Double(draftCholesterol),
            !draftFoodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        let entry = FoodEntry(
            name: draftFoodName,
            calories: max(0, calories),
            protein: max(0, protein),
            carbs: max(0, carbs),
            fat: max(0, fat),
            cholesterol: max(0, cholesterol)
        )
        entries.insert(entry, at: 0)
        clearDraft()
        return true
    }

    func removeFood(at offsets: IndexSet, from source: [FoodEntry]) {
        let idsToRemove = offsets.map { source[$0].id }
        entries.removeAll { idsToRemove.contains($0.id) }
    }

    func recommendedFoods() -> [RecommendedFood] {
        let totals = todayTotals
        let deficits: [(key: String, amount: Double)] = [
            ("protein", max(0, goals.protein - totals.protein)),
            ("carbs", max(0, goals.carbs - totals.carbs)),
            ("fat", max(0, goals.fat - totals.fat)),
            ("calories", max(0, goals.calories - totals.calories))
        ]
        .sorted { $0.amount > $1.amount }

        guard let topNeed = deficits.first(where: { $0.amount > 0 }) else {
            return recommendationsDB.shuffled().prefix(3).map { $0 }
        }

        let sorted: [RecommendedFood]
        switch topNeed.key {
        case "protein":
            sorted = recommendationsDB.sorted { $0.protein > $1.protein }
        case "carbs":
            sorted = recommendationsDB.sorted { $0.carbs > $1.carbs }
        case "fat":
            sorted = recommendationsDB.sorted { $0.fat > $1.fat }
        default:
            sorted = recommendationsDB.sorted { $0.calories > $1.calories }
        }

        return Array(sorted.prefix(4))
    }

    func isGoalMet(totals: FoodEntry) -> Bool {
        totals.calories >= goals.calories &&
        totals.protein >= goals.protein &&
        totals.carbs >= goals.carbs &&
        totals.fat >= goals.fat &&
        totals.cholesterol <= goals.cholesterol
    }

    private func clearDraft() {
        draftFoodName = ""
        draftCalories = ""
        draftProtein = ""
        draftCarbs = ""
        draftFat = ""
        draftCholesterol = ""
    }

    private func dailySummaries() -> [(date: Date, totals: FoodEntry)] {
        let grouped = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.map { day, foods in
            let total = FoodEntry(
                name: "Day Total",
                calories: foods.reduce(0) { $0 + $1.calories },
                protein: foods.reduce(0) { $0 + $1.protein },
                carbs: foods.reduce(0) { $0 + $1.carbs },
                fat: foods.reduce(0) { $0 + $1.fat },
                cholesterol: foods.reduce(0) { $0 + $1.cholesterol },
                date: day
            )
            return (date: day, totals: total)
        }
    }
}

// MARK: - Views

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            RecommendationView()
                .tabItem {
                    Label("Recommend", systemImage: "lightbulb.fill")
                }
            BMRCalculatorView()
                .tabItem {
                    Label("BMR", systemImage: "heart.text.square.fill")
                }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: NutritionTrackerStore
    @State private var showAddError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Nutrition Goals (Daily)") {
                    GoalRow(title: "Calories", value: $store.goals.calories, unit: "kcal", step: 50)
                    GoalRow(title: "Protein", value: $store.goals.protein, unit: "g", step: 5)
                    GoalRow(title: "Carbs", value: $store.goals.carbs, unit: "g", step: 5)
                    GoalRow(title: "Fat", value: $store.goals.fat, unit: "g", step: 5)
                    GoalRow(title: "Cholesterol (max)", value: $store.goals.cholesterol, unit: "mg", step: 10)
                }

                Section("Add Food") {
                    TextField("Food Name", text: $store.draftFoodName)
                    HStack {
                        TextField("Calories", text: $store.draftCalories)
                            .keyboardType(.decimalPad)
                        Text("kcal")
                    }
                    HStack {
                        TextField("Protein", text: $store.draftProtein)
                            .keyboardType(.decimalPad)
                        Text("g")
                    }
                    HStack {
                        TextField("Carbs", text: $store.draftCarbs)
                            .keyboardType(.decimalPad)
                        Text("g")
                    }
                    HStack {
                        TextField("Fat", text: $store.draftFat)
                            .keyboardType(.decimalPad)
                        Text("g")
                    }
                    HStack {
                        TextField("Cholesterol", text: $store.draftCholesterol)
                            .keyboardType(.decimalPad)
                        Text("mg")
                    }

                    Button("Add Food Entry") {
                        showAddError = !store.addFoodFromDraft()
                    }
                }

                Section("Today's Nutrients") {
                    NutrientProgressRow(title: "Calories", value: store.todayTotals.calories, goal: store.goals.calories, unit: "kcal")
                    NutrientProgressRow(title: "Protein", value: store.todayTotals.protein, goal: store.goals.protein, unit: "g")
                    NutrientProgressRow(title: "Carbs", value: store.todayTotals.carbs, goal: store.goals.carbs, unit: "g")
                    NutrientProgressRow(title: "Fat", value: store.todayTotals.fat, goal: store.goals.fat, unit: "g")
                    NutrientProgressRow(title: "Cholesterol", value: store.todayTotals.cholesterol, goal: store.goals.cholesterol, unit: "mg", treatAsMaximum: true)
                }

                Section("Consistency") {
                    HStack {
                        Text("Days logged")
                        Spacer()
                        Text("\(store.totalDaysLogged)")
                    }
                    HStack {
                        Text("Days met goals")
                        Spacer()
                        Text("\(store.daysMetGoals)")
                    }
                    HStack {
                        Text("Current streak")
                        Spacer()
                        Text("\(store.currentStreak()) days")
                    }
                    HStack {
                        Text("Consistency score")
                        Spacer()
                        Text(String(format: "%.0f%%", store.consistencyPercent))
                    }
                }
            }
            .navigationTitle("Nutrition Tracker")
            .alert("Please enter valid nutrition values.", isPresented: $showAddError) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: NutritionTrackerStore
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                if store.entries.isEmpty {
                    ContentUnavailableView("No history yet", systemImage: "fork.knife", description: Text("Add foods on the Dashboard to build your log."))
                } else {
                    ForEach(store.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.name)
                                .font(.headline)
                            Text(dateFormatter.string(from: entry.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Calories \(Int(entry.calories)) | P \(Int(entry.protein))g | C \(Int(entry.carbs))g | F \(Int(entry.fat))g | Chol \(Int(entry.cholesterol))mg")
                                .font(.subheadline)
                        }
                    }
                    .onDelete { offsets in
                        store.removeFood(at: offsets, from: store.entries)
                    }
                }
            }
            .navigationTitle("Food History")
            .toolbar {
                EditButton()
            }
        }
    }
}

struct RecommendationView: View {
    @EnvironmentObject var store: NutritionTrackerStore

    var body: some View {
        NavigationStack {
            List {
                Section("Recommended Foods") {
                    ForEach(store.recommendedFoods()) { food in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(food.name)
                                .font(.headline)
                            Text(food.reason)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Calories \(Int(food.calories)) | P \(Int(food.protein))g | C \(Int(food.carbs))g | F \(Int(food.fat))g | Chol \(Int(food.cholesterol))mg")
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("How recommendations are chosen") {
                    Text("Foods are suggested based on your biggest nutrient gap for today.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Recommendations")
        }
    }
}

struct BMRCalculatorView: View {
    @State private var age = "25"
    @State private var weightKg = "70"
    @State private var heightCm = "175"
    @State private var sex: BiologicalSex = .male
    @State private var activity: ActivityLevel = .moderatelyActive

    private var bmr: Double {
        let ageVal = Double(age) ?? 0
        let weightVal = Double(weightKg) ?? 0
        let heightVal = Double(heightCm) ?? 0
        guard ageVal > 0, weightVal > 0, heightVal > 0 else { return 0 }

        switch sex {
        case .male:
            return 88.362 + (13.397 * weightVal) + (4.799 * heightVal) - (5.677 * ageVal)
        case .female:
            return 447.593 + (9.247 * weightVal) + (3.098 * heightVal) - (4.330 * ageVal)
        }
    }

    private var maintenanceCalories: Double {
        bmr * activity.multiplier
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Inputs") {
                    Picker("Sex", selection: $sex) {
                        ForEach(BiologicalSex.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                    TextField("Weight (kg)", text: $weightKg)
                        .keyboardType(.decimalPad)
                    TextField("Height (cm)", text: $heightCm)
                        .keyboardType(.decimalPad)
                    Picker("Activity level", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                Section("Results") {
                    HStack {
                        Text("Estimated BMR")
                        Spacer()
                        Text("\(Int(bmr)) kcal/day")
                    }
                    HStack {
                        Text("Estimated maintenance")
                        Spacer()
                        Text("\(Int(maintenanceCalories)) kcal/day")
                    }
                }
            }
            .navigationTitle("BMR Calculator")
        }
    }
}

// MARK: - Reusable Rows

struct GoalRow: View {
    var title: String
    @Binding var value: Double
    var unit: String
    var step: Double

    var body: some View {
        Stepper(value: $value, in: 0...10_000, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NutrientProgressRow: View {
    var title: String
    var value: Double
    var goal: Double
    var unit: String
    var treatAsMaximum: Bool = false

    private var progress: Double {
        guard goal > 0 else { return 0 }
        if treatAsMaximum {
            return min(value / goal, 1)
        }
        return min(value / goal, 1)
    }

    private var statusText: String {
        if treatAsMaximum {
            if value <= goal { return "Within max" }
            return "Over by \(Int(value - goal)) \(unit)"
        }
        if value >= goal { return "Goal met" }
        return "\(Int(goal - value)) \(unit) left"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value))/\(Int(goal)) \(unit)")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
