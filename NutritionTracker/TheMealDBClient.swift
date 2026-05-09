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
        struct Ingredient: Hashable {
            let name: String
            let measure: String
        }

        let idMeal: String
        let strMeal: String
        let ingredients: [Ingredient]

        var id: String { idMeal }

        var ingredientLines: [String] {
            ingredients.map { item in
                if item.measure.isEmpty { return item.name }
                return "\(item.measure) \(item.name)"
            }
        }

        private enum CodingKeys: String, CodingKey {
            case idMeal
            case strMeal
        }

        private struct NumberedMealDetailKey: CodingKey {
            let stringValue: String
            let intValue: Int?

            init?(stringValue: String) {
                self.stringValue = stringValue
                self.intValue = nil
            }

            init?(intValue: Int) {
                self.stringValue = String(intValue)
                self.intValue = intValue
            }
        }

        init(from decoder: Decoder) throws {
            let base = try decoder.container(keyedBy: CodingKeys.self)
            idMeal = try base.decode(String.self, forKey: .idMeal)
            strMeal = try base.decode(String.self, forKey: .strMeal)

            let numbered = try decoder.container(keyedBy: NumberedMealDetailKey.self)
            ingredients = Self.decodeIngredients(from: numbered)
        }

        private static func decodeIngredients(
            from container: KeyedDecodingContainer<NumberedMealDetailKey>
        ) -> [Ingredient] {
            var decoded: [Ingredient] = []
            decoded.reserveCapacity(20)

            for index in 1...20 {
                let name = decodeString(from: container, key: "strIngredient\(index)")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }

                let measure = decodeString(from: container, key: "strMeasure\(index)")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                decoded.append(Ingredient(name: name, measure: measure))
            }

            return decoded
        }

        private static func decodeString(
            from container: KeyedDecodingContainer<NumberedMealDetailKey>,
            key: String
        ) -> String {
            guard let codingKey = NumberedMealDetailKey(stringValue: key) else { return "" }
            return (try? container.decodeIfPresent(String.self, forKey: codingKey)) ?? ""
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
