import SwiftUI

struct AddFoodView: View {
    @EnvironmentObject private var store: NutritionStore
    @EnvironmentObject private var foodDatabase: FoundationFoodDatabase

    private enum Mode: String, CaseIterable {
        case manual = "Manual"
        case usda = "Lookup Food"
        case mealdb = "Lookup Meals"
    }

    @State private var mode: Mode = .manual
    @State private var name = ""
    @State private var manualFields: [Int: String] = [:]
    @State private var showValidation = false

    @State private var searchText = ""
    @State private var browseGroup: FoodBrowseGroup = .all
    @State private var meatSubfilter: FoodMeatSubfilter = .all
    @State private var expandedUSDAFoodGroups: Set<String> = []
    /// USDA flow: pick a category row first, then (if meat) pick a meat type, then see foods.
    @State private var usdaPhase: USDABrowsePhase = .pickCategory
    @State private var selectedItem: FoundationFoodItem?
    @State private var portionGrams = "100"

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

    private enum USDABrowsePhase: Equatable {
        case pickCategory
        case pickMeatSubtype
        case listFoods
    }

    private struct USDAFoodGroup: Identifiable {
        let id: String
        let title: String
        let items: [FoundationFoodItem]
    }

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
                } else if mode == .usda {
                    databaseSection
                } else {
                    mealDBSection
                }
            }
            .navigationTitle(mode == .usda ? usdaNavigationTitle : "Add Food")
            .navigationBarTitleDisplayMode(mode == .usda ? .inline : .automatic)
            .toolbar {
                if mode == .usda, usdaPhase != .pickCategory {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            goBackUSDABrowse()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(usdaBackButtonTitle)
                            }
                        }
                    }
                }
            }
            .onAppear {
                ensureManualFields()
            }
            .onChange(of: mode) {newMode in
                if newMode == .usda {
                    resetUSDABrowseToCategories()
                } else if newMode == .mealdb, mealDBResults.isEmpty {
                    Task { await searchMealDB() }
                }
            }
            .sheet(item: $selectedItem) { item in
                portionSheet(for: item)
            }
            .sheet(item: $selectedMealDetail) { detail in
                mealDBNutritionSheet(for: detail)
            }
        }
    }

    private var usdaNavigationTitle: String {
        guard mode == .usda else { return "Add Food" }
        switch usdaPhase {
        case .pickCategory:
            return "Choose category"
        case .pickMeatSubtype:
            return FoodBrowseGroup.meatPoultry.rawValue
        case .listFoods:
            if browseGroup == .meatPoultry, meatSubfilter != .all {
                return "\(browseGroup.rawValue) · \(meatSubfilter.rawValue)"
            }
            return browseGroup.rawValue
        }
    }

    private var usdaBackButtonTitle: String {
        switch usdaPhase {
        case .listFoods:
            return browseGroup == .meatPoultry ? "Meat types" : "Categories"
        case .pickMeatSubtype:
            return "Categories"
        case .pickCategory:
            return ""
        }
    }

    private func goBackUSDABrowse() {
        expandedUSDAFoodGroups.removeAll()
        switch usdaPhase {
        case .listFoods:
            searchText = ""
            if browseGroup == .meatPoultry {
                usdaPhase = .pickMeatSubtype
            } else {
                usdaPhase = .pickCategory
                browseGroup = .all
                meatSubfilter = .all
            }
        case .pickMeatSubtype:
            usdaPhase = .pickCategory
            browseGroup = .all
            meatSubfilter = .all
        case .pickCategory:
            break
        }
    }

    private func resetUSDABrowseToCategories() {
        usdaPhase = .pickCategory
        browseGroup = .all
        meatSubfilter = .all
        searchText = ""
        expandedUSDAFoodGroups.removeAll()
    }

    private func selectBrowseGroup(_ group: FoodBrowseGroup) {
        expandedUSDAFoodGroups.removeAll()
        searchText = ""
        browseGroup = group
        if group == .meatPoultry {
            meatSubfilter = .all
            usdaPhase = .pickMeatSubtype
        } else {
            usdaPhase = .listFoods
        }
    }

    private func selectMeatSubfilter(_ sub: FoodMeatSubfilter) {
        expandedUSDAFoodGroups.removeAll()
        searchText = ""
        meatSubfilter = sub
        usdaPhase = .listFoods
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
        .onSubmit(of: .text) {
            Task { await searchMealDB() }
        }
        .task {
            if mealDBResults.isEmpty {
                await searchMealDB()
            }
        }
    }

    private var databaseSection: some View {
        Group {
            if foodDatabase.isLoading {
                ProgressView("Loading USDA Foundation Foods…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = foodDatabase.loadError {
                Text(err)
                    .foregroundStyle(.red)
                    .padding()
            } else {
                List {
                    switch usdaPhase {
                    case .pickCategory:
                        Section {
                            TextField("Search all foods", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Text("Search matches any word; order does not need to match the full name.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ForEach(groupedUSDAFoods) { group in
                                if group.items.count == 1 && group.title == group.items[0].description {
                                    usdaFoodButton(group.items[0])
                                } else {
                                    DisclosureGroup(
                                        isExpanded: usdaFoodGroupBinding(for: group.id)
                                    ) {
                                        ForEach(group.items) { item in
                                            usdaFoodButton(item)
                                        }
                                    } label: {
                                        usdaRow(
                                            title: group.title,
                                            detail: "\(group.items.count) variants",
                                            footnote: "Tap to choose a specific option",
                                            detailIsTertiary: true
                                        )
                                    }
                                }
                            }
                        } else {
                            Section {
                                Text("Choose a category to see foods. Meat & poultry has one more step to narrow by type.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(FoodBrowseGroup.allCases) { group in
                                Button {
                                    selectBrowseGroup(group)
                                } label: {
                                    usdaRow(
                                        title: group.rawValue,
                                        detail: usdaCategorySubtitle(for: group),
                                        footnote: "Tap to browse"
                                    )
                                }
                            }
                        }
                    case .pickMeatSubtype:
                        Section {
                            Text("Choose a meat type, or “All in group” for every meat & poultry item.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(FoodMeatSubfilter.allCases) { sub in
                            Button {
                                selectMeatSubfilter(sub)
                            } label: {
                                usdaRow(
                                    title: sub.rawValue,
                                    detail: sub == .all
                                        ? "Includes chicken, beef, pork, and more"
                                        : "Foods with “\(sub.rawValue.lowercased())” in the name",
                                    footnote: "Tap to see foods"
                                )
                            }
                        }
                    case .listFoods:
                        Section {
                            TextField("Search in this category", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Text("Search matches any word; order does not need to match the full name.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(groupedUSDAFoods) { group in
                            if group.items.count == 1 && group.title == group.items[0].description {
                                usdaFoodButton(group.items[0])
                            } else {
                                DisclosureGroup(
                                    isExpanded: usdaFoodGroupBinding(for: group.id)
                                ) {
                                    ForEach(group.items) { item in
                                        usdaFoodButton(item)
                                    }
                                } label: {
                                    usdaRow(
                                        title: group.title,
                                        detail: "\(group.items.count) variants",
                                        footnote: "Tap to choose a specific option",
                                        detailIsTertiary: true
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedUSDAFoods: [USDAFoodGroup] {
        let foods = foodDatabase.search(searchText, browse: browseGroup, meatSubfilter: meatSubfilter)
        let grouped = Dictionary(grouping: foods) { item in
            FoundationFoodDatabase.browseDisplayName(for: item.description)
        }

        return grouped.keys.sorted().map { key in
            USDAFoodGroup(
                id: key,
                title: key,
                items: grouped[key, default: []].sorted {
                    $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending
                }
            )
        }
    }

    private func usdaCategorySubtitle(for group: FoodBrowseGroup) -> String {
        switch group {
        case .all:
            return "Search across every foundation food"
        case .meatPoultry:
            return "Then pick chicken, beef, pork, and more"
        case .dairyEggs:
            return "Milk, cheese, yogurt, eggs…"
        case .grainsBakery:
            return "Bread, cereal, flour, pasta…"
        case .vegetables:
            return "Vegetables and vegetable products"
        case .fruits:
            return "Fruits and juices"
        case .legumes:
            return "Beans, lentils, hummus…"
        case .seafood:
            return "Fish and shellfish"
        case .fatsOils:
            return "Oils and solid fats"
        case .snacksSweets:
            return "Snacks, nuts, sweets"
        case .other:
            return "Everything else in the database"
        }
    }

    /// Shared layout with food rows: title, optional detail line, footnote caption.
    @ViewBuilder
    private func usdaRow(title: String, detail: String?, footnote: String, detailIsTertiary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(.primary)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(detailIsTertiary ? .tertiary : .secondary)
            }
            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func usdaFoodButton(_ item: FoundationFoodItem) -> some View {
        Button {
            selectedItem = item
            portionGrams = "100"
        } label: {
            usdaRow(
                title: item.description,
                detail: item.fdcCategoryDescription,
                footnote: "Tap to choose portion (per 100 g in database)",
                detailIsTertiary: true
            )
        }
    }

    private func usdaFoodGroupBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedUSDAFoodGroups.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedUSDAFoodGroups.insert(id)
                } else {
                    expandedUSDAFoodGroups.remove(id)
                }
            }
        )
    }

    private func portionSheet(for item: FoundationFoodItem) -> some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(item.description)
                        .font(.body)
                }
                Section("Portion") {
                    TextField("Grams", text: $portionGrams)
                        .keyboardType(.decimalPad)
                    Text("Nutrients are scaled from USDA values per 100 g.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Add to log") {
                        addFromDatabase(item)
                    }
                }
            }
            .navigationTitle("Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedItem = nil
                    }
                }
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

    private func addFromDatabase(_ item: FoundationFoodItem) {
        guard let g = Double(portionGrams.trimmingCharacters(in: .whitespacesAndNewlines)), g > 0 else {
            return
        }
        let scaled = FoundationFoodDatabase.scaledNutrients(item.nutrientsPer100g, grams: g)
        let label = "\(item.description) (\(String(format: "%.0f", g)) g)"
        store.addFood(name: label, nutrients: scaled)
        selectedItem = nil
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
                    Text("We’ll estimate nutrition by matching ingredients to the USDA foundation database and scaling by servings.")
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
                    Button(isMealDBNutritionComputing ? "Calculating…" : "Add to log") {
                        Task { await addMealDBDetailToLog(detail) }
                    }
                    .disabled(isMealDBDetailLoading || isMealDBNutritionComputing || foodDatabase.isLoading)
                }
            }
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
