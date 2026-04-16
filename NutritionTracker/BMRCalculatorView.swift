import SwiftUI

struct BMRCalculatorView: View {
    @EnvironmentObject private var store: NutritionStore

    private enum Sex: String, CaseIterable, Identifiable {
        case male = "Male"
        case female = "Female"

        var id: String { rawValue }
    }

    @State private var sex: Sex = .male
    @State private var weightLb: Double = 0
    @State private var heightFeet: Int = 0
    @State private var heightInches: Int = 0

    private let lbToKg = 0.45359237
    private let inchToCm = 2.54

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", value: clampedIntBinding(for: \.age, range: 12...100), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Weight (lb)")
                        Spacer()
                        TextField("Weight", value: $weightLb, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Height")
                        Spacer()
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                TextField("ft", value: $heightFeet, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 44)
                                Text("ft")
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 6) {
                                TextField("in", value: $heightInches, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 44)
                                Text("in")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Picker("Sex", selection: $sex) {
                        ForEach(Sex.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Activity", selection: binding(for: \.activityMultiplier)) {
                        Text("Sedentary (1.2)").tag(1.2)
                        Text("Light (1.375)").tag(1.375)
                        Text("Moderate (1.55)").tag(1.55)
                        Text("Active (1.725)").tag(1.725)
                        Text("Very Active (1.9)").tag(1.9)
                    }
                }

                Section("Activity level reference") {
                    TextEditor(text: .constant(activityReferenceText))
                        .frame(minHeight: 160)
                        .disabled(true)
                        .font(.footnote)
                }

                Section("Estimated Daily Energy Need") {
                    Text("\(store.calculateBMR(), specifier: "%.0f") kcal/day")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            .navigationTitle("BMR Calculator")
            .onAppear {
                syncUIFromProfile()
            }
            .onChange(of: sex) { newValue in
                store.profile.isMale = (newValue == .male)
            }
            .onChange(of: weightLb) { newValue in
                store.profile.weightKg = max(0, newValue) * lbToKg
            }
            .onChange(of: heightFeet) { newValue in
                if newValue < 0 {
                    heightFeet = 0
                    return
                }
                syncProfileHeightFromUI()
            }
            .onChange(of: heightInches) { newValue in
                let clamped = min(max(newValue, 0), 11)
                if clamped != newValue {
                    heightInches = clamped
                    return
                }
                syncProfileHeightFromUI()
            }
        }
    }

    private func binding<T>(for keyPath: WritableKeyPath<UserProfile, T>) -> Binding<T> {
        Binding(
            get: { store.profile[keyPath: keyPath] },
            set: { store.profile[keyPath: keyPath] = $0 }
        )
    }

    private func clampedIntBinding(for keyPath: WritableKeyPath<UserProfile, Int>, range: ClosedRange<Int>) -> Binding<Int> {
        Binding(
            get: { store.profile[keyPath: keyPath] },
            set: { store.profile[keyPath: keyPath] = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    private func syncUIFromProfile() {
        sex = store.profile.isMale ? .male : .female
        weightLb = store.profile.weightKg / lbToKg

        let totalInches = Int((store.profile.heightCm / inchToCm).rounded())
        heightFeet = max(0, totalInches / 12)
        heightInches = min(max(totalInches % 12, 0), 11)
    }

    private func syncProfileHeightFromUI() {
        let feet = max(0, heightFeet)
        let inches = min(max(heightInches, 0), 11)
        let totalInches = feet * 12 + inches
        store.profile.heightCm = Double(totalInches) * inchToCm
    }

    private var activityReferenceText: String {
        """
        Sedentary (1.2): Little to no exercise; mostly sitting during the day.
        Light (1.375): Light exercise 1–3 days/week (easy walks, light gym work).
        Moderate (1.55): Moderate exercise 3–5 days/week.
        Active (1.725): Hard exercise 6–7 days/week.
        Very Active (1.9): Very hard exercise + physically demanding job/training.
        """
    }
}
