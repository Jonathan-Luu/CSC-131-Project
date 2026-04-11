import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject private var store: NutritionStore

    var body: some View {
        NavigationStack {
            List {
                Section("Nutrient Gap Helpers") {
                    ForEach(store.recommendedFoods()) { food in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(food.name)
                                .font(.headline)
                            Text(summaryLine(food.nutrients))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Recommendations")
        }
    }

    private func summaryLine(_ n: [Int: Double]) -> String {
        let c = n[1008].map { String(format: "%.0f kcal", $0) }
        let p = n[1003].map { String(format: "%.0fg protein", $0) }
        let ch = n[1253].map { String(format: "%.0fmg cholesterol", $0) }
        return [c, p, ch].compactMap { $0 }.joined(separator: " | ")
    }
}
