import SwiftUI

struct AddFoodView: View {
    @EnvironmentObject private var store: NutritionStore
    @EnvironmentObject private var foodDatabase: FoundationFoodDatabase

    private enum Mode: String, CaseIterable {
        static let allCases: [Mode] = [.manual, .mealdb]

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
    private let mealDBClient = TheMealDBClient()

    @State private var mealDBQuery = ""
    @State private var mealDBResults: [TheMealDBClient.Meal] = []
    @State private var isMealDBLoading = false
    @State private var mealDBError: String?

    @State private var isMealDBDetailLoading = false
    @State private var selectedMealDetail: TheMealDBClient.MealDetail?
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
                .scrollDismissesKeyboard(.interactively)
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
            .scrollDismissesKeyboard(.interactively)
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
            mealDBResults = try await mealDBClient.searchMealsByName(q)
        } catch {
            mealDBResults = []
            mealDBError = error.localizedDescription
        }
    }

    @MainActor
    private func selectMealDBMeal(_ meal: TheMealDBClient.Meal) async {
        isMealDBDetailLoading = true
        defer { isMealDBDetailLoading = false }

        do {
            let detail = try await mealDBClient.lookupMealDetail(idMeal: meal.idMeal)

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

    private func mealDBNutritionSheet(for detail: TheMealDBClient.MealDetail) -> some View {
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
    private func addMealDBDetailToLog(_ detail: TheMealDBClient.MealDetail) async {
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

        let nutrients = MealDBNutritionEstimator.estimateNutrients(
            detail: detail,
            servings: servings,
            foodDatabase: foodDatabase
        )
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

}
