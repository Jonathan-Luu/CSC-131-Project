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
    @State private var ageLimitMessage: String?
    @State private var weightLimitMessage: String?
    @State private var heightLimitMessage: String?
    @State private var isApplyingAgeLimit = false
    @State private var isApplyingWeightLimit = false
    @State private var heightLimitAdjustmentCount = 0
    @FocusState private var focusedField: Field?

    private enum Field {
        case age
        case weight
        case heightFeet
        case heightInches
    }

    private let maxWeightLb = 2000.0
    private let maxHeightFeet = 10
    private let maxHeightInches = 11
    private let defaultWeightLb = 150.0
    private let ageRange = 12...100

    private let lbToKg = 0.45359237
    private let inchToCm = 2.54

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", value: $store.profile.age, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .age)
                    }
                    if let ageLimitMessage {
                        Text(ageLimitMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Text("Weight (lb)")
                        Spacer()
                        TextField("Weight", value: $weightLb, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .weight)
                    }
                    if let weightLimitMessage {
                        Text(weightLimitMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
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
                                    .focused($focusedField, equals: .heightFeet)
                                Text("ft")
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 6) {
                                TextField("in", value: $heightInches, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 44)
                                    .focused($focusedField, equals: .heightInches)
                                Text("in")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let heightLimitMessage {
                        Text(heightLimitMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Picker("Sex", selection: $sex) {
                        ForEach(Sex.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Activity", selection: binding(for: \.activityMultiplier)) {
                        Text("Sedentary").tag(1.2)
                        Text("Light").tag(1.375)
                        Text("Moderate").tag(1.55)
                        Text("Active").tag(1.725)
                        Text("Very Active").tag(1.9)
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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                        clearLimitMessages()
                    }
                }
            }
            .onAppear {
                syncUIFromProfile()
            }
            .onChange(of: sex) { newValue in
                store.profile.isMale = (newValue == .male)
            }
            .onChange(of: focusedField) { newValue in
                if newValue == nil {
                    clearLimitMessages()
                }
            }
            .onChange(of: store.profile.age) { newValue in
                if isApplyingAgeLimit {
                    isApplyingAgeLimit = false
                    return
                }

                let clamped = min(max(newValue, ageRange.lowerBound), ageRange.upperBound)
                if clamped != newValue {
                    ageLimitMessage = ageLimitWarning
                    isApplyingAgeLimit = true
                    store.profile.age = clamped
                    return
                }
                ageLimitMessage = nil
            }
            .onChange(of: weightLb) { newValue in
                if isApplyingWeightLimit {
                    isApplyingWeightLimit = false
                    return
                }

                let clamped = min(max(newValue, 0), maxWeightLb)
                if clamped != newValue {
                    weightLimitMessage = weightLimitWarning
                    store.profile.weightKg = clamped * lbToKg
                    store.profile.lastWeightLb = clamped
                    isApplyingWeightLimit = true
                    weightLb = clamped
                    return
                }
                weightLimitMessage = nil
                store.profile.weightKg = clamped * lbToKg
                store.profile.lastWeightLb = clamped
            }
            .onChange(of: heightFeet) { newValue in
                if heightLimitAdjustmentCount > 0 {
                    heightLimitAdjustmentCount -= 1
                    syncProfileHeightFromUI()
                    return
                }

                if newValue < 0 {
                    heightLimitMessage = heightLimitWarning
                    if heightFeet != 0 {
                        heightLimitAdjustmentCount += 1
                    }
                    heightFeet = 0
                    return
                }
                if newValue > maxHeightFeet {
                    heightLimitMessage = heightLimitWarning
                    if heightFeet != maxHeightFeet {
                        heightLimitAdjustmentCount += 1
                    }
                    if heightInches != maxHeightInches {
                        heightLimitAdjustmentCount += 1
                    }
                    heightFeet = maxHeightFeet
                    heightInches = maxHeightInches
                    syncProfileHeightFromUI()
                    return
                }
                heightLimitMessage = nil
                syncProfileHeightFromUI()
            }
            .onChange(of: heightInches) { newValue in
                if heightLimitAdjustmentCount > 0 {
                    heightLimitAdjustmentCount -= 1
                    syncProfileHeightFromUI()
                    return
                }

                let maxInches = (heightFeet >= maxHeightFeet) ? maxHeightInches : 11
                let clamped = min(max(newValue, 0), maxInches)
                if clamped != newValue {
                    heightLimitMessage = heightLimitWarning
                    if heightInches != clamped {
                        heightLimitAdjustmentCount += 1
                    }
                    heightInches = clamped
                    return
                }
                heightLimitMessage = nil
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

    private func syncUIFromProfile() {
        sex = store.profile.isMale ? .male : .female
        if let saved = store.profile.lastWeightLb {
            weightLb = min(max(saved, 0), maxWeightLb)
            store.profile.weightKg = weightLb * lbToKg
        } else {
            weightLb = defaultWeightLb
            store.profile.weightKg = weightLb * lbToKg
            store.profile.lastWeightLb = weightLb
        }

        if let feet = store.profile.lastHeightFeet, let inches = store.profile.lastHeightInches {
            heightFeet = min(max(feet, 0), maxHeightFeet)
            let maxInches = (heightFeet >= maxHeightFeet) ? maxHeightInches : 11
            heightInches = min(max(inches, 0), maxInches)
            syncProfileHeightFromUI()
        } else {
            let totalInches = max(0, Int((store.profile.heightCm / inchToCm).rounded()))
            let maxTotalInches = maxHeightFeet * 12 + maxHeightInches
            let clampedTotalInches = min(totalInches, maxTotalInches)

            heightFeet = clampedTotalInches / 12
            heightInches = clampedTotalInches % 12
            store.profile.heightCm = Double(clampedTotalInches) * inchToCm
            store.profile.lastHeightFeet = heightFeet
            store.profile.lastHeightInches = heightInches
        }
    }

    private func syncProfileHeightFromUI() {
        let feet = max(0, heightFeet)
        let inches = min(max(heightInches, 0), 11)
        let totalInches = feet * 12 + inches
        store.profile.heightCm = Double(totalInches) * inchToCm
        store.profile.lastHeightFeet = feet
        store.profile.lastHeightInches = inches
    }

    private func clearLimitMessages() {
        ageLimitMessage = nil
        weightLimitMessage = nil
        heightLimitMessage = nil
    }

    private var ageLimitWarning: String {
        "Please enter an age within \(ageRange.lowerBound)-\(ageRange.upperBound)."
    }

    private var weightLimitWarning: String {
        "Please enter a weight within 0-\(String(format: "%.0f", maxWeightLb)) lb."
    }

    private var heightLimitWarning: String {
        "Please enter a height within 0 ft 0 in-\(maxHeightFeet) ft \(maxHeightInches) in."
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
