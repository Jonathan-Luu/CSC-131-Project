import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: NutritionStore

    private var totals: (calories: Double, protein: Double, cholesterol: Double) {
        store.todaysTotals
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Today's Nutrients") {
                    nutrientRow(
                        label: "Calories",
                        value: totals.calories,
                        goal: store.goal.calories,
                        unit: "kcal",
                        prefersLess: false
                    )
                    nutrientRow(
                        label: "Protein",
                        value: totals.protein,
                        goal: store.goal.protein,
                        unit: "g",
                        prefersLess: false
                    )
                    nutrientRow(
                        label: "Cholesterol",
                        value: totals.cholesterol,
                        goal: store.goal.cholesterol,
                        unit: "mg",
                        prefersLess: true
                    )
                }

                Section("Goal Consistency") {
                    HStack {
                        Text("Days goals met")
                        Spacer()
                        Text("\(store.consistencyPercent, specifier: "%.1f")%")
                            .fontWeight(.semibold)
                    }
                    ProgressView(value: store.consistencyPercent, total: 100)
                }
            }
            .navigationTitle("Nutrition Tracker")
        }
    }

    private func nutrientRow(
        label: String,
        value: Double,
        goal: Double,
        unit: String,
        prefersLess: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value, specifier: "%.0f") / \(goal, specifier: "%.0f") \(unit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: normalizedProgress(value: value, goal: goal, prefersLess: prefersLess))
                .tint(prefersLess && value > goal ? .red : .green)
        }
    }

    private func normalizedProgress(value: Double, goal: Double, prefersLess: Bool) -> Double {
        guard goal > 0 else { return 0 }
        if prefersLess {
            return min(goal / max(value, 1), 1)
        }
        return min(value / goal, 1)
    }
}
