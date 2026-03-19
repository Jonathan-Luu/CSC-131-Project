import SwiftUI

struct BMRCalculatorView: View {
    @EnvironmentObject private var store: NutritionStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    Stepper("Age: \(store.profile.age)", value: binding(for: \.age), in: 12...100)

                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("Weight", value: binding(for: \.weightKg), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        TextField("Height", value: binding(for: \.heightCm), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    Toggle("Male", isOn: binding(for: \.isMale))

                    Picker("Activity", selection: binding(for: \.activityMultiplier)) {
                        Text("Sedentary (1.2)").tag(1.2)
                        Text("Light (1.375)").tag(1.375)
                        Text("Moderate (1.55)").tag(1.55)
                        Text("Active (1.725)").tag(1.725)
                        Text("Very Active (1.9)").tag(1.9)
                    }
                }

                Section("Estimated Daily Energy Need") {
                    Text("\(store.calculateBMR(), specifier: "%.0f") kcal/day")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            .navigationTitle("BMR Calculator")
        }
    }

    private func binding<T>(for keyPath: WritableKeyPath<UserProfile, T>) -> Binding<T> {
        Binding(
            get: { store.profile[keyPath: keyPath] },
            set: { store.profile[keyPath: keyPath] = $0 }
        )
    }
}
