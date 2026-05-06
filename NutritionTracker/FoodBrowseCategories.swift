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
        raw
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
            .map(canonicalToken)
    }

    static func normalizedText(from raw: String) -> String {
        tokens(from: raw).joined(separator: " ")
    }

    /// Every token must appear somewhere in the description or FDC category (forgiving AND).
    static func matchesAllTokens(
        description: String,
        fdcCategory: String?,
        tokens: [String]
    ) -> Bool {
        guard !tokens.isEmpty else { return true }
        let hayTokens = Set(self.tokens(from: description + " " + (fdcCategory ?? "")))
        return tokens.allSatisfy { hayTokens.contains($0) }
    }

    /// Higher = better. Prefers full-string match, then token hits, then earlier / shorter names.
    static func relevanceScore(
        description: String,
        fdcCategory: String?,
        normalizedQuery: String,
        tokens: [String]
    ) -> Int {
        let normalizedDescription = normalizedText(from: description)
        let normalizedCategory = normalizedText(from: fdcCategory ?? "")
        let descriptionTokens = self.tokens(from: description)
        let categoryTokens = Set(self.tokens(from: fdcCategory ?? ""))
        let q = normalizedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var score = 0

        if !q.isEmpty {
            if normalizedDescription.contains(q) { score += 10_000 }
            if normalizedDescription.hasPrefix(q) { score += 5_000 }
            if normalizedCategory.contains(q) { score += 2_000 }
        }

        for t in tokens {
            if descriptionTokens.contains(t) {
                score += 1_000
                if descriptionTokens.first == t { score += 600 }
            } else if categoryTokens.contains(t) {
                score += 400
            }
        }

        score -= min(description.count, 200)
        return score
    }

    static func canonicalToken(_ raw: String) -> String {
        let lower = raw.lowercased()

        if lower.count <= 3 {
            return lower
        }

        if lower.hasSuffix("ies"), lower.count > 4 {
            return String(lower.dropLast(3)) + "y"
        }

        if lower.hasSuffix("oes"), lower.count > 4 {
            return String(lower.dropLast(2))
        }

        if lower.hasSuffix("ches")
            || lower.hasSuffix("shes")
            || lower.hasSuffix("sses")
            || lower.hasSuffix("xes")
            || lower.hasSuffix("zes")
        {
            return String(lower.dropLast(2))
        }

        if lower.hasSuffix("s"),
           !lower.hasSuffix("ss"),
           !lower.hasSuffix("us"),
           !lower.hasSuffix("is")
        {
            return String(lower.dropLast())
        }

        return lower
    }
}
