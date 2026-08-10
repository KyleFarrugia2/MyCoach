import Foundation

// MARK: - Protocol

protocol FoodCatalogProvider: Sendable {
    var isAvailable: Bool { get }
    func search(query: String) async -> [FoodItem]
    func food(id: UUID) async -> FoodItem?
    func favorites() async -> [FoodItem]
}

extension FoodCatalogProvider {
    var isAvailable: Bool { true }
}

// MARK: - Bundled catalog

/// Local generic bodybuilding staples with realistic USDA-style values.
/// Dry vs cooked rice (and similar) are **separate** entries — never conflate measurement states.
struct BundledFoodCatalog: FoodCatalogProvider {
    let isAvailable = true

    private let foods: [FoodItem]
    private let byID: [UUID: FoodItem]

    init() {
        let catalog = Self.makeCatalog()
        self.foods = catalog
        self.byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }

    func search(query: String) async -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return foods }
        let tokens = trimmed.lowercased().split(separator: " ").map(String.init)
        return foods.filter { item in
            let haystack = [
                item.name,
                item.brand ?? "",
                item.servingDescription,
                item.measurementState.displayName
            ].joined(separator: " ").lowercased()
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }

    func food(id: UUID) async -> FoodItem? {
        byID[id]
    }

    func favorites() async -> [FoodItem] {
        foods.filter(\.isFavorite)
    }

    // Stable UUIDs so meal plans / logs remain consistent across launches.
    private static func id(_ hex: String) -> UUID {
        UUID(uuidString: hex)!
    }

    private static func item(
        id: UUID,
        name: String,
        servingDescription: String,
        servingGrams: Double,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fibre: Double? = nil,
        state: MeasurementState,
        allergens: Set<FoodAllergy> = [],
        favorite: Bool = false
    ) -> FoodItem {
        FoodItem(
            id: id,
            name: name,
            brand: nil,
            restaurant: nil,
            source: .bundledGeneric,
            servingDescription: servingDescription,
            servingGrams: servingGrams,
            calories: calories,
            proteinGrams: protein,
            carbohydrateGrams: carbs,
            fatGrams: fat,
            fibreGrams: fibre,
            measurementState: state,
            barcode: nil,
            isCustom: false,
            isVerified: true,
            allergenTags: allergens,
            isFavorite: favorite
        )
    }

    /// Values are per listed serving (typically 100 g) from commonly cited generic references.
    private static func makeCatalog() -> [FoodItem] {
        [
            // Proteins
            item(
                id: id("A1000001-0001-4000-8000-000000000001"),
                name: "Chicken Breast",
                servingDescription: "100 g raw",
                servingGrams: 100,
                calories: 110,
                protein: 23.1,
                carbs: 0,
                fat: 1.2,
                state: .raw,
                favorite: true
            ),
            item(
                id: id("A1000001-0001-4000-8000-000000000002"),
                name: "Chicken Breast",
                servingDescription: "100 g cooked",
                servingGrams: 100,
                calories: 165,
                protein: 31.0,
                carbs: 0,
                fat: 3.6,
                state: .cooked,
                favorite: true
            ),
            item(
                id: id("A1000001-0001-4000-8000-000000000003"),
                name: "Lean Beef (5% fat)",
                servingDescription: "100 g raw",
                servingGrams: 100,
                calories: 137,
                protein: 21.4,
                carbs: 0,
                fat: 5.0,
                state: .raw
            ),
            item(
                id: id("A1000001-0001-4000-8000-000000000004"),
                name: "Lean Beef (5% fat)",
                servingDescription: "100 g cooked",
                servingGrams: 100,
                calories: 176,
                protein: 26.0,
                carbs: 0,
                fat: 8.0,
                state: .cooked
            ),
            item(
                id: id("A1000001-0001-4000-8000-000000000005"),
                name: "Turkey Breast",
                servingDescription: "100 g raw",
                servingGrams: 100,
                calories: 104,
                protein: 24.0,
                carbs: 0,
                fat: 0.7,
                state: .raw
            ),
            item(
                id: id("A1000001-0001-4000-8000-000000000006"),
                name: "White Fish (cod)",
                servingDescription: "100 g raw",
                servingGrams: 100,
                calories: 82,
                protein: 17.8,
                carbs: 0,
                fat: 0.7,
                state: .raw,
                allergens: [.fish]
            ),
            item(
                id: id("A1000001-0001-4000-8000-000000000007"),
                name: "Egg",
                servingDescription: "1 large (50 g edible)",
                servingGrams: 50,
                calories: 72,
                protein: 6.3,
                carbs: 0.4,
                fat: 4.8,
                state: .raw,
                allergens: [.eggs],
                favorite: true
            ),
            item(
                id: id("A1000001-0001-4000-8000-000000000008"),
                name: "Egg Whites",
                servingDescription: "100 g liquid",
                servingGrams: 100,
                calories: 52,
                protein: 10.9,
                carbs: 0.7,
                fat: 0.2,
                state: .raw,
                allergens: [.eggs],
                favorite: true
            ),
            item(
                id: id("A1000001-0001-4000-8000-000000000009"),
                name: "Greek Yogurt (0% fat)",
                servingDescription: "100 g",
                servingGrams: 100,
                calories: 59,
                protein: 10.3,
                carbs: 3.6,
                fat: 0.4,
                state: .prepared,
                allergens: [.dairy],
                favorite: true
            ),
            item(
                id: id("A1000001-0001-4000-8000-00000000000A"),
                name: "Cottage Cheese (low fat)",
                servingDescription: "100 g",
                servingGrams: 100,
                calories: 72,
                protein: 12.4,
                carbs: 2.7,
                fat: 1.0,
                state: .prepared,
                allergens: [.dairy]
            ),
            item(
                id: id("A1000001-0001-4000-8000-00000000000B"),
                name: "Whey Protein Powder",
                servingDescription: "30 g scoop",
                servingGrams: 30,
                calories: 120,
                protein: 24.0,
                carbs: 2.0,
                fat: 1.5,
                state: .serving,
                allergens: [.dairy]
            ),
            item(
                id: id("A1000001-0001-4000-8000-00000000000C"),
                name: "Tuna (canned in water, drained)",
                servingDescription: "100 g",
                servingGrams: 100,
                calories: 86,
                protein: 19.0,
                carbs: 0,
                fat: 1.0,
                state: .prepared,
                allergens: [.fish]
            ),

            // Carbs — dry and cooked are SEPARATE
            item(
                id: id("A1000002-0001-4000-8000-000000000001"),
                name: "White Rice",
                servingDescription: "100 g dry",
                servingGrams: 100,
                calories: 365,
                protein: 7.1,
                carbs: 80.0,
                fat: 0.7,
                fibre: 1.3,
                state: .dry,
                favorite: true
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000002"),
                name: "White Rice",
                servingDescription: "100 g cooked",
                servingGrams: 100,
                calories: 130,
                protein: 2.7,
                carbs: 28.2,
                fat: 0.3,
                fibre: 0.4,
                state: .cooked,
                favorite: true
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000003"),
                name: "Brown Rice",
                servingDescription: "100 g dry",
                servingGrams: 100,
                calories: 370,
                protein: 7.9,
                carbs: 77.2,
                fat: 2.9,
                fibre: 3.5,
                state: .dry
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000004"),
                name: "Brown Rice",
                servingDescription: "100 g cooked",
                servingGrams: 100,
                calories: 112,
                protein: 2.3,
                carbs: 23.5,
                fat: 0.8,
                fibre: 1.8,
                state: .cooked
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000005"),
                name: "Potato",
                servingDescription: "100 g raw",
                servingGrams: 100,
                calories: 77,
                protein: 2.0,
                carbs: 17.5,
                fat: 0.1,
                fibre: 2.1,
                state: .raw
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000006"),
                name: "Potato",
                servingDescription: "100 g boiled",
                servingGrams: 100,
                calories: 87,
                protein: 1.9,
                carbs: 20.1,
                fat: 0.1,
                fibre: 1.8,
                state: .cooked
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000007"),
                name: "Sweet Potato",
                servingDescription: "100 g raw",
                servingGrams: 100,
                calories: 86,
                protein: 1.6,
                carbs: 20.1,
                fat: 0.1,
                fibre: 3.0,
                state: .raw
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000008"),
                name: "Pasta",
                servingDescription: "100 g dry",
                servingGrams: 100,
                calories: 371,
                protein: 13.0,
                carbs: 74.7,
                fat: 1.5,
                fibre: 3.2,
                state: .dry,
                allergens: [.glutenWheat],
                favorite: true
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000009"),
                name: "Pasta",
                servingDescription: "100 g cooked",
                servingGrams: 100,
                calories: 131,
                protein: 5.0,
                carbs: 25.0,
                fat: 1.1,
                fibre: 1.8,
                state: .cooked,
                allergens: [.glutenWheat]
            ),
            item(
                id: id("A1000002-0001-4000-8000-00000000000A"),
                name: "Oats (rolled)",
                servingDescription: "100 g dry",
                servingGrams: 100,
                calories: 389,
                protein: 16.9,
                carbs: 66.3,
                fat: 6.9,
                fibre: 10.6,
                state: .dry,
                allergens: [.glutenWheat],
                favorite: true
            ),
            item(
                id: id("A1000002-0001-4000-8000-00000000000B"),
                name: "Oats (rolled)",
                servingDescription: "100 g cooked with water",
                servingGrams: 100,
                calories: 71,
                protein: 2.5,
                carbs: 12.0,
                fat: 1.5,
                fibre: 1.7,
                state: .cooked,
                allergens: [.glutenWheat]
            ),
            item(
                id: id("A1000002-0001-4000-8000-00000000000C"),
                name: "Bread (white)",
                servingDescription: "1 slice (30 g)",
                servingGrams: 30,
                calories: 79,
                protein: 2.7,
                carbs: 14.7,
                fat: 1.0,
                fibre: 0.8,
                state: .prepared,
                allergens: [.glutenWheat]
            ),
            item(
                id: id("A1000002-0001-4000-8000-00000000000D"),
                name: "Banana",
                servingDescription: "100 g edible",
                servingGrams: 100,
                calories: 89,
                protein: 1.1,
                carbs: 22.8,
                fat: 0.3,
                fibre: 2.6,
                state: .raw,
                favorite: true
            ),
            item(
                id: id("A1000002-0001-4000-8000-00000000000E"),
                name: "Apple",
                servingDescription: "100 g edible",
                servingGrams: 100,
                calories: 52,
                protein: 0.3,
                carbs: 13.8,
                fat: 0.2,
                fibre: 2.4,
                state: .raw
            ),
            item(
                id: id("A1000002-0001-4000-8000-00000000000F"),
                name: "Mixed Berries",
                servingDescription: "100 g",
                servingGrams: 100,
                calories: 57,
                protein: 0.7,
                carbs: 14.5,
                fat: 0.3,
                fibre: 2.4,
                state: .raw
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000010"),
                name: "Mixed Vegetables",
                servingDescription: "100 g raw",
                servingGrams: 100,
                calories: 35,
                protein: 2.0,
                carbs: 7.0,
                fat: 0.2,
                fibre: 2.5,
                state: .raw
            ),
            item(
                id: id("A1000002-0001-4000-8000-000000000011"),
                name: "Broccoli",
                servingDescription: "100 g raw",
                servingGrams: 100,
                calories: 34,
                protein: 2.8,
                carbs: 6.6,
                fat: 0.4,
                fibre: 2.6,
                state: .raw
            ),

            // Fats
            item(
                id: id("A1000003-0001-4000-8000-000000000001"),
                name: "Peanut Butter",
                servingDescription: "32 g (2 tbsp)",
                servingGrams: 32,
                calories: 188,
                protein: 8.0,
                carbs: 6.0,
                fat: 16.0,
                fibre: 2.0,
                state: .serving,
                allergens: [.peanuts],
                favorite: true
            ),
            item(
                id: id("A1000003-0001-4000-8000-000000000002"),
                name: "Olive Oil",
                servingDescription: "14 g (1 tbsp)",
                servingGrams: 14,
                calories: 119,
                protein: 0,
                carbs: 0,
                fat: 13.5,
                state: .serving
            ),
            item(
                id: id("A1000003-0001-4000-8000-000000000003"),
                name: "Almonds",
                servingDescription: "28 g (1 oz)",
                servingGrams: 28,
                calories: 164,
                protein: 6.0,
                carbs: 6.1,
                fat: 14.2,
                fibre: 3.5,
                state: .serving,
                allergens: [.treeNuts]
            ),
            item(
                id: id("A1000003-0001-4000-8000-000000000004"),
                name: "Avocado",
                servingDescription: "100 g edible",
                servingGrams: 100,
                calories: 160,
                protein: 2.0,
                carbs: 8.5,
                fat: 14.7,
                fibre: 6.7,
                state: .raw
            ),

            // Intra / supplements
            item(
                id: id("A1000004-0001-4000-8000-000000000001"),
                name: "Dextrose",
                servingDescription: "100 g powder",
                servingGrams: 100,
                calories: 380,
                protein: 0,
                carbs: 95.0,
                fat: 0,
                state: .dry,
                favorite: true
            ),
            item(
                id: id("A1000004-0001-4000-8000-000000000002"),
                name: "Essential Amino Acids (EAAs)",
                servingDescription: "10 g serving",
                servingGrams: 10,
                calories: 40,
                protein: 10.0,
                carbs: 0,
                fat: 0,
                state: .serving,
                favorite: true
            ),
            item(
                id: id("A1000004-0001-4000-8000-000000000003"),
                name: "Creatine Monohydrate",
                servingDescription: "5 g",
                servingGrams: 5,
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                state: .serving
            ),
        ]
    }
}

// MARK: - Composite (bundled + custom)

/// Merges bundled generics with user-created custom foods. Custom overrides same ID.
struct CompositeFoodCatalog: FoodCatalogProvider {
    let isAvailable = true

    private let bundled: BundledFoodCatalog
    private let customProvider: @Sendable () async -> [FoodItem]

    init(
        bundled: BundledFoodCatalog = BundledFoodCatalog(),
        customProvider: @escaping @Sendable () async -> [FoodItem]
    ) {
        self.bundled = bundled
        self.customProvider = customProvider
    }

    func search(query: String) async -> [FoodItem] {
        let custom = await customProvider()
        let bundledHits = await bundled.search(query: query)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let customHits: [FoodItem]
        if trimmed.isEmpty {
            customHits = custom
        } else {
            let tokens = trimmed.split(separator: " ").map(String.init)
            customHits = custom.filter { item in
                let haystack = [item.name, item.brand ?? "", item.servingDescription]
                    .joined(separator: " ")
                    .lowercased()
                return tokens.allSatisfy { haystack.contains($0) }
            }
        }
        // Custom first so user recipes surface ahead of generics with similar names.
        return dedupe(customHits + bundledHits)
    }

    func food(id: UUID) async -> FoodItem? {
        let custom = await customProvider()
        if let hit = custom.first(where: { $0.id == id }) { return hit }
        return await bundled.food(id: id)
    }

    func favorites() async -> [FoodItem] {
        let custom = await customProvider()
        let bundledFavs = await bundled.favorites()
        return dedupe(custom.filter(\.isFavorite) + bundledFavs)
    }

    private func dedupe(_ items: [FoodItem]) -> [FoodItem] {
        var seen = Set<UUID>()
        var result: [FoodItem] = []
        for item in items where seen.insert(item.id).inserted {
            result.append(item)
        }
        return result
    }
}

// MARK: - Online stub (no credentials)

/// Placeholder for a future verified online food API.
/// **Unavailable** without API credentials — returns empty results and never invents restaurant data.
struct OnlineFoodCatalogStub: FoodCatalogProvider {
    /// Explicitly false until a real API client is configured with credentials.
    let isAvailable = false

    /// Human-readable reason for UI empty states.
    let unavailableReason =
        "Online food search is unavailable. API credentials are not configured. Use the bundled generic database or add a custom food."

    func search(query: String) async -> [FoodItem] {
        // Intentionally empty — do not invent branded, restaurant, or scraped data.
        _ = query
        return []
    }

    func food(id: UUID) async -> FoodItem? {
        _ = id
        return nil
    }

    func favorites() async -> [FoodItem] {
        []
    }
}
