import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: NutritionStore

    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var cholesterol: String = ""
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Set Daily Goal") {
                    TextField("Calories (kcal)", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Cholesterol max (mg)", text: $cholesterol)
                        .keyboardType(.decimalPad)
                    Button("Save Goal") {
                        saveGoal()
                    }
                }

                if showValidation {
                    Text("Please enter valid numeric values.")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Section("Current Goal") {
                    Text("Calories: \(store.goal.calories, specifier: "%.0f") kcal")
                    Text("Protein: \(store.goal.protein, specifier: "%.0f") g")
                    Text("Cholesterol: \(store.goal.cholesterol, specifier: "%.0f") mg max")
                }

                Section("Consistency") {
                    Text("You have met your goals on \(store.consistencyPercent, specifier: "%.1f")% of logged days.")
                }
            }
            .navigationTitle("Goals")
            .onAppear {
                calories = String(format: "%.0f", store.goal.calories)
                protein = String(format: "%.0f", store.goal.protein)
                cholesterol = String(format: "%.0f", store.goal.cholesterol)
            }
        }
    }

    private func saveGoal() {
        guard
            let caloriesValue = Double(calories),
            let proteinValue = Double(protein),
            let cholesterolValue = Double(cholesterol),
            caloriesValue > 0,
            proteinValue > 0,
            cholesterolValue >= 0
        else {
            showValidation = true
            return
        }

        store.updateGoal(calories: caloriesValue, protein: proteinValue, cholesterol: cholesterolValue)
        showValidation = false
    }
}
