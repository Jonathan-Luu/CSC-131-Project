import Foundation
import FirebaseFirestore
import FirebaseAuth

final class NutritionStore: ObservableObject {
    @Published var goal: NutritionGoal {
        didSet { persist(.goal) }
    }
    @Published var entries: [FoodEntry] {
        didSet { persist(.entries) }
    }
    @Published var profile: UserProfile {
        didSet { persist(.profile) }
    }

    private let defaults = UserDefaults.standard
    private static let goalKey = "nutrition.goal"
    private static let entriesKey = "nutrition.entries"
    private static let profileKey = "nutrition.profile"

    private enum PersistenceScope {
        case goal
        case entries
        case profile
    }

    private var uid: String?
    private var firestoreListener: ListenerRegistration?
    private var isApplyingRemote = false
    private var pendingCloudWrite: DispatchWorkItem?
    private var hasLoadedRemoteOnce = false
    private var hasScheduledRemoteLoadFallback = false
    private var isCloudSyncBlocked = false

    init() {
        self.goal = .default
        self.entries = []
        self.profile = .default

        // If the app starts already authenticated, immediately scope to that user.
        setUser(uid: Auth.auth().currentUser?.uid)
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
        hasLoadedRemoteOnce = false
        hasScheduledRemoteLoadFallback = false
        isCloudSyncBlocked = false

        // Signed-out state should not show the previous user's data.
        guard let uid, !uid.isEmpty else {
            isApplyingRemote = true
            self.goal = .default
            self.entries = []
            self.profile = .default
            isApplyingRemote = false
            return
        }

        let goalKey = scopedKey(Self.goalKey, uid: uid)
        let entriesKey = scopedKey(Self.entriesKey, uid: uid)
        let profileKey = scopedKey(Self.profileKey, uid: uid)

        isApplyingRemote = true
        self.goal = Self.loadGoal(forKey: goalKey)
        self.entries = Self.loadObject(forKey: entriesKey, defaultValue: [])
        self.profile = Self.loadObject(forKey: profileKey, defaultValue: .default)
        isApplyingRemote = false

        startFirestoreListener(uid: uid)
        // Note: we intentionally do NOT write immediately on sign-in.
        // We wait until we have either loaded the cloud state or confirmed it doesn't exist,
        // so we don't accidentally overwrite existing cloud history with an empty local cache.
    }

    func addFood(name: String, nutrients: [Int: Double]) {
        ensureUserIsCurrent()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let food = FoodEntry(name: trimmed, nutrients: nutrients)
        entries.insert(food, at: 0)
    }

    func deleteEntries(at offsets: IndexSet) {
        ensureUserIsCurrent()
        entries.remove(atOffsets: offsets)
    }

    func updateGoal(targets: [Int: Double]) {
        ensureUserIsCurrent()
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

    private func persist(_ scope: PersistenceScope) {
        // When we're switching users or applying cloud data, `goal/entries/profile` are
        // temporarily set programmatically. We must not persist those intermediate values
        // or we can overwrite a user's cached data with defaults/empties.
        if isApplyingRemote { return }

        ensureUserIsCurrent()
        let goalKey = scopedKey(Self.goalKey, uid: uid)
        let entriesKey = scopedKey(Self.entriesKey, uid: uid)
        let profileKey = scopedKey(Self.profileKey, uid: uid)

        switch scope {
        case .goal:
            Self.saveObject(goal, forKey: goalKey, defaults: defaults)
        case .entries:
            Self.saveObject(entries, forKey: entriesKey, defaults: defaults)
        case .profile:
            Self.saveObject(profile, forKey: profileKey, defaults: defaults)
        }

        if !isApplyingRemote, hasLoadedRemoteOnce, !isCloudSyncBlocked {
            scheduleCloudWrite()
        }
    }

    private static func loadGoal(forKey key: String) -> NutritionGoal {
        if let data = UserDefaults.standard.data(forKey: key),
           let g = try? JSONDecoder().decode(NutritionGoal.self, from: data) {
            return g
        }
        return .default
    }

    private static func loadObject<T: Codable>(forKey key: String, defaultValue: T) -> T {
        if let data = UserDefaults.standard.data(forKey: key),
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
            if let error {
                self.handleFirestoreListenerError(error)
                return
            }
            guard let snapshot else { return }

            // If no cloud doc exists yet, mark as loaded and (if we have local data) push it up once.
            if !snapshot.exists {
                self.hasLoadedRemoteOnce = true
                if !self.entries.isEmpty || self.goal.targets != NutritionGoal.default.targets || self.profileIsNonDefault {
                    self.scheduleCloudWrite()
                }
                return
            }

            guard let data = snapshot.data(), !data.isEmpty else {
                self.hasLoadedRemoteOnce = true
                return
            }

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

            if let entriesRaw = data["entries"] as? [Any] {
                var decoded: [FoodEntry] = []
                decoded.reserveCapacity(entriesRaw.count)
                for raw in entriesRaw {
                    guard let entryMap = raw as? [String: Any] else { continue }
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
                let lastWeightLb = (profileMap["lastWeightLb"] as? NSNumber)?.doubleValue ?? (profileMap["lastWeightLb"] as? Double)
                let lastHeightFeet = (profileMap["lastHeightFeet"] as? NSNumber)?.intValue ?? (profileMap["lastHeightFeet"] as? Int)
                let lastHeightInches = (profileMap["lastHeightInches"] as? NSNumber)?.intValue ?? (profileMap["lastHeightInches"] as? Int)
                self.profile = UserProfile(
                    age: age,
                    weightKg: weightKg,
                    heightCm: heightCm,
                    isMale: isMale,
                    activityMultiplier: activityMultiplier,
                    lastWeightLb: lastWeightLb,
                    lastHeightFeet: lastHeightFeet,
                    lastHeightInches: lastHeightInches
                )
            }
            self.isApplyingRemote = false
            self.hasLoadedRemoteOnce = true
        }

        // Fallback: if for any reason the listener doesn't fire (config/network),
        // allow writes after a short delay so user-entered data still persists to the account.
        if !hasScheduledRemoteLoadFallback {
            hasScheduledRemoteLoadFallback = true
            let expectedUid = uid
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self else { return }
                guard self.uid == expectedUid else { return }
                guard !self.isCloudSyncBlocked else { return }
                if !self.hasLoadedRemoteOnce {
                    self.hasLoadedRemoteOnce = true
                    if !self.entries.isEmpty || self.goal.targets != NutritionGoal.default.targets || self.profileIsNonDefault {
                        self.scheduleCloudWrite()
                    }
                }
            }
        }
    }

    private func scheduleCloudWrite() {
        guard let uid, !uid.isEmpty else { return }
        guard !isCloudSyncBlocked else { return }

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
        if isCloudSyncBlocked { return }

        let doc = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("nutrition")
            .document("state")

        func firestoreValue<T>(_ value: T?) -> Any {
            value.map { $0 as Any } ?? NSNull()
        }

        let profilePayload: [String: Any] = [
            "age": profile.age,
            "weightKg": profile.weightKg,
            "heightCm": profile.heightCm,
            "isMale": profile.isMale,
            "activityMultiplier": profile.activityMultiplier,
            "lastWeightLb": firestoreValue(profile.lastWeightLb),
            "lastHeightFeet": firestoreValue(profile.lastHeightFeet),
            "lastHeightInches": firestoreValue(profile.lastHeightInches),
        ]

        let payload: [String: Any] = [
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
            "profile": profilePayload,
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        let expectedUid = uid
        doc.setData(payload, merge: true) { [weak self] error in
            guard let self, self.uid == expectedUid, let error else { return }
            print("Firestore nutrition sync write failed: \(error.localizedDescription)")
            if self.isFirestoreAuthError(error) {
                self.disableCloudSyncForCurrentUser()
            }
        }
    }

    private func handleFirestoreListenerError(_ error: Error) {
        print("Firestore nutrition sync listener failed: \(error.localizedDescription)")
        if isFirestoreAuthError(error) {
            disableCloudSyncForCurrentUser()
        }
    }

    private func disableCloudSyncForCurrentUser() {
        isCloudSyncBlocked = true
        hasLoadedRemoteOnce = false
        pendingCloudWrite?.cancel()
        pendingCloudWrite = nil
        firestoreListener?.remove()
        firestoreListener = nil
    }

    private func isFirestoreAuthError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain,
              let code = FirestoreErrorCode.Code(rawValue: nsError.code) else {
            return false
        }
        return code == .permissionDenied || code == .unauthenticated
    }

    private var profileIsNonDefault: Bool {
        let d = UserProfile.default
        return profile.age != d.age
            || profile.weightKg != d.weightKg
            || profile.heightCm != d.heightCm
            || profile.isMale != d.isMale
            || profile.activityMultiplier != d.activityMultiplier
            || profile.lastWeightLb != d.lastWeightLb
            || profile.lastHeightFeet != d.lastHeightFeet
            || profile.lastHeightInches != d.lastHeightInches
    }

    private func ensureUserIsCurrent() {
        let actualUid = Auth.auth().currentUser?.uid
        if actualUid != uid {
            setUser(uid: actualUid)
        }
    }
}
