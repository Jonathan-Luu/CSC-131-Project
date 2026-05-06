import SwiftUI

struct AddFoodView: View {
    @EnvironmentObject private var store: NutritionStore
    @EnvironmentObject private var foodDatabase: FoundationFoodDatabase

    private enum Mode: String, CaseIterable {
        case manual = "Manual"
        case mealdb = "Lookup Meals"
    }

    @State private var mode: Mode = .manual
    @State private var name = ""
    @State private var manualFields: [Int: String] = [:]
    @State private var showValidation = false

    // MARK: - TheMealDB
    private struct MealDBSearchResponse: Decodable {
        let meals: [MealDBMeal]?
    }

    private struct MealDBMeal: Identifiable, Decodable {
        let idMeal: String
        let strMeal: String
        let strMealThumb: String?

        var id: String { idMeal }
    }

    private struct MealDBLookupResponse: Decodable {
        let meals: [MealDBMealDetail]?
    }

    private struct MealDBMealDetail: Identifiable, Decodable {
        let idMeal: String
        let strMeal: String
        let strMealThumb: String?
        let strInstructions: String?

        // Ingredient slots (TheMealDB uses numbered keys; we decode manually)
        let strIngredient1: String?
        let strIngredient2: String?
        let strIngredient3: String?
        let strIngredient4: String?
        let strIngredient5: String?
        let strIngredient6: String?
        let strIngredient7: String?
        let strIngredient8: String?
        let strIngredient9: String?
        let strIngredient10: String?
        let strIngredient11: String?
        let strIngredient12: String?
        let strIngredient13: String?
        let strIngredient14: String?
        let strIngredient15: String?
        let strIngredient16: String?
        let strIngredient17: String?
        let strIngredient18: String?
        let strIngredient19: String?
        let strIngredient20: String?

        let strMeasure1: String?
        let strMeasure2: String?
        let strMeasure3: String?
        let strMeasure4: String?
        let strMeasure5: String?
        let strMeasure6: String?
        let strMeasure7: String?
        let strMeasure8: String?
        let strMeasure9: String?
        let strMeasure10: String?
        let strMeasure11: String?
        let strMeasure12: String?
        let strMeasure13: String?
        let strMeasure14: String?
        let strMeasure15: String?
        let strMeasure16: String?
        let strMeasure17: String?
        let strMeasure18: String?
        let strMeasure19: String?
        let strMeasure20: String?

        var id: String { idMeal }

        var ingredientLines: [String] {
            let ingredients: [String?] = [
                strIngredient1, strIngredient2, strIngredient3, strIngredient4, strIngredient5,
                strIngredient6, strIngredient7, strIngredient8, strIngredient9, strIngredient10,
                strIngredient11, strIngredient12, strIngredient13, strIngredient14, strIngredient15,
                strIngredient16, strIngredient17, strIngredient18, strIngredient19, strIngredient20,
            ]
            let measures: [String?] = [
                strMeasure1, strMeasure2, strMeasure3, strMeasure4, strMeasure5,
                strMeasure6, strMeasure7, strMeasure8, strMeasure9, strMeasure10,
                strMeasure11, strMeasure12, strMeasure13, strMeasure14, strMeasure15,
                strMeasure16, strMeasure17, strMeasure18, strMeasure19, strMeasure20,
            ]

            var out: [String] = []
            out.reserveCapacity(20)
            for i in 0..<min(ingredients.count, measures.count) {
                let ing = ingredients[i]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !ing.isEmpty else { continue }
                let measure = measures[i]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if measure.isEmpty {
                    out.append(ing)
                } else {
                    out.append("\(measure) \(ing)")
                }
            }
            return out
        }

        var ingredientPairs: [(ingredient: String, measure: String)] {
            let ingredients: [String?] = [
                strIngredient1, strIngredient2, strIngredient3, strIngredient4, strIngredient5,
                strIngredient6, strIngredient7, strIngredient8, strIngredient9, strIngredient10,
                strIngredient11, strIngredient12, strIngredient13, strIngredient14, strIngredient15,
                strIngredient16, strIngredient17, strIngredient18, strIngredient19, strIngredient20,
            ]
            let measures: [String?] = [
                strMeasure1, strMeasure2, strMeasure3, strMeasure4, strMeasure5,
                strMeasure6, strMeasure7, strMeasure8, strMeasure9, strMeasure10,
                strMeasure11, strMeasure12, strMeasure13, strMeasure14, strMeasure15,
                strMeasure16, strMeasure17, strMeasure18, strMeasure19, strMeasure20,
            ]

            var out: [(String, String)] = []
            out.reserveCapacity(20)
            for i in 0..<min(ingredients.count, measures.count) {
                let ing = ingredients[i]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !ing.isEmpty else { continue }
                let measure = measures[i]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                out.append((ing, measure))
            }
            return out
        }
    }

    @State private var mealDBQuery = ""
    @State private var mealDBResults: [MealDBMeal] = []
    @State private var isMealDBLoading = false
    @State private var mealDBError: String?

    @State private var isMealDBDetailLoading = false
    @State private var selectedMealDetail: MealDBMealDetail?
    @State private var mealDBServings = "1"
    @State private var showMealDBServingsValidation = false
    @State private var isMealDBNutritionComputing = false
    @State private var mealDBComputedNutrients: [Int: Double] = [:]
    @State private var mealDBComputedPreviewText: String?

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
                mealDBNutritionSheet(for: detail)
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
                
                Button(isMealDBLoading ? "Searching..." : "Search") {
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
                                    Text("Tap to add with nutrition")
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


    @MainActor
    private func searchMealDB() async {
        let q = mealDBQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isMealDBLoading = true
        mealDBError = nil
        defer { isMealDBLoading = false }

        do {
            var components = URLComponents(string: "https://www.themealdb.com/api/json/v1/1/search.php")!
            components.queryItems = [URLQueryItem(name: "s", value: q)]
            let url = components.url!

            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(MealDBSearchResponse.self, from: data)
            mealDBResults = decoded.meals ?? []
        } catch {
            mealDBResults = []
            mealDBError = error.localizedDescription
        }
    }

    @MainActor
    private func selectMealDBMeal(_ meal: MealDBMeal) async {
        isMealDBDetailLoading = true
        defer { isMealDBDetailLoading = false }

        do {
            var components = URLComponents(string: "https://www.themealdb.com/api/json/v1/1/lookup.php")!
            components.queryItems = [URLQueryItem(name: "i", value: meal.idMeal)]
            let url = components.url!

            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(MealDBLookupResponse.self, from: data)
            guard let detail = decoded.meals?.first else {
                mealDBError = "Meal details not found."
                return
            }

            // Reset serving + computed nutrition state for the new meal.
            mealDBServings = "1"
            showMealDBServingsValidation = false
            isMealDBNutritionComputing = false
            mealDBComputedNutrients = [:]
            mealDBComputedPreviewText = nil
            selectedMealDetail = detail
        } catch {
            mealDBError = error.localizedDescription
        }
    }

    private func mealDBNutritionSheet(for detail: MealDBMealDetail) -> some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    Text(detail.strMeal)
                        .font(.body)
                    if !detail.ingredientLines.isEmpty {
                        Text(detail.ingredientLines.joined(separator: "\n"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Servings") {
                    TextField("Servings", text: $mealDBServings)
                        .keyboardType(.decimalPad)
                    Text("We'll estimate nutrition by matching ingredients to the USDA foundation database and scaling by servings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if showMealDBServingsValidation {
                    Section {
                        Text("Enter a valid servings amount (e.g. 1, 2, 0.5).")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                if let preview = mealDBComputedPreviewText {
                    Section("Estimated nutrition (total)") {
                        Text(preview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(isMealDBNutritionComputing ? "Calculating..." : "Add to log") {
                        Task { await addMealDBDetailToLog(detail) }
                    }
                    .disabled(isMealDBDetailLoading || isMealDBNutritionComputing || foodDatabase.isLoading)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedMealDetail = nil
                    }
                }
            }
        }
    }

    @MainActor
    private func addMealDBDetailToLog(_ detail: MealDBMealDetail) async {
        let servingsRaw = mealDBServings.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let servings = Double(servingsRaw), servings > 0 else {
            showMealDBServingsValidation = true
            return
        }
        showMealDBServingsValidation = false

        guard !foodDatabase.isLoading else {
            mealDBComputedPreviewText = "USDA database is still loading. Please try again in a moment."
            return
        }

        isMealDBNutritionComputing = true
        defer { isMealDBNutritionComputing = false }

        let nutrients = estimateMealNutrients(detail: detail, servings: servings)
        mealDBComputedNutrients = nutrients

        if let calories = nutrients[1008] {
            let protein = nutrients[1003] ?? 0
            let carbs = nutrients[1005] ?? 0
            let fat = nutrients[1004] ?? 0
            mealDBComputedPreviewText = String(
                format: "Calories: %.0f kcal\nProtein: %.1f g\nCarbs: %.1f g\nFat: %.1f g",
                calories,
                protein,
                carbs,
                fat
            )
        } else {
            mealDBComputedPreviewText = "Could not estimate calories from the ingredient matches."
        }

        guard nutrients[1008] != nil else { return }

        store.addFood(name: "\(detail.strMeal) (\(servingsRaw) servings)", nutrients: nutrients)
        selectedMealDetail = nil
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

    @MainActor
    private func estimateMealNutrients(detail: MealDBMealDetail, servings: Double) -> [Int: Double] {
        var totalsPerRecipe: [Int: Double] = [:]

        for (ingredient, measure) in detail.ingredientPairs {
            let grams = estimateGrams(fromMeasure: measure)
            let query = sanitizeIngredientQuery(ingredient)
            guard !query.isEmpty else { continue }

            guard let match = foodDatabase.search(query).first else { continue }

            let gramsToUse = grams ?? 100.0
            let scaled = FoundationFoodDatabase.scaledNutrients(match.nutrientsPer100g, grams: gramsToUse)
            for (k, v) in scaled {
                totalsPerRecipe[k, default: 0] += v
            }
        }

        var totals: [Int: Double] = [:]
        totals.reserveCapacity(totalsPerRecipe.count)
        for (k, v) in totalsPerRecipe {
            totals[k] = v * servings
        }

        if totals[1008] == nil, let computed = computeCaloriesFromMacros(nutrients: totals) {
            totals[1008] = computed
        }

        return totals
    }

    private func sanitizeIngredientQuery(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let stopWords = ["fresh", "chopped", "diced", "minced", "sliced", "ground", "optional", "to taste"]
        var cleaned = lowered
        for w in stopWords {
            cleaned = cleaned.replacingOccurrences(of: w, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func estimateGrams(fromMeasure measureRaw: String) -> Double? {
        let m = measureRaw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if m.isEmpty { return nil }
        if m.contains("to taste") { return nil }

        func parseQuantity(_ s: String) -> Double? {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("/") {
                let parts = trimmed.split(separator: " ")
                var total: Double = 0
                for p in parts {
                    let fracParts = p.split(separator: "/")
                    if fracParts.count == 2,
                       let num = Double(fracParts[0]),
                       let den = Double(fracParts[1]),
                       den != 0 {
                        total += num / den
                    } else if let v = Double(p) {
                        total += v
                    }
                }
                return total > 0 ? total : nil
            }
            return Double(trimmed)
        }

        let tokens = m.split(separator: " ").map(String.init)
        guard let qty = tokens.first.flatMap(parseQuantity) else { return nil }
        let rest = tokens.dropFirst().joined(separator: " ")

        if rest.contains("kg") { return qty * 1000 }
        if rest.contains("g") { return qty }
        if rest.contains("ml") { return qty } // ~ water density
        if rest.contains("oz") { return qty * 28.3495 }
        if rest.contains("lb") { return qty * 453.592 }
        if rest.contains("cup") { return qty * 240 }
        if rest.contains("tbsp") || rest.contains("tablespoon") { return qty * 15 }
        if rest.contains("tsp") || rest.contains("teaspoon") { return qty * 5 }
        if rest.contains("clove") { return qty * 3 }
        if rest.contains("slice") { return qty * 25 }

        if rest.isEmpty { return qty * 100 }
        return nil
    }
}

