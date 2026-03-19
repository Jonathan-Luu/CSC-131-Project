import SwiftUI

struct AddFoodView: View {
    @EnvironmentObject private var store: NutritionStore

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var cholesterol = ""
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Food Details") {
                    TextField("Food name", text: $name)
                    TextField("Calories (kcal)", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Cholesterol (mg)", text: $cholesterol)
                        .keyboardType(.decimalPad)
                }

                if showValidation {
                    Text("Enter a valid name and numeric nutrients.")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button("Add Food") {
                    addFood()
                }
            }
            .navigationTitle("Add Food")
        }
    }

    private func addFood() {
        guard
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let caloriesValue = Double(calories),
            let proteinValue = Double(protein),
            let cholesterolValue = Double(cholesterol)
        else {
            showValidation = true
            return
        }

        store.addFood(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: caloriesValue,
            protein: proteinValue,
            cholesterol: cholesterolValue
        )

        name = ""
        calories = ""
        protein = ""
        cholesterol = ""
        showValidation = false
    }
}
