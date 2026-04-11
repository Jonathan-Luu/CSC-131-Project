import Foundation

// MARK: - USDA browse groups (broad → optional meat sub-filter)

/// High-level buckets derived from FDC `foodCategory.description` strings in the bundled JSON.
enum FoodBrowseGroup: String, CaseIterable, Identifiable {
    case all = "All foods"
    case meatPoultry = "Meat & poultry"
    case dairyEggs = "Dairy & eggs"
    case grainsBakery = "Grains & bakery"
    case vegetables = "Vegetables"
    case fruits = "Fruits"
    case legumes = "Legumes"
    case seafood = "Seafood"
    case fatsOils = "Fats & oils"
    case snacksSweets = "Snacks & sweets"
    case other = "Other"

    var id: String { rawValue }

    /// Maps an FDC category line (e.g. `"Poultry Products"`) to a browse group.
    static func from(fdcCategoryDescription: String?) -> FoodBrowseGroup {
        guard let c = fdcCategoryDescription?.lowercased() else { return .other }
        if c.contains("vegetable") { return .vegetables }
        if c.contains("fruit") { return .fruits }
        if c.contains("dairy") || c.contains("egg") { return .dairyEggs }
        if c.contains("legume") { return .legumes }
        if c.contains("finfish") || c.contains("shellfish") { return .seafood }
        if c.contains("poultry")
            || c.contains("sausage")
            || c.contains("pork")
            || c.contains("beef")
            || c.contains("veal")
            || c.contains("lamb")
            || c.contains("game")
        { return .meatPoultry }
        if c.contains("cereal") || c.contains("baked") || c.contains("pasta") || c.contains("grain") || c.contains("rice") {
            return .grainsBakery
        }
        if c.contains("oil") || c.contains("fat") { return .fatsOils }
        if c.contains("snack") || c.contains("sweet") || c.contains("candy") || c.contains("chocolate") {
            return .snacksSweets
        }
        if c.contains("nut") || c.contains("seed") { return .snacksSweets }
        return .other
    }
}

/// Narrowing options inside **Meat & poultry** (keyword match on food description).
enum FoodMeatSubfilter: String, CaseIterable, Identifiable {
    case all = "All in group"
    case chicken = "Chicken"
    case beef = "Beef"
    case pork = "Pork"
    case turkey = "Turkey"
    case lamb = "Lamb"

    var id: String { rawValue }

    func matchesDescription(_ description: String) -> Bool {
        let d = description.lowercased()
        switch self {
        case .all:
            return true
        case .chicken:
            return d.contains("chicken")
        case .beef:
            return d.contains("beef") || d.contains("bison")
        case .pork:
            return d.contains("pork")
        case .turkey:
            return d.contains("turkey")
        case .lamb:
            return d.contains("lamb")
        }
    }
}

// MARK: - Query normalization & ranking

enum FoodSearchQuery {
    /// Splits on non-alphanumeric; drops empty pieces; ignores 1-character tokens to reduce noise.
    static func tokens(from raw: String) -> [String] {
        let parts = raw
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
        return parts
    }

    /// Every token must appear somewhere in the description or FDC category (forgiving AND).
    static func matchesAllTokens(
        description: String,
        fdcCategory: String?,
        tokens: [String]
    ) -> Bool {
        guard !tokens.isEmpty else { return true }
        let hay = (description + " " + (fdcCategory ?? "")).lowercased()
        return tokens.allSatisfy { hay.contains($0) }
    }

    /// Higher = better. Prefers full-string match, then token hits, then earlier / shorter names.
    static func relevanceScore(
        description: String,
        fdcCategory: String?,
        normalizedQuery: String,
        tokens: [String]
    ) -> Int {
        let lower = description.lowercased()
        let cat = (fdcCategory ?? "").lowercased()
        let q = normalizedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var score = 0

        if !q.isEmpty {
            if lower.contains(q) { score += 10_000 }
            if lower.hasPrefix(q) { score += 5_000 }
            if cat.contains(q) { score += 2_000 }
        }

        for t in tokens {
            if lower.contains(t) {
                score += 1_000
                if lower.hasPrefix(t) { score += 400 }
                if let range = lower.range(of: t) {
                    if range.lowerBound == lower.startIndex {
                        score += 200
                    } else {
                        let beforeIdx = lower.index(before: range.lowerBound)
                        if !lower[beforeIdx].isLetter {
                            score += 200
                        }
                    }
                }
            } else if cat.contains(t) {
                score += 400
            }
        }

        score -= min(description.count, 200)
        return score
    }
}
