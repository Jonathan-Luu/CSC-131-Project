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
                            Text("\(food.calories, specifier: "%.0f") kcal | \(food.protein, specifier: "%.0f")g protein | \(food.cholesterol, specifier: "%.0f")mg cholesterol")
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
}
