import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject private var store: NutritionStore
    @EnvironmentObject private var foodDatabase: FoundationFoodDatabase
    @StateObject private var vm = MealRecommendationsViewModel()

    var body: some View {
        NavigationStack {
            List {
                if !vm.focusDeficits.isEmpty {
                    Section("Missing goals today") {
                        ForEach(vm.focusDeficits.prefix(5), id: \.nutrientId) { item in
                            if let def = NutrientCatalog.definition(for: item.nutrientId) {
                                HStack {
                                    Text(def.name)
                                    Spacer()
                                    Text("\(format(item.deficit)) \(def.unit) left")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Recommended meals") {
                    if vm.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let error = vm.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if vm.recommendations.isEmpty {
                        Text(vm.focusDeficits.isEmpty
                             ? "You’ve met all of your minimum goals for today."
                             : "No meal recommendations found yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.recommendations) { rec in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 12) {
                                    if let url = rec.thumbURL {
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Color(.secondarySystemBackground)
                                        }
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(width: 44, height: 44)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rec.name)
                                            .font(.headline)
                                        Text(focusLine(rec))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }

                                Text(summaryLine(rec.estimatedNutrients))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Recommendations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task { await vm.refresh(store: store, foodDatabase: foodDatabase) }
                    }
                    .disabled(vm.isLoading)
                }
            }
            .task {
                if vm.recommendations.isEmpty, !vm.isLoading {
                    await vm.refresh(store: store, foodDatabase: foodDatabase)
                }
            }
        }
    }

    private func summaryLine(_ n: [Int: Double]) -> String {
        let c = n[1008].map { String(format: "%.0f kcal", $0) }
        let p = n[1003].map { String(format: "%.0f g protein", $0) }
        let ca = n[1087].map { String(format: "%.0f mg calcium", $0) }
        let fe = n[1089].map { String(format: "%.1f mg iron", $0) }
        return [c, p, ca, fe].compactMap { $0 }.joined(separator: " | ")
    }

    private func focusLine(_ rec: MealRecommendation) -> String {
        let names = rec.focusNutrientIds.compactMap { NutrientCatalog.definition(for: $0)?.name }
        if names.isEmpty { return "Chosen for your goals" }
        return "Helps with \(names.joined(separator: ", "))"
    }

    private func format(_ v: Double) -> String {
        if v.rounded() == v { return String(format: "%.0f", v) }
        if v >= 10 { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }
}
