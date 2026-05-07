import Foundation

/// Lightweight wrapper for TheMealDB (`themealdb.com`) endpoints used in this app.
struct TheMealDBClient {
    struct Meal: Identifiable, Decodable, Hashable {
        let idMeal: String
        let strMeal: String
        let strMealThumb: String?
        var id: String { idMeal }
    }

    struct MealDetail: Identifiable, Decodable, Hashable {
        let idMeal: String
        let strMeal: String

        // Ingredient slots (TheMealDB uses numbered keys)
        let strIngredient1: String?
        let strIngredient2: String?
        let strIngredient3: String?
        let strIngredient4: String?
        let strIngredient5: String?
        let strIngredient6: String?
        let strIngredient7: String?
        let strIngredient8: String?
        let strIngredient9: String?
        let strIngredient10: String?
        let strIngredient11: String?
        let strIngredient12: String?
        let strIngredient13: String?
        let strIngredient14: String?
        let strIngredient15: String?
        let strIngredient16: String?
        let strIngredient17: String?
        let strIngredient18: String?
        let strIngredient19: String?
        let strIngredient20: String?

        let strMeasure1: String?
        let strMeasure2: String?
        let strMeasure3: String?
        let strMeasure4: String?
        let strMeasure5: String?
        let strMeasure6: String?
        let strMeasure7: String?
        let strMeasure8: String?
        let strMeasure9: String?
        let strMeasure10: String?
        let strMeasure11: String?
        let strMeasure12: String?
        let strMeasure13: String?
        let strMeasure14: String?
        let strMeasure15: String?
        let strMeasure16: String?
        let strMeasure17: String?
        let strMeasure18: String?
        let strMeasure19: String?
        let strMeasure20: String?

        var id: String { idMeal }

        var ingredientLines: [String] {
            ingredientPairs.map { ing, measure in
                let m = measure.trimmingCharacters(in: .whitespacesAndNewlines)
                if m.isEmpty { return ing }
                return "\(m) \(ing)"
            }
        }

        var ingredientPairs: [(ingredient: String, measure: String)] {
            let ingredients: [String?] = [
                strIngredient1, strIngredient2, strIngredient3, strIngredient4, strIngredient5,
                strIngredient6, strIngredient7, strIngredient8, strIngredient9, strIngredient10,
                strIngredient11, strIngredient12, strIngredient13, strIngredient14, strIngredient15,
                strIngredient16, strIngredient17, strIngredient18, strIngredient19, strIngredient20,
            ]
            let measures: [String?] = [
                strMeasure1, strMeasure2, strMeasure3, strMeasure4, strMeasure5,
                strMeasure6, strMeasure7, strMeasure8, strMeasure9, strMeasure10,
                strMeasure11, strMeasure12, strMeasure13, strMeasure14, strMeasure15,
                strMeasure16, strMeasure17, strMeasure18, strMeasure19, strMeasure20,
            ]

            var out: [(String, String)] = []
            out.reserveCapacity(20)
            for i in 0..<min(ingredients.count, measures.count) {
                let ing = ingredients[i]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !ing.isEmpty else { continue }
                let measure = measures[i]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                out.append((ing, measure))
            }
            return out
        }
    }

    enum ClientError: Error {
        case invalidURL
        case badResponse
        case notFound
    }

    private struct MealsResponse<T: Decodable>: Decodable {
        let meals: [T]?
    }

    func searchMealsByName(_ query: String) async throws -> [Meal] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var components = URLComponents(string: "https://www.themealdb.com/api/json/v1/1/search.php")
        components?.queryItems = [URLQueryItem(name: "s", value: q)]
        guard let url = components?.url else { throw ClientError.invalidURL }
        let decoded: MealsResponse<Meal> = try await fetch(url)
        return decoded.meals ?? []
    }

    /// Returns a list of meals that include the given ingredient.
    func filterMealsByIngredient(_ ingredient: String) async throws -> [Meal] {
        let q = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var components = URLComponents(string: "https://www.themealdb.com/api/json/v1/1/filter.php")
        components?.queryItems = [URLQueryItem(name: "i", value: q)]
        guard let url = components?.url else { throw ClientError.invalidURL }
        let decoded: MealsResponse<Meal> = try await fetch(url)
        return decoded.meals ?? []
    }

    func lookupMealDetail(idMeal: String) async throws -> MealDetail {
        let q = idMeal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { throw ClientError.notFound }
        var components = URLComponents(string: "https://www.themealdb.com/api/json/v1/1/lookup.php")
        components?.queryItems = [URLQueryItem(name: "i", value: q)]
        guard let url = components?.url else { throw ClientError.invalidURL }
        let decoded: MealsResponse<MealDetail> = try await fetch(url)
        guard let detail = decoded.meals?.first else { throw ClientError.notFound }
        return detail
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ClientError.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

