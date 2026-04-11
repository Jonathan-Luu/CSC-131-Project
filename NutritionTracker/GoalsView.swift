import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: NutritionStore

    @State private var draft: [Int: String] = [:]
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            Form {
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
                                            get: { draft[def.id] ?? "" },
                                            set: { draft[def.id] = $0 }
                                        )
                                    )
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 120)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Save Goals") {
                        saveGoal()
                    }
                }

                if showValidation {
                    Section {
                        Text("Enter valid numbers for goals you want to set. Leave blank or use 0 to ignore a nutrient in streaks.")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section("Current streak rule") {
                    Text("A day counts when every non-zero goal is met: minimums reached (or maximums not exceeded for cholesterol and sodium).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Consistency") {
                    Text("You have met your goals on \(store.consistencyPercent, specifier: "%.1f")% of logged days.")
                }
            }
            .navigationTitle("Goals")
            .onAppear {
                syncDraftFromStore()
            }
        }
    }

    private func syncDraftFromStore() {
        var next: [Int: String] = [:]
        for def in NutrientCatalog.tracked {
            let g = store.goal.targets[def.id] ?? 0
            if g > 0 {
                next[def.id] = formatGoal(g)
            } else {
                next[def.id] = ""
            }
        }
        draft = next
    }

    private func formatGoal(_ g: Double) -> String {
        if g.rounded() == g { return String(format: "%.0f", g) }
        return String(format: "%.2f", g)
    }

    private func saveGoal() {
        var targets: [Int: Double] = [:]
        for def in NutrientCatalog.tracked {
            let raw = draft[def.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty {
                targets[def.id] = 0
                continue
            }
            guard let v = Double(raw), v >= 0 else {
                showValidation = true
                return
            }
            targets[def.id] = v
        }
        store.updateGoal(targets: targets)
        showValidation = false
    }
}
