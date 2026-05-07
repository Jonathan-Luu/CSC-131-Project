import SwiftUI

struct AddFoodView: View {
    @EnvironmentObject private var store: NutritionStore
    @EnvironmentObject private var foodDatabase: FoundationFoodDatabase

    private enum Mode: String, CaseIterable {
        static let allCases: [Mode] = [.manual, .mealdb]

        case manual = "Manual"
        case mealdb = "Lookup Meals"
    }

    @State private var mode: Mode = .manual
    @State private var name = ""
    @State private var manualFields: [Int: String] = [:]
    @State private var showValidation = false

    // MARK: - TheMealDB
    private let mealDBClient = TheMealDBClient()

    @State private var mealDBQuery = ""
    @State private var mealDBResults: [TheMealDBClient.Meal] = []
    @State private var isMealDBLoading = false
    @State private var mealDBError: String?

    @State private var selectedMealDetail: TheMealDBClient.MealDetail?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Entry type", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if mode == .manual {
                    manualForm
                } else {
                    mealDBSection
                }
            }
            .navigationTitle("Add Food")
            .onAppear {
                ensureManualFields()
            }
            .onChange(of: mode) {newMode in
                if newMode == .mealdb, mealDBResults.isEmpty {
                    Task { await searchMealDB() }
                }
            }
            .sheet(item: $selectedMealDetail) { detail in
                MealDBAddMealSheet(
                    detail: detail,
                    foodDatabase: foodDatabase,
                    onAdd: { name, nutrients in
                        store.addFood(name: name, nutrients: nutrients)
                    },
                    onClose: {
                        selectedMealDetail = nil
                    }
                )
            }
        }
    }

    private var manualForm: some View {
        Form {
            Section("Food Details") {
                TextField("Food name", text: $name)
            }

            ForEach(NutrientCategory.allCases, id: \.self) { category in
                let defs = NutrientCatalog.tracked.filter { $0.category == category }
                if !defs.isEmpty {
                    Section(category.rawValue) {
                        ForEach(defs) { def in
                            HStack {
                                Text(def.name)
                                Spacer()
                                TextField(
                                    def.unit,
                                    text: Binding(
                                        get: { manualFields[def.id] ?? "" },
                                        set: { manualFields[def.id] = $0 }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                            }
                        }
                    }
                }
            }

            if showValidation {
                Section {
                    Text("Enter a food name and at least calories, with valid numbers elsewhere.")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button("Add Food") {
                    addManual()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var mealDBSection: some View {
        List {
            Section("Search meals") {
                TextField("Search meals", text: $mealDBQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Button(isMealDBLoading ? "Searching…" : "Search") {
                    Task { await searchMealDB() }
                }
                .disabled(isMealDBLoading || mealDBQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let mealDBError {
                    Text(mealDBError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if isMealDBLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if mealDBResults.isEmpty {
                Section {
                    Text("No meals found.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Results") {
                    ForEach(mealDBResults) { meal in
                        Button {
                            Task { await selectMealDBMeal(meal) }
                        } label: {
                            HStack(spacing: 12) {
                                if let thumb = meal.strMealThumb, let url = URL(string: thumb) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Color(.secondarySystemBackground)
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.secondarySystemBackground))
                                        .frame(width: 44, height: 44)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(meal.strMeal)
                                        .foregroundStyle(.primary)
                                    Text("Tap to add")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onSubmit(of: .text) {
            Task { await searchMealDB() }
        }
        .task {
            if mealDBResults.isEmpty {
                await searchMealDB()
            }
        }
    }


    private func ensureManualFields() {
        if manualFields.isEmpty {
            for def in NutrientCatalog.tracked {
                manualFields[def.id] = ""
            }
        }
    }

    private func addManual() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showValidation = true
            return
        }
        var nutrients: [Int: Double] = [:]
        for def in NutrientCatalog.tracked {
            let raw = manualFields[def.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !raw.isEmpty, let v = Double(raw) else { continue }
            nutrients[def.id] = v
        }
        if nutrients[1008] == nil {
            if let computed = computeCaloriesFromMacros(nutrients: nutrients) {
                nutrients[1008] = computed
            }
        }
        guard nutrients[1008] != nil else {
            showValidation = true
            return
        }
        store.addFood(name: trimmed, nutrients: nutrients)
        name = ""
        for def in NutrientCatalog.tracked {
            manualFields[def.id] = ""
        }
        showValidation = false
    }


    @MainActor
    private func searchMealDB() async {
        let q = mealDBQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isMealDBLoading = true
        mealDBError = nil
        defer { isMealDBLoading = false }

        do {
            mealDBResults = try await mealDBClient.searchMealsByName(q)
        } catch {
            mealDBResults = []
            mealDBError = error.localizedDescription
        }
    }

    private func selectMealDBMeal(_ meal: TheMealDBClient.Meal) async {
        do {
            let detail = try await mealDBClient.lookupMealDetail(idMeal: meal.idMeal)
            selectedMealDetail = detail
        } catch {
            mealDBError = error.localizedDescription
        }
    }

    /// Computes calories from macros using:
    /// carbs (1005) * 4 + fat (1004) * 9 + protein (1003) * 4.
    /// Returns nil if none of the macros are present.
    private func computeCaloriesFromMacros(nutrients: [Int: Double]) -> Double? {
        let protein = nutrients[1003] ?? 0
        let carbs = nutrients[1005] ?? 0
        let fat = nutrients[1004] ?? 0

        if protein == 0, carbs == 0, fat == 0 { return nil }
        return protein * 4 + carbs * 4 + fat * 9
    }

}
