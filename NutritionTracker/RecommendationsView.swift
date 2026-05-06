import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject private var store: NutritionStore
    @EnvironmentObject private var foodDatabase: FoundationFoodDatabase
    @StateObject private var vm = MealRecommendationsViewModel()
    @State private var isLookupLoading = false
    @State private var lookupError: String?
    @State private var selectedMealDetail: TheMealDBClient.MealDetail?
    @State private var selectedAssumedServingsPerRecipe: Double = 4
    @State private var servingsText = "1"
    @State private var showServingsValidation = false
    @State private var isNutritionComputing = false
    @State private var computedPreviewText: String?

    var body: some View {
        NavigationStack {
            List {
                if !vm.focusDeficits.isEmpty {
                    Section("Missing goals today") {
                        ForEach(vm.focusDeficits.prefix(5), id: \.nutrientId) { item in
                            if let def = NutrientCatalog.definition(for: item.nutrientId) {
                                HStack {
                                    Text(def.name)
                                    Spacer()
                                    Text("\(format(item.deficit)) \(def.unit) left")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Recommended meals") {
                    if vm.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let error = vm.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if vm.recommendations.isEmpty {
                        Text(vm.focusDeficits.isEmpty
                             ? "You’ve met all of your minimum goals for today."
                             : "No meal recommendations found yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.recommendations) { rec in
                            Button {
                                Task { await openLookup(for: rec) }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 12) {
                                        if let url = rec.thumbURL {
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

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(rec.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(focusLine(rec))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("Tap to add")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        Spacer()
                                    }

                                    Text(summaryLine(rec.estimatedNutrientsPerServing))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Recommendations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task { await vm.refresh(store: store, foodDatabase: foodDatabase) }
                    }
                    .disabled(vm.isLoading)
                }
            }
            .overlay {
                if isLookupLoading {
                    ProgressView()
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                if vm.recommendations.isEmpty, !vm.isLoading {
                    await vm.refresh(store: store, foodDatabase: foodDatabase)
                }
            }
            .alert("Meal Lookup Error", isPresented: Binding(get: { lookupError != nil }, set: { _ in lookupError = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(lookupError ?? "")
            }
            .sheet(item: $selectedMealDetail) { detail in
                mealAddSheet(for: detail)
            }
        }
    }

    @MainActor
    private func openLookup(for rec: MealRecommendation) async {
        guard !isLookupLoading else { return }
        lookupError = nil

        // Reset sheet state each time.
        servingsText = "1"
        showServingsValidation = false
        isNutritionComputing = false
        computedPreviewText = nil
        selectedAssumedServingsPerRecipe = rec.assumedServingsPerRecipe

        isLookupLoading = true
        defer { isLookupLoading = false }

        do {
            let detail = try await TheMealDBClient().lookupMealDetail(idMeal: rec.id)
            selectedMealDetail = detail
        } catch {
            lookupError = error.localizedDescription
        }
    }

    private func mealAddSheet(for detail: TheMealDBClient.MealDetail) -> some View {
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
                    TextField("Servings", text: $servingsText)
                        .keyboardType(.decimalPad)
                    Text("Serving counts are estimated (TheMealDB doesn’t provide them).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("We’ll estimate nutrition by matching ingredients to the USDA foundation database and scaling by servings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if showServingsValidation {
                    Section {
                        Text("Enter a valid servings amount (e.g. 1, 2, 0.5).")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                if let preview = computedPreviewText {
                    Section("Estimated nutrition (total)") {
                        Text(preview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(isNutritionComputing ? "Calculating…" : "Add to log") {
                        Task { await addDetailToLog(detail) }
                    }
                    .disabled(isNutritionComputing || foodDatabase.isLoading)
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
    private func addDetailToLog(_ detail: TheMealDBClient.MealDetail) async {
        let servingsRaw = servingsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let servings = Double(servingsRaw), servings > 0 else {
            showServingsValidation = true
            return
        }
        showServingsValidation = false

        guard !foodDatabase.isLoading else {
            computedPreviewText = "USDA database is still loading. Please try again in a moment."
            return
        }

        isNutritionComputing = true
        defer { isNutritionComputing = false }

        // Estimator returns totals for the full recipe. Convert to per-serving using the
        // same assumed serving count we used to display the recommendation.
        let recipeTotals = MealDBNutritionEstimator.estimateNutrients(
            detail: detail,
            servings: 1.0,
            foodDatabase: foodDatabase
        )
        let perServing = MealRecommendationsViewModel.divideNutrients(recipeTotals, by: selectedAssumedServingsPerRecipe)
        var nutrients: [Int: Double] = [:]
        nutrients.reserveCapacity(perServing.count)
        for (k, v) in perServing {
            nutrients[k] = v * servings
        }

        if let calories = nutrients[1008] {
            let protein = nutrients[1003] ?? 0
            let carbs = nutrients[1005] ?? 0
            let fat = nutrients[1004] ?? 0
            computedPreviewText = String(
                format: "Calories: %.0f kcal\nProtein: %.1f g\nCarbs: %.1f g\nFat: %.1f g",
                calories,
                protein,
                carbs,
                fat
            )
        } else {
            computedPreviewText = "Could not estimate calories from the ingredient matches."
        }

        guard nutrients[1008] != nil else { return }
        store.addFood(name: "\(detail.strMeal) (\(servingsRaw) servings)", nutrients: nutrients)
        selectedMealDetail = nil
    }

    private func summaryLine(_ n: [Int: Double]) -> String {
        let c = n[1008].map { String(format: "%.0f kcal", $0) }
        let p = n[1003].map { String(format: "%.0f g protein", $0) }
        let ca = n[1087].map { String(format: "%.0f mg calcium", $0) }
        let fe = n[1089].map { String(format: "%.1f mg iron", $0) }
        return [c, p, ca, fe].compactMap { $0 }.joined(separator: " | ")
    }

    private func focusLine(_ rec: MealRecommendation) -> String {
        let names = rec.focusNutrientIds.compactMap { NutrientCatalog.definition(for: $0)?.name }
        if names.isEmpty { return "Chosen for your goals" }
        return "Helps with \(names.joined(separator: ", "))"
    }

    private func format(_ v: Double) -> String {
        if v.rounded() == v { return String(format: "%.0f", v) }
        if v >= 10 { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }
}
