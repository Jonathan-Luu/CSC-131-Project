import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: NutritionStore

    @State private var draft: [Int: String] = [:]
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if activeDefinitions.isEmpty {
                        Text("You have not set any daily goals yet. Tap Add Goal to create one.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeDefinitions) { def in
                            goalRow(def: def)
                        }
                    }
                    
                } header: {
                    Text("Daily Goals")
                } 

                Section {
                    NavigationLink {
                        AddGoalView()
                            .environmentObject(store)
                    } label: {
                        Label("Add Goal", systemImage: "plus.circle")
                    }
                }

                if showValidation {
                    Section {
                        Text("Enter a valid number greater than zero for each goal, or remove the goal.")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section("Current streak rule") {
                    Text("A day counts when every active goal is met: minimums reached (or maximums not exceeded for cholesterol, sodium, and total fat).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Consistency") {
                    Text("You have met your goals on \(store.consistencyPercent, specifier: "%.1f")% of logged days.")
                }
            }
            .navigationTitle("Goals")
            .onAppear {
                syncFromStore()
            }
            .onChange(of: store.goal.targets) { _ in
                syncFromStore()
            }
        }
    }

    private var activeDefinitions: [NutrientCatalog.Definition] {
        NutrientCatalog.tracked.filter { (store.goal.targets[$0.id] ?? 0) > 0 }
    }

    private func goalRow(def: NutrientCatalog.Definition) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(def.name)
                    .font(.subheadline)
                Text(def.unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            TextField("Goal", text: Binding(
                get: { draft[def.id] ?? "" },
                set: { draft[def.id] = $0 }
            ))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 88)

            Button(role: .destructive) {
                removeGoal(def.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .imageScale(.medium)
                    .accessibilityLabel("Remove goal")
            }
            .buttonStyle(.borderless)
        }
    }

    private func syncFromStore() {
        let activeIds = Set(activeDefinitions.map(\.id))
        draft = draft.filter { activeIds.contains($0.key) }

        for def in activeDefinitions {
            if let goal = store.goal.targets[def.id], goal > 0 {
                draft[def.id] = formatGoal(goal)
            }
        }
    }

    private func removeGoal(_ id: Int) {
        var targets = store.goal.targets
        targets[id] = 0
        store.updateGoal(targets: targets)
        draft.removeValue(forKey: id)
        showValidation = false
    }

    private func formatGoal(_ goal: Double) -> String {
        if goal.rounded() == goal {
            return String(format: "%.0f", goal)
        }
        return String(format: "%.2f", goal)
    }
}
