import Foundation

struct FoodItem: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var brand: String?
    var restaurant: String?
    var source: FoodSource
    var servingDescription: String
    var servingGrams: Double?
    var calories: Double?
    var proteinGrams: Double?
    var carbohydrateGrams: Double?
    var fatGrams: Double?
    var fibreGrams: Double?
    var measurementState: MeasurementState
    var barcode: String?
    var isCustom: Bool
    var isVerified: Bool
    var allergenTags: Set<FoodAllergy>
    var isFavorite: Bool

    enum FoodSource: String, Codable, Sendable {
        case bundledGeneric
        case verifiedAPI
        case brandedPackage
        case restaurant
        case customUser
        case barcode
    }

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        restaurant: String? = nil,
        source: FoodSource,
        servingDescription: String,
        servingGrams: Double? = nil,
        calories: Double? = nil,
        proteinGrams: Double? = nil,
        carbohydrateGrams: Double? = nil,
        fatGrams: Double? = nil,
        fibreGrams: Double? = nil,
        measurementState: MeasurementState,
        barcode: String? = nil,
        isCustom: Bool = false,
        isVerified: Bool = false,
        allergenTags: Set<FoodAllergy> = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.restaurant = restaurant
        self.source = source
        self.servingDescription = servingDescription
        self.servingGrams = servingGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fibreGrams = fibreGrams
        self.measurementState = measurementState
        self.barcode = barcode
        self.isCustom = isCustom
        self.isVerified = isVerified
        self.allergenTags = allergenTags
        self.isFavorite = isFavorite
    }

    var displaySubtitle: String {
        if let restaurant, !restaurant.isEmpty { return restaurant }
        if let brand, !brand.isEmpty { return brand }
        switch source {
        case .bundledGeneric: return "Generic Database"
        case .customUser: return "My Foods"
        case .verifiedAPI: return "Verified"
        case .brandedPackage: return "Branded"
        case .restaurant: return "Restaurant"
        case .barcode: return "Barcode"
        }
    }

    /// Per-gram nutrition when gram-based serving data exists. Unknown values stay nil.
    func nutritionPerGram() -> (calories: Double, protein: Double, carbs: Double, fat: Double)? {
        guard let grams = servingGrams, grams > 0,
              let calories, let proteinGrams, let carbohydrateGrams, let fatGrams else {
            return nil
        }
        return (
            calories / grams,
            proteinGrams / grams,
            carbohydrateGrams / grams,
            fatGrams / grams
        )
    }

    func scaled(toGrams grams: Double) -> (calories: Double, macros: MacroGrams)? {
        guard let per = nutritionPerGram() else { return nil }
        return (
            per.calories * grams,
            MacroGrams(
                protein: per.protein * grams,
                carbohydrates: per.carbs * grams,
                fat: per.fat * grams
            )
        )
    }

    var measurementLabel: String {
        "\(measurementState.displayName) · \(servingDescription)"
    }
}

struct FoodServing: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var foodID: UUID
    var label: String
    var grams: Double?
    var multiplier: Double

    init(id: UUID = UUID(), foodID: UUID, label: String, grams: Double? = nil, multiplier: Double = 1) {
        self.id = id
        self.foodID = foodID
        self.label = label
        self.grams = grams
        self.multiplier = multiplier
    }
}

struct FoodLogEntry: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var localDate: Date
    var mealSlot: MealSlot
    var food: FoodItem
    /// Grams when scalable; otherwise number of servings.
    var amount: Double
    var amountIsServings: Bool
    /// Prefer provider/manufacturer calories when available.
    var loggedCalories: Double
    var loggedMacros: MacroGrams
    var createdAt: Date
    var updatedAt: Date
    var notes: String

    init(
        id: UUID = UUID(),
        localDate: Date,
        mealSlot: MealSlot,
        food: FoodItem,
        amount: Double,
        amountIsServings: Bool,
        loggedCalories: Double,
        loggedMacros: MacroGrams,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.localDate = localDate
        self.mealSlot = mealSlot
        self.food = food
        self.amount = amount
        self.amountIsServings = amountIsServings
        self.loggedCalories = loggedCalories
        self.loggedMacros = loggedMacros
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notes = notes
    }
}

struct DailyFoodDiary: Codable, Equatable, Sendable, Identifiable {
    var id: Date { localDate }
    var localDate: Date
    var entries: [FoodLogEntry]
    var markedComplete: Bool

    var totalCalories: Double {
        entries.reduce(0) { $0 + $1.loggedCalories }
    }

    var totalMacros: MacroGrams {
        entries.reduce(.zero) { $0 + $1.loggedMacros }
    }
}

struct MealItem: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var food: FoodItem
    var grams: Double?
    var servings: Double?
    var isLocked: Bool
    var calories: Double
    var macros: MacroGrams

    init(
        id: UUID = UUID(),
        food: FoodItem,
        grams: Double? = nil,
        servings: Double? = nil,
        isLocked: Bool = false,
        calories: Double,
        macros: MacroGrams
    ) {
        self.id = id
        self.food = food
        self.grams = grams
        self.servings = servings
        self.isLocked = isLocked
        self.calories = calories
        self.macros = macros
    }

    var quantityLabel: String {
        if let grams {
            let rounded = (grams * 10).rounded() / 10
            // State word only where weight changes with cooking: raw / dry / cooked.
            let state: String
            switch food.measurementState {
            case .raw, .dry, .cooked: state = "\(food.measurementState.displayName.lowercased()) "
            default: state = ""
            }
            return "\(rounded.formatted(.number.precision(.fractionLength(0...1)))) g \(state)\(food.name)"
        }
        if let servings {
            return "\(servings.formatted(.number.precision(.fractionLength(0...2)))) × \(food.servingDescription)"
        }
        return food.name
    }
}

struct Meal: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var slot: MealSlot
    var name: String
    var scheduledTimeMinutes: Int?
    var items: [MealItem]
    /// Planner recipe this meal was built from (used to offer the next alternative on "Swap meal").
    var recipeID: String?

    init(
        id: UUID = UUID(),
        slot: MealSlot,
        name: String? = nil,
        scheduledTimeMinutes: Int? = nil,
        items: [MealItem] = [],
        recipeID: String? = nil
    ) {
        self.id = id
        self.slot = slot
        self.name = name ?? slot.displayName
        self.scheduledTimeMinutes = scheduledTimeMinutes
        self.items = items
        self.recipeID = recipeID
    }

    var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    var totalMacros: MacroGrams { items.reduce(.zero) { $0 + $1.macros } }

    var timeLabel: String? {
        guard let scheduledTimeMinutes else { return nil }
        let hours = scheduledTimeMinutes / 60
        let minutes = scheduledTimeMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

struct MealPlanDay: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var localDate: Date
    var weekday: Weekday
    var isTrainingDay: Bool
    var target: DailyNutritionTarget
    var meals: [Meal]
    var solverMessage: String?

    init(
        id: UUID = UUID(),
        localDate: Date,
        weekday: Weekday,
        isTrainingDay: Bool,
        target: DailyNutritionTarget,
        meals: [Meal] = [],
        solverMessage: String? = nil
    ) {
        self.id = id
        self.localDate = localDate
        self.weekday = weekday
        self.isTrainingDay = isTrainingDay
        self.target = target
        self.meals = meals
        self.solverMessage = solverMessage
    }

    var totalCalories: Double { meals.reduce(0) { $0 + $1.totalCalories } }
    var totalMacros: MacroGrams { meals.reduce(.zero) { $0 + $1.totalMacros } }
}

struct RefeedPlan: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var scheduledDate: Date?
    var normalTarget: DailyNutritionTarget
    var refeedTarget: DailyNutritionTarget
    var reason: String
    var accepted: Bool

    init(
        id: UUID = UUID(),
        scheduledDate: Date? = nil,
        normalTarget: DailyNutritionTarget,
        refeedTarget: DailyNutritionTarget,
        reason: String,
        accepted: Bool = false
    ) {
        self.id = id
        self.scheduledDate = scheduledDate
        self.normalTarget = normalTarget
        self.refeedTarget = refeedTarget
        self.reason = reason
        self.accepted = accepted
    }
}
