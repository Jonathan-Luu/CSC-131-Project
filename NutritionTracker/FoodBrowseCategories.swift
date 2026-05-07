import Foundation

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
