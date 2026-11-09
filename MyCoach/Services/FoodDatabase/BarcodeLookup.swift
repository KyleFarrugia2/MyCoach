import Foundation

/// Barcode → food lookup. Port of `web/src/engines/barcode.ts` (keep in sync).
///
/// Product data comes from Open Food Facts (https://openfoodfacts.org), an open, community-maintained
/// database (ODbL). Values are user-contributed, so scanned foods are always shown to the user to check
/// against the label before saving, and are never marked verified.
enum BarcodeLookup {
    static let attribution = "Product data from Open Food Facts (ODbL) — check it against the label."

    /// Digits only; accepts EAN-8, UPC-A (12), EAN-13 and GTIN-14 with a valid check digit.
    static func normalize(_ raw: String) -> String? {
        let code = raw.filter(\.isNumber).filter(\.isASCII)
        guard [8, 12, 13, 14].contains(code.count), isValidGTIN(code) else { return nil }
        return code
    }

    /// GS1 mod-10 check digit (weights 3,1,3,… from the right, excluding the check digit).
    static func isValidGTIN(_ code: String) -> Bool {
        let digits = code.compactMap { $0.wholeNumberValue }
        guard digits.count == code.count, digits.count >= 8, let check = digits.last else { return false }
        var sum = 0
        for (i, d) in digits.dropLast().reversed().enumerated() {
            sum += d * (i % 2 == 0 ? 3 : 1)
        }
        return (10 - sum % 10) % 10 == check
    }

    private static let allergenMap: [String: FoodAllergy] = [
        "en:milk": .dairy,
        "en:eggs": .eggs,
        "en:peanuts": .peanuts,
        "en:nuts": .treeNuts,
        "en:fish": .fish,
        "en:crustaceans": .shellfish,
        "en:molluscs": .shellfish,
        "en:gluten": .glutenWheat,
        "en:soybeans": .soy,
    ]

    struct ParsedProduct: Equatable, Sendable {
        var food: FoodItem
        /// All of calories, protein, carbs and fat were present.
        var complete: Bool
    }

    private static func number(_ value: Any?) -> Double? {
        let n: Double?
        if let v = value as? NSNumber {
            n = v.doubleValue
        } else if let v = value as? String {
            n = Double(v.replacingOccurrences(of: ",", with: "."))
        } else {
            n = nil
        }
        guard let n, n.isFinite, n >= 0 else { return nil }
        return n
    }

    private static func text(_ value: Any?) -> String? {
        guard let s = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    /// Map an Open Food Facts v2 product response to a per-100 g FoodItem.
    static func parseOpenFoodFacts(_ data: Data, barcode: String) -> ParsedProduct? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["status"] as? NSNumber)?.intValue == 1,
              let product = root["product"] as? [String: Any] else {
            return nil
        }
        let n = product["nutriments"] as? [String: Any] ?? [:]
        let kj = number(n["energy-kj_100g"]) ?? number(n["energy_100g"])
        let kcalRaw = number(n["energy-kcal_100g"]) ?? kj.map { $0 / 4.184 }
        let kcal = kcalRaw.map { ($0 * 10).rounded() / 10 }
        let protein = number(n["proteins_100g"])
        let carbs = number(n["carbohydrates_100g"])
        let fat = number(n["fat_100g"])
        let fibre = number(n["fiber_100g"])
        let brand = text(product["brands"])?
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let tags = product["allergens_tags"] as? [String] ?? []
        let allergens = Set(tags.compactMap { allergenMap[$0] })
        let name = text(product["product_name_en"]) ?? text(product["product_name"]) ?? text(product["generic_name"])
            ?? "Scanned product"

        let food = FoodItem(
            name: name,
            brand: brand,
            source: .barcode,
            servingDescription: "100 g",
            servingGrams: 100,
            calories: kcal,
            proteinGrams: protein,
            carbohydrateGrams: carbs,
            fatGrams: fat,
            fibreGrams: fibre,
            measurementState: .package,
            barcode: barcode,
            isCustom: true,
            isVerified: false,
            allergenTags: allergens
        )
        return ParsedProduct(food: food, complete: kcal != nil && protein != nil && carbs != nil && fat != nil)
    }

    /// Blank food for a barcode the database doesn't know — the user fills in the label.
    static func blankFood(barcode: String) -> FoodItem {
        FoodItem(
            name: "",
            source: .barcode,
            servingDescription: "100 g",
            servingGrams: 100,
            measurementState: .package,
            barcode: barcode,
            isCustom: true,
            isVerified: false
        )
    }
}

enum BarcodeLookupResult: Equatable, Sendable {
    case found(BarcodeLookup.ParsedProduct)
    case notFound
    case failed(String)
}

/// Fetches products from the Open Food Facts API. Sends only the barcode number — no user data, no API key.
struct OpenFoodFactsClient: Sendable {
    var session: URLSession = .shared

    func lookup(barcode: String) async -> BarcodeLookupResult {
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json")
        components?.queryItems = [
            URLQueryItem(name: "fields", value: "product_name,product_name_en,generic_name,brands,nutriments,allergens_tags"),
        ]
        guard let url = components?.url else { return .failed("Invalid barcode.") }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Open Food Facts asks API clients to identify the app.
        request.setValue("MyCoach-iOS/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 { return .notFound }
            guard (200..<300).contains(status) else {
                return .failed("Lookup failed (\(status)). Enter the label values instead.")
            }
            if let parsed = BarcodeLookup.parseOpenFoodFacts(data, barcode: barcode) {
                return .found(parsed)
            }
            return .notFound
        } catch {
            return .failed("Couldn't reach the product database. Enter the label values instead.")
        }
    }
}
