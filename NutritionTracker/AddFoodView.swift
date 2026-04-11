import SwiftUI

struct AddFoodView: View {
    @EnvironmentObject private var store: NutritionStore
    @EnvironmentObject private var foodDatabase: FoundationFoodDatabase

    private enum Mode: String, CaseIterable {
        case manual = "Manual"
        case usda = "USDA Database"
    }

    @State private var mode: Mode = .manual
    @State private var name = ""
    @State private var manualFields: [Int: String] = [:]
    @State private var showValidation = false

    @State private var searchText = ""
    @State private var selectedItem: FoundationFoodItem?
    @State private var portionGrams = "100"

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
                    databaseSection
                }
            }
            .navigationTitle("Add Food")
            .onAppear {
                ensureManualFields()
            }
            .sheet(item: $selectedItem) { item in
                portionSheet(for: item)
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
                    Section {
                        TextField("Search foods", text: $searchText)
                    }
                    ForEach(foodDatabase.search(searchText)) { item in
                        Button {
                            selectedItem = item
                            portionGrams = "100"
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.description)
                                    .foregroundStyle(.primary)
                                Text("Tap to choose portion (per 100 g in database)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
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
}
