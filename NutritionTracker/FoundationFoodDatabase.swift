import Foundation
import Combine

// MARK: - USDA JSON (FoodData Central foundation_food_json)

private struct FoodDataCentralFile: Decodable {
    let foundationFoods: [FDCFood]

    enum CodingKeys: String, CodingKey {
        case foundationFoods = "FoundationFoods"
    }
}

private struct FDCFoodCategory: Decodable {
    let description: String?
}

private struct FDCFood: Decodable {
    let description: String
    let foodNutrients: [FDCFoodNutrient]
    let foodCategory: FDCFoodCategory?
}

private struct FDCFoodNutrient: Decodable {
    let nutrient: FDCNutrient
    let amount: Double?
    /// Some FDC rows publish only `median` (e.g. lab aggregates) instead of `amount`.
    let median: Double?

    var resolvedAmount: Double? {
        if let amount { return amount }
        return median
    }
}

private struct FDCNutrient: Decodable {
    let id: Int
    let name: String
    let unitName: String
}

/// One foundation food with nutrient amounts **per 100 g** edible portion (USDA standard).
struct FoundationFoodItem: Identifiable, Hashable {
    let id: Int
    let description: String
    /// FDC `foodCategory.description` when present (e.g. `"Poultry Products"`).
    let fdcCategoryDescription: String?
    /// USDA nutrient id → amount per 100 g
    let nutrientsPer100g: [Int: Double]
}

@MainActor
final class FoundationFoodDatabase: ObservableObject {
    @Published private(set) var items: [FoundationFoodItem] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?

    private static let bundleName = "FoodData_Central_foundation_food_json_2025-12-18"

    init() {
        Task { await load() }
    }

    /// Local search: optional **browse** bucket (from FDC category), optional **meat** keyword filter, then tokenized text query with ranking.
    func search(
        _ query: String,
        browse: FoodBrowseGroup = .all,
        meatSubfilter: FoodMeatSubfilter = .all
    ) -> [FoundationFoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var tokens = FoodSearchQuery.tokens(from: trimmed)
        if tokens.isEmpty, !trimmed.isEmpty {
            tokens = [FoodSearchQuery.canonicalToken(trimmed.lowercased())]
        }
        let normalized = FoodSearchQuery.normalizedText(from: trimmed)

        var base = items
        if browse != .all {
            base = base.filter { FoodBrowseGroup.from(fdcCategoryDescription: $0.fdcCategoryDescription) == browse }
        }
        if browse == .meatPoultry, meatSubfilter != .all {
            base = base.filter { meatSubfilter.matchesDescription($0.description) }
        }

        if trimmed.isEmpty {
            return base.sorted { $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending }
        }

        let matched = base.filter {
            FoodSearchQuery.matchesAllTokens(
                description: $0.description,
                fdcCategory: $0.fdcCategoryDescription,
                tokens: tokens
            )
        }

        return matched.sorted {
            let s0 = FoodSearchQuery.relevanceScore(
                description: $0.description,
                fdcCategory: $0.fdcCategoryDescription,
                normalizedQuery: normalized,
                tokens: tokens
            )
            let s1 = FoodSearchQuery.relevanceScore(
                description: $1.description,
                fdcCategory: $1.fdcCategoryDescription,
                normalizedQuery: normalized,
                tokens: tokens
            )
            if s0 != s1 { return s0 > s1 }
            return $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending
        }
    }

    /// Scale per-100 g values to the given gram amount.
    static func scaledNutrients(_ per100g: [Int: Double], grams: Double) -> [Int: Double] {
        let factor = grams / 100.0
        var out: [Int: Double] = [:]
        for (k, v) in per100g {
            out[k] = v * factor
        }
        return out
    }

    /// Safer browse label used only for UI grouping; underlying USDA items stay unchanged.
    static func browseDisplayName(for description: String) -> String {
        let components = significantBrowseComponents(from: description)
        let lower = description.lowercased()

        if isFlourLike(description: lower) {
            return "Flour"
        }
        if isCheeseLike(description: lower) {
            return "Cheese"
        }
        if isYogurtLike(description: lower) {
            return "Yogurt"
        }
        if isMilkLike(description: lower) {
            return "Milk"
        }
        if isBeanLike(description: lower) {
            return "Beans"
        }
        if isRiceLike(description: lower) {
            return "Rice"
        }
        if isShellfishLike(description: lower, components: components) {
            return "Shellfish"
        }
        if isFishLike(description: lower, components: components) {
            return "Fish"
        }

        if lower.contains("chicken") {
            return poultryDisplayName(base: "Chicken", description: lower) ?? description
        }
        if lower.contains("turkey") {
            return poultryDisplayName(base: "Turkey", description: lower) ?? description
        }
        if let meat = meatDisplayName(description: lower) {
            return meat
        }
        if let seafood = seafoodDisplayName(from: components) {
            return seafood
        }
        if let generic = genericDisplayName(from: components) {
            return generic
        }

        return description
    }

    private static func poultryDisplayName(base: String, description: String) -> String? {
        if description.contains("breast") { return "\(base) Breast" }
        if description.contains("thigh") { return "\(base) Thigh" }
        if description.contains("leg") || description.contains("drumstick") { return "\(base) Leg" }
        if description.contains("wing") { return "\(base) Wing" }
        if description.contains("liver") { return "\(base) Liver" }
        if description.contains("gizzard") { return "\(base) Gizzard" }
        if description.contains("ground") { return "Ground \(base)" }
        return description.contains(base.lowercased()) ? base : nil
    }

    private static func isBeanLike(description: String) -> Bool {
        let beanTerms = [
            "beans", "bean,", "bean ", "lentils", "lentil", "garbanzo",
            "chickpea", "chickpeas", "hummus",
        ]
        return beanTerms.contains(where: { description.contains($0) })
    }

    private static func isRiceLike(description: String) -> Bool {
        description.contains("rice") && !isFlourLike(description: description)
    }

    private static func isMilkLike(description: String) -> Bool {
        let milkTerms = [
            "milk,", "milk ", "buttermilk", "chocolate milk",
            "evaporated milk", "condensed milk",
        ]
        return milkTerms.contains(where: { description.contains($0) })
    }

    private static func isCheeseLike(description: String) -> Bool {
        let cheeseTerms = [
            "cheese", "cottage cheese", "cream cheese",
        ]
        return cheeseTerms.contains(where: { description.contains($0) })
    }

    private static func isYogurtLike(description: String) -> Bool {
        description.contains("yogurt") || description.contains("yoghurt")
    }

    private static func isFlourLike(description: String) -> Bool {
        description.contains("flour")
    }

    private static func isShellfishLike(description: String, components: [String]) -> Bool {
        let shellfishTerms = [
            "shellfish", "shrimp", "prawn", "crab", "lobster",
            "oyster", "clam", "mussel", "scallop",
        ]
        if shellfishTerms.contains(where: { description.contains($0) }) {
            return true
        }
        if let first = components.first?.lowercased() {
            return ["shellfish", "crustaceans", "mollusks"].contains(first)
        }
        return false
    }

    private static func isFishLike(description: String, components: [String]) -> Bool {
        let fishTerms = [
            "fish", "salmon", "tuna", "cod", "tilapia", "trout",
            "sardine", "sardines", "anchovy", "anchovies",
            "halibut", "herring", "mackerel", "perch", "snapper",
            "sole", "catfish", "mahi mahi", "sea bass", "seabass",
            "grouper", "pollock", "flounder", "haddock", "rockfish",
        ]
        if fishTerms.contains(where: { description.contains($0) }) {
            return true
        }
        return components.first?.lowercased() == "fish"
    }

    private static func meatDisplayName(description: String) -> String? {
        let proteins: [(String, String)] = [
            ("beef", "Beef"),
            ("pork", "Pork"),
            ("lamb", "Lamb"),
            ("veal", "Veal"),
            ("bison", "Bison"),
            ("duck", "Duck"),
            ("goose", "Goose"),
        ]

        guard let protein = proteins.first(where: { description.contains($0.0) })?.1 else { return nil }

        if description.contains("ground") { return "Ground \(protein)" }
        if description.contains("liver") { return "\(protein) Liver" }
        if description.contains("rib") { return "\(protein) Rib" }
        if description.contains("loin") { return "\(protein) Loin" }
        if description.contains("shoulder") { return "\(protein) Shoulder" }
        if description.contains("leg") { return "\(protein) Leg" }
        if description.contains("chop") { return "\(protein) Chop" }
        if description.contains("steak") { return "\(protein) Steak" }
        if description.contains("roast") { return "\(protein) Roast" }
        return protein
    }

    private static func seafoodDisplayName(from components: [String]) -> String? {
        guard let first = components.first?.lowercased() else { return nil }
        guard ["fish", "shellfish", "crustaceans", "mollusks"].contains(first) else { return nil }
        guard components.count >= 2 else { return components.first }
        return components[1]
    }

    private static func genericDisplayName(from components: [String]) -> String? {
        guard let first = components.first else { return nil }
        let singularFirst = displayTitle(for: first)
        let firstLower = singularFirst.lowercased()
        let useSecondComponent = Set([
            "milk", "cheese", "yogurt", "rice", "bread", "pasta",
            "beans", "peas", "lentils", "nuts", "seeds", "oil",
            "oils", "cereal", "flour", "crackers",
        ])

        if useSecondComponent.contains(firstLower), components.count >= 2 {
            return "\(singularFirst) \(displayTitle(for: components[1]))"
        }

        return singularFirst
    }

    private static func significantBrowseComponents(from description: String) -> [String] {
        let ignoredPhrases = [
            "raw", "cooked", "roasted", "baked", "broiled", "fried", "boiled",
            "steamed", "grilled", "braised", "stewed", "microwaved",
            "with skin", "without skin", "meat and skin", "meat only",
            "broilers or fryers", "separable lean and fat", "lean and fat",
            "commercial", "commercially prepared", "with added vitamin a and vitamin d",
            "with salt", "without salt",
        ]

        return description
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { component in
                let lower = component.lowercased()
                return !lower.isEmpty && !ignoredPhrases.contains(lower)
            }
            .map { component in
                component
                    .split(separator: " ")
                    .map { displayTitle(for: String($0)) }
                    .joined(separator: " ")
            }
    }

    private static func displayTitle(for token: String) -> String {
        let canonical = FoodSearchQuery.canonicalToken(token)
        guard !canonical.isEmpty else { return token }
        return canonical.prefix(1).uppercased() + canonical.dropFirst()
    }

    private func load() async {
        isLoading = true
        loadError = nil
        guard let url = Bundle.main.url(forResource: Self.bundleName, withExtension: "json") else {
            loadError = "Food database file missing from app bundle."
            isLoading = false
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(FoodDataCentralFile.self, from: data)
            items = decoded.foundationFoods.enumerated().map { index, food in
                var dict: [Int: Double] = [:]
                for fn in food.foodNutrients {
                    if let amt = fn.resolvedAmount {
                        dict[fn.nutrient.id] = amt
                    }
                }
                let canonical = NutrientNormalization.canonicalizeNutrients(dict)
                return FoundationFoodItem(
                    id: index,
                    description: food.description,
                    fdcCategoryDescription: food.foodCategory?.description,
                    nutrientsPer100g: canonical
                )
            }
            isLoading = false
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }
}
