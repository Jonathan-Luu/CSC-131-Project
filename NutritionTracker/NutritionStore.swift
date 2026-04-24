import Foundation
import FirebaseFirestore

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

    private var uid: String?
    private var firestoreListener: ListenerRegistration?
    private var isApplyingRemote = false
    private var pendingCloudWrite: DispatchWorkItem?

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
        self.goal = Self.loadGoal(forKey: Self.goalKey)
        self.entries = Self.loadObject(forKey: Self.entriesKey, defaultValue: [])
        self.profile = Self.loadObject(forKey: Self.profileKey, defaultValue: .default)
    }

    /// Call when Firebase auth user changes so nutrition data is stored per account
    /// and synced across devices.
    func setUser(uid: String?) {
        if self.uid == uid { return }

        pendingCloudWrite?.cancel()
        pendingCloudWrite = nil

        firestoreListener?.remove()
        firestoreListener = nil

        self.uid = uid

        // Signed-out state should not show the previous user's data.
        guard let uid, !uid.isEmpty else {
            isApplyingRemote = true
            self.goal = .default
            self.entries = []
            self.profile = .default
            isApplyingRemote = false
            return
        }

        // Load local cache for this account. If this device still has legacy (pre-account)
        // data and this account has no scoped cache yet, migrate the legacy data once.
        let goalKey = scopedKey(Self.goalKey, uid: uid)
        let entriesKey = scopedKey(Self.entriesKey, uid: uid)
        let profileKey = scopedKey(Self.profileKey, uid: uid)

        let hasScoped =
            defaults.data(forKey: goalKey) != nil ||
            defaults.data(forKey: entriesKey) != nil ||
            defaults.data(forKey: profileKey) != nil

        let hasLegacy =
            defaults.data(forKey: Self.goalKey) != nil ||
            defaults.data(forKey: Self.entriesKey) != nil ||
            defaults.data(forKey: Self.profileKey) != nil

        isApplyingRemote = true
        if !hasScoped, hasLegacy {
            // One-time migration: move legacy global data into this user's scoped keys,
            // then delete legacy keys so it never leaks across accounts again.
            self.goal = Self.loadGoal(forKey: Self.goalKey)
            self.entries = Self.loadObject(forKey: Self.entriesKey, defaultValue: [])
            self.profile = Self.loadObject(forKey: Self.profileKey, defaultValue: .default)

            Self.saveObject(self.goal, forKey: goalKey, defaults: defaults)
            Self.saveObject(self.entries, forKey: entriesKey, defaults: defaults)
            Self.saveObject(self.profile, forKey: profileKey, defaults: defaults)

            defaults.removeObject(forKey: Self.goalKey)
            defaults.removeObject(forKey: Self.entriesKey)
            defaults.removeObject(forKey: Self.profileKey)
        } else {
            self.goal = Self.loadGoal(forKey: goalKey)
            self.entries = Self.loadObject(forKey: entriesKey, defaultValue: [])
            self.profile = Self.loadObject(forKey: profileKey, defaultValue: .default)
        }
        isApplyingRemote = false

        startFirestoreListener(uid: uid)
        // Kick an initial write so first-time sign-ins push local data to the cloud.
        scheduleCloudWrite()
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
        return max(0, base * profile.activityMultiplier)
    }

    private func totals(for foods: [FoodEntry]) -> [Int: Double] {
        foods.reduce(into: [Int: Double]()) { acc, food in
            for (k, v) in food.nutrients {
                let contribution: Double
                if k == NutrientNormalization.carbohydrateByDifferenceId {
                    contribution = max(0, v)
                } else {
                    contribution = v
                }
                acc[k, default: 0] += contribution
            }
        }
    }

    private func persist() {
        let goalKey = scopedKey(Self.goalKey, uid: uid)
        let entriesKey = scopedKey(Self.entriesKey, uid: uid)
        let profileKey = scopedKey(Self.profileKey, uid: uid)

        Self.saveObject(goal, forKey: goalKey, defaults: defaults)
        Self.saveObject(entries, forKey: entriesKey, defaults: defaults)
        Self.saveObject(profile, forKey: profileKey, defaults: defaults)

        if !isApplyingRemote {
            scheduleCloudWrite()
        }
    }

    private static func loadGoal(forKey key: String, legacyKey: String? = nil) -> NutritionGoal {
        if let data = UserDefaults.standard.data(forKey: key),
           let g = try? JSONDecoder().decode(NutritionGoal.self, from: data) {
            return g
        }

        if let legacyKey,
           let data = UserDefaults.standard.data(forKey: legacyKey) {
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
        }

        guard let data = UserDefaults.standard.data(forKey: key) else {
            return .default
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

    private static func loadObject<T: Codable>(forKey key: String, legacyKey: String? = nil, defaultValue: T) -> T {
        if let data = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode(T.self, from: data) {
            return v
        }
        if let legacyKey,
           let data = UserDefaults.standard.data(forKey: legacyKey),
           let v = try? JSONDecoder().decode(T.self, from: data) {
            return v
        }
        return defaultValue
    }

    private static func saveObject<T: Codable>(_ value: T, forKey key: String, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func scopedKey(_ base: String, uid: String?) -> String {
        guard let uid, !uid.isEmpty else { return base }
        return "\(base).\(uid)"
    }

    private func startFirestoreListener(uid: String) {
        let doc = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("nutrition")
            .document("state")

        firestoreListener = doc.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            guard error == nil else { return }
            guard let data = snapshot?.data(), !data.isEmpty else { return }

            self.isApplyingRemote = true
            if let goalMap = data["goal"] as? [String: Any],
               let targetsMap = goalMap["targets"] as? [String: Any] {
                var targets: [Int: Double] = [:]
                for (k, vAny) in targetsMap {
                    guard let id = Int(k) else { continue }
                    if let v = vAny as? Double {
                        targets[id] = v
                    } else if let v = vAny as? Int {
                        targets[id] = Double(v)
                    } else if let v = vAny as? NSNumber {
                        targets[id] = v.doubleValue
                    }
                }
                self.goal = NutritionGoal(targets: targets)
            }

            if let entriesAny = data["entries"] as? [[String: Any]] {
                var decoded: [FoodEntry] = []
                decoded.reserveCapacity(entriesAny.count)
                for entryMap in entriesAny {
                    guard
                        let idString = entryMap["id"] as? String,
                        let id = UUID(uuidString: idString),
                        let name = entryMap["name"] as? String
                    else { continue }

                    let date: Date
                    if let ts = entryMap["date"] as? Timestamp {
                        date = ts.dateValue()
                    } else if let d = entryMap["date"] as? Date {
                        date = d
                    } else {
                        date = Date()
                    }

                    var nutrients: [Int: Double] = [:]
                    if let nutrientMap = entryMap["nutrients"] as? [String: Any] {
                        for (k, vAny) in nutrientMap {
                            guard let nid = Int(k) else { continue }
                            if let v = vAny as? Double {
                                nutrients[nid] = v
                            } else if let v = vAny as? Int {
                                nutrients[nid] = Double(v)
                            } else if let v = vAny as? NSNumber {
                                nutrients[nid] = v.doubleValue
                            }
                        }
                    }

                    decoded.append(FoodEntry(id: id, name: name, nutrients: nutrients, date: date))
                }
                // Keep same ordering semantics as local (most recent first) if cloud isn't ordered.
                decoded.sort(by: { $0.date > $1.date })
                self.entries = decoded
            }

            if let profileMap = data["profile"] as? [String: Any] {
                let age = (profileMap["age"] as? NSNumber)?.intValue ?? (profileMap["age"] as? Int) ?? UserProfile.default.age
                let weightKg = (profileMap["weightKg"] as? NSNumber)?.doubleValue ?? (profileMap["weightKg"] as? Double) ?? UserProfile.default.weightKg
                let heightCm = (profileMap["heightCm"] as? NSNumber)?.doubleValue ?? (profileMap["heightCm"] as? Double) ?? UserProfile.default.heightCm
                let isMale = (profileMap["isMale"] as? Bool) ?? UserProfile.default.isMale
                let activityMultiplier = (profileMap["activityMultiplier"] as? NSNumber)?.doubleValue
                    ?? (profileMap["activityMultiplier"] as? Double)
                    ?? UserProfile.default.activityMultiplier
                self.profile = UserProfile(
                    age: age,
                    weightKg: weightKg,
                    heightCm: heightCm,
                    isMale: isMale,
                    activityMultiplier: activityMultiplier
                )
            }
            self.isApplyingRemote = false
        }
    }

    private func scheduleCloudWrite() {
        guard let uid, !uid.isEmpty else { return }

        pendingCloudWrite?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.writeToCloud()
        }
        pendingCloudWrite = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func writeToCloud() {
        guard let uid, !uid.isEmpty else { return }
        if isApplyingRemote { return }

        let doc = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("nutrition")
            .document("state")

        doc.setData(
            [
                "goal": [
                    "targets": Dictionary(uniqueKeysWithValues: goal.targets.map { (String($0.key), $0.value) }),
                ],
                "entries": entries.map { e in
                    [
                        "id": e.id.uuidString,
                        "name": e.name,
                        "date": Timestamp(date: e.date),
                        "nutrients": Dictionary(uniqueKeysWithValues: e.nutrients.map { (String($0.key), $0.value) }),
                    ] as [String: Any]
                },
                "profile": [
                    "age": profile.age,
                    "weightKg": profile.weightKg,
                    "heightCm": profile.heightCm,
                    "isMale": profile.isMale,
                    "activityMultiplier": profile.activityMultiplier,
                ],
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            merge: true
        )
    }
}
