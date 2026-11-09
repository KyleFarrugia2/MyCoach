import Foundation

/// Practical meal planner. Line-for-line port of `web/src/engines/mealPlanner.ts` (the reference) —
/// keep numerically identical; `MealPlannerTests` checks this port against `MealPlannerFixture`.
///
/// Rules (new plans, regenerated plans and swaps):
///  - Protein target = 1 g per lb of current bodyweight (nutrition engine); the plan must meet it.
///  - Calories verified with 4 / 4 / 9 kcal per g of protein / carbs / fat.
///  - Exactly one main protein source per meal (whole eggs + egg whites count as one); incidental protein
///    from rice, bread, oats, veg… counts toward totals.
///  - Every quantity is weighed RAW (meat, fish, eggs, potatoes, fruit, veg) or DRY (rice, pasta, oats)
///    using the matching database entry — cooked entries are never used for planning.
///  - Real meals, practical increments within sensible ranges; a small macro tolerance instead of
///    tiny unrelated foods.
///  - Every plan is validated; failing meals are regenerated with alternative recipes.
enum PlannerConfig {
    static let proteinUnderToleranceG = 8.0
    static let proteinOverToleranceG = 20.0
    static let calorieToleranceFraction = 0.04
    static let calorieToleranceMinKcal = 80.0
    static let carbToleranceFraction = 0.12
    static let carbToleranceMinG = 20.0
    static let fatToleranceFraction = 0.15
    static let fatToleranceMinG = 8.0
    static let databaseKcalToleranceFraction = 0.1
    static let databaseKcalToleranceMin = 10.0
    static let maxAttempts = 12
    static let maxIterations = 600
    static let weightProtein = 4.0
    static let weightCarbs = 1.0
    static let weightFat = 2.0
    static let weightKcal = 1.0
    static let weightDistribution = 0.25
    static let vegDefaultG = 150.0
}

enum PlannerRole: String, Sendable {
    case protein, carb, fruit, veg, fat, supplement
}

enum PlannerMealType: String, Sendable {
    case breakfast, snack, main, pre, post
}

struct PlannerFood: Equatable, Sendable {
    var key: String
    var id: UUID
    var name: String
    var state: MeasurementState
    /// Unit foods (eggs, bread slices, whey scoops) are counted in units; others in grams.
    var unit: Bool
    var servingDescription: String
    var servingGrams: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var role: PlannerRole
    var step: Double
    var min: Double
    var max: Double
    /// 0 allowed (item dropped) — side components: starch (low-carb days), fruit, added fat, extra egg whites.
    var optional: Bool
    var group: String?
    var allergens: [FoodAllergy]
    var keywords: [String]
}

struct PlannerRecipe: Equatable, Sendable {
    var id: String
    var type: PlannerMealType
    var protein: [String]
    var carb: String?
    var fruit: String?
    var veg: String?
    var fat: String?
}

struct PlannerContext: Equatable, Sendable {
    var allergies: [FoodAllergy]
    var dislikedFoods: [String]
    var preferredFoods: [String]
    var trainingTime: TrainingTimePreference
    var intraWorkoutEnabled: Bool
    var weightKg: Double
    var goal: GoalPhase
}

struct PlanValidation: Equatable, Sendable {
    var ok: Bool
    var issues: [String]
    var failingMeals: [Int]
    var protein: Double
    var carbs: Double
    var fat: Double
    /// 4/4/9 calories from the plan's macros.
    var kcal: Double
    /// Sum of the database calorie values.
    var databaseKcal: Double
    var databaseWarnings: [String]
}

enum MealPlanner {
    // MARK: - Food library (raw / dry entries only)

    private static func f(
        _ key: String, _ id: String, _ name: String, _ state: MeasurementState, _ unit: Bool, _ desc: String,
        _ grams: Double, _ kcal: Double, _ p: Double, _ c: Double, _ fat: Double, _ role: PlannerRole,
        _ step: Double, _ min: Double, _ max: Double, _ optional: Bool, _ group: String?,
        _ allergens: [FoodAllergy], _ keywords: [String]
    ) -> PlannerFood {
        PlannerFood(
            key: key, id: UUID(uuidString: id)!, name: name, state: state, unit: unit, servingDescription: desc,
            servingGrams: grams, kcal: kcal, protein: p, carbs: c, fat: fat, role: role, step: step, min: min,
            max: max, optional: optional, group: group, allergens: allergens, keywords: keywords
        )
    }

    static let foods: [PlannerFood] = [
        f("chicken", "a1000001-0001-4000-8000-000000000001", "Chicken Breast", .raw, false, "100 g raw", 100, 110, 23.1, 0, 1.2, .protein, 25, 75, 300, false, nil, [], ["chicken"]),
        f("beef", "a1000001-0001-4000-8000-000000000003", "Lean Beef (5% fat)", .raw, false, "100 g raw", 100, 137, 21.4, 0, 5.0, .protein, 25, 75, 250, false, nil, [], ["beef", "steak", "mince"]),
        f("turkey", "a1000001-0001-4000-8000-000000000005", "Turkey Breast", .raw, false, "100 g raw", 100, 104, 24.0, 0, 0.7, .protein, 25, 75, 300, false, nil, [], ["turkey"]),
        f("whiteFish", "a1000001-0001-4000-8000-000000000006", "White Fish (cod)", .raw, false, "100 g raw", 100, 82, 17.8, 0, 0.7, .protein, 25, 100, 350, false, nil, [.fish], ["fish", "cod"]),
        f("egg", "a1000001-0001-4000-8000-000000000007", "Egg", .raw, true, "large egg, raw (50 g each)", 50, 72, 6.3, 0.4, 4.8, .protein, 1, 1, 4, false, "egg", [.eggs], ["egg"]),
        f("eggWhites", "a1000001-0001-4000-8000-000000000008", "Egg Whites", .raw, false, "100 g raw", 100, 52, 10.9, 0.7, 0.2, .protein, 50, 100, 300, true, "egg", [.eggs], ["egg white"]),
        f("greekYogurt", "a1000001-0001-4000-8000-000000000009", "Greek Yogurt (0% fat)", .prepared, false, "100 g", 100, 59, 10.3, 3.6, 0.4, .protein, 50, 150, 500, false, nil, [.dairy], ["yogurt", "yoghurt"]),
        f("cottageCheese", "a1000001-0001-4000-8000-00000000000a", "Cottage Cheese (low fat)", .prepared, false, "100 g", 100, 72, 12.4, 2.7, 1.0, .protein, 50, 150, 400, false, nil, [.dairy], ["cottage"]),
        f("whey", "a1000001-0001-4000-8000-00000000000b", "Whey Protein Powder", .serving, true, "scoop whey protein (30 g each)", 30, 120, 24.0, 2.0, 1.5, .protein, 0.5, 0.5, 2, false, nil, [.dairy], ["whey", "protein powder", "protein shake"]),
        f("whiteRice", "a1000002-0001-4000-8000-000000000001", "White Rice", .dry, false, "100 g dry", 100, 365, 7.1, 80.0, 0.7, .carb, 10, 40, 175, true, nil, [], ["rice"]),
        f("brownRice", "a1000002-0001-4000-8000-000000000003", "Brown Rice", .dry, false, "100 g dry", 100, 370, 7.9, 77.2, 2.9, .carb, 10, 40, 175, true, nil, [], ["brown rice"]),
        f("potato", "a1000002-0001-4000-8000-000000000005", "Potato", .raw, false, "100 g raw", 100, 77, 2.0, 17.5, 0.1, .carb, 50, 150, 600, true, nil, [], ["potato"]),
        f("sweetPotato", "a1000002-0001-4000-8000-000000000007", "Sweet Potato", .raw, false, "100 g raw", 100, 86, 1.6, 20.1, 0.1, .carb, 50, 150, 500, true, nil, [], ["sweet potato"]),
        f("pasta", "a1000002-0001-4000-8000-000000000008", "Pasta", .dry, false, "100 g dry", 100, 371, 13.0, 74.7, 1.5, .carb, 10, 50, 175, true, nil, [.glutenWheat], ["pasta", "spaghetti"]),
        f("oats", "a1000002-0001-4000-8000-00000000000a", "Oats (rolled)", .dry, false, "100 g dry", 100, 389, 16.9, 66.3, 6.9, .carb, 10, 30, 150, true, nil, [.glutenWheat], ["oat", "porridge"]),
        f("bread", "a1000002-0001-4000-8000-00000000000c", "Bread (white)", .prepared, true, "slice white bread (30 g each)", 30, 79, 2.7, 14.7, 1.0, .carb, 1, 1, 4, true, nil, [.glutenWheat], ["bread", "toast"]),
        f("banana", "a1000002-0001-4000-8000-00000000000d", "Banana", .raw, false, "100 g raw (peeled)", 100, 89, 1.1, 22.8, 0.3, .fruit, 25, 75, 250, true, nil, [], ["banana"]),
        f("apple", "a1000002-0001-4000-8000-00000000000e", "Apple", .raw, false, "100 g raw", 100, 52, 0.3, 13.8, 0.2, .fruit, 25, 100, 250, true, nil, [], ["apple"]),
        f("berries", "a1000002-0001-4000-8000-00000000000f", "Mixed Berries", .raw, false, "100 g raw", 100, 57, 0.7, 14.5, 0.3, .fruit, 25, 75, 250, true, nil, [], ["berr"]),
        f("mixedVeg", "a1000002-0001-4000-8000-000000000010", "Mixed Vegetables", .raw, false, "100 g raw", 100, 35, 2.0, 7.0, 0.2, .veg, 25, 100, 250, false, nil, [], ["vegetable", "veg"]),
        f("broccoli", "a1000002-0001-4000-8000-000000000011", "Broccoli", .raw, false, "100 g raw", 100, 34, 2.8, 6.6, 0.4, .veg, 25, 100, 250, false, nil, [], ["broccoli"]),
        f("peanutButter", "a1000003-0001-4000-8000-000000000001", "Peanut Butter", .serving, false, "32 g (2 tbsp)", 32, 188, 8.0, 6.0, 16.0, .fat, 5, 10, 50, true, nil, [.peanuts], ["peanut"]),
        f("oliveOil", "a1000003-0001-4000-8000-000000000002", "Olive Oil", .serving, false, "14 g (1 tbsp)", 14, 119, 0, 0, 13.5, .fat, 5, 5, 30, true, nil, [], ["olive oil", "oil"]),
        f("almonds", "a1000003-0001-4000-8000-000000000003", "Almonds", .raw, false, "28 g (1 oz)", 28, 164, 6.0, 6.1, 14.2, .fat, 5, 10, 50, true, nil, [.treeNuts], ["almond", "nuts"]),
        f("avocado", "a1000003-0001-4000-8000-000000000004", "Avocado", .raw, false, "100 g raw", 100, 160, 2.0, 8.5, 14.7, .fat, 25, 50, 200, true, nil, [], ["avocado"]),
        f("dextrose", "a1000004-0001-4000-8000-000000000001", "Dextrose", .dry, false, "100 g dry powder", 100, 380, 0, 95.0, 0, .supplement, 1, 0, 200, false, nil, [], ["dextrose"]),
        f("eaa", "a1000004-0001-4000-8000-000000000002", "Essential Amino Acids (EAAs)", .serving, false, "10 g serving", 10, 40, 10.0, 0, 0, .supplement, 1, 0, 50, false, nil, [], ["eaa"]),
    ]

    private static let byKey: [String: PlannerFood] = Dictionary(uniqueKeysWithValues: foods.map { ($0.key, $0) })
    private static let byID: [UUID: PlannerFood] = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
    private static func food(_ key: String) -> PlannerFood { byKey[key]! }

    static func plannerFood(id: UUID) -> PlannerFood? { byID[id] }
    static func plannerFood(key: String) -> PlannerFood? { byKey[key] }

    private static func r(
        _ id: String, _ type: PlannerMealType, _ protein: [String],
        carb: String? = nil, fruit: String? = nil, veg: String? = nil, fat: String? = nil
    ) -> PlannerRecipe {
        PlannerRecipe(id: id, type: type, protein: protein, carb: carb, fruit: fruit, veg: veg, fat: fat)
    }

    /// Real meals from compatible ingredients. Order matters (deterministic tie-breaking).
    static let recipes: [PlannerRecipe] = [
        r("eggs-toast-berries", .breakfast, ["egg", "eggWhites"], carb: "bread", fruit: "berries"),
        r("yogurt-oats-berries", .breakfast, ["greekYogurt"], carb: "oats", fruit: "berries", fat: "almonds"),
        r("eggs-oats-banana", .breakfast, ["egg", "eggWhites"], carb: "oats", fruit: "banana"),
        r("whey-oats-banana-pb", .breakfast, ["whey"], carb: "oats", fruit: "banana", fat: "peanutButter"),
        r("cottage-toast-apple", .breakfast, ["cottageCheese"], carb: "bread", fruit: "apple"),
        r("eggs-toast-avocado", .breakfast, ["egg", "eggWhites"], carb: "bread", fat: "avocado"),
        r("eggs-potato-veg", .breakfast, ["egg", "eggWhites"], carb: "potato", veg: "mixedVeg"),

        r("yogurt-berries-almonds", .snack, ["greekYogurt"], fruit: "berries", fat: "almonds"),
        r("cottage-apple", .snack, ["cottageCheese"], fruit: "apple", fat: "almonds"),
        r("whey-banana-pb", .snack, ["whey"], fruit: "banana", fat: "peanutButter"),
        r("yogurt-oats-banana", .snack, ["greekYogurt"], carb: "oats", fruit: "banana"),
        r("whey-apple-almonds", .snack, ["whey"], fruit: "apple", fat: "almonds"),
        r("turkey-toast", .snack, ["turkey"], carb: "bread"),

        r("chicken-rice-broccoli", .main, ["chicken"], carb: "whiteRice", veg: "broccoli", fat: "oliveOil"),
        r("beef-potato-veg", .main, ["beef"], carb: "potato", veg: "mixedVeg", fat: "oliveOil"),
        r("turkey-pasta-veg", .main, ["turkey"], carb: "pasta", veg: "mixedVeg", fat: "oliveOil"),
        r("fish-potato-broccoli", .main, ["whiteFish"], carb: "potato", veg: "broccoli", fat: "oliveOil"),
        r("chicken-sweetpotato-veg", .main, ["chicken"], carb: "sweetPotato", veg: "mixedVeg", fat: "avocado"),
        r("beef-rice-broccoli", .main, ["beef"], carb: "whiteRice", veg: "broccoli"),
        r("turkey-brownrice-veg", .main, ["turkey"], carb: "brownRice", veg: "mixedVeg", fat: "avocado"),
        r("fish-rice-veg", .main, ["whiteFish"], carb: "whiteRice", veg: "mixedVeg", fat: "oliveOil"),

        r("chicken-rice", .pre, ["chicken"], carb: "whiteRice"),
        r("turkey-toast-banana", .pre, ["turkey"], carb: "bread", fruit: "banana"),
        r("chicken-potato", .pre, ["chicken"], carb: "potato"),
        r("fish-rice", .pre, ["whiteFish"], carb: "whiteRice"),
        r("yogurt-oats-banana-pre", .pre, ["greekYogurt"], carb: "oats", fruit: "banana"),

        r("chicken-rice-broccoli-post", .post, ["chicken"], carb: "whiteRice", veg: "broccoli"),
        r("beef-potato-veg-post", .post, ["beef"], carb: "potato", veg: "mixedVeg"),
        r("turkey-pasta-veg-post", .post, ["turkey"], carb: "pasta", veg: "mixedVeg"),
        r("fish-potato-broccoli-post", .post, ["whiteFish"], carb: "potato", veg: "broccoli"),
        r("chicken-pasta-broccoli-post", .post, ["chicken"], carb: "pasta", veg: "broccoli"),
    ]

    static func mealType(for slot: MealSlot) -> PlannerMealType {
        switch slot {
        case .breakfast: return .breakfast
        case .snack, .afternoonSnack: return .snack
        case .preWorkout, .intraWorkout: return .pre
        case .postWorkout: return .post
        default: return .main
        }
    }

    private static func carbWeight(_ type: PlannerMealType) -> Double {
        switch type {
        case .breakfast: return 1
        case .snack: return 0.6
        case .main: return 1
        case .pre: return 1.3
        case .post: return 1.3
        }
    }

    // MARK: - Preferences and filters

    /// Does a user-entered food name refer to this planner food?
    static func matchesName(_ food: PlannerFood, _ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !t.isEmpty else { return false }
        return food.name.lowercased().contains(t) || food.keywords.contains { t.contains($0) }
    }

    private static func recipeKeys(_ r: PlannerRecipe) -> [String] {
        r.protein + [r.carb, r.fruit, r.veg, r.fat].compactMap { $0 }
    }

    private static func recipeAllowed(_ r: PlannerRecipe, _ ctx: PlannerContext) -> Bool {
        let banned = ctx.allergies.filter { $0 != .none }
        return recipeKeys(r).allSatisfy { key in
            let f = food(key)
            if f.allergens.contains(where: { banned.contains($0) }) { return false }
            return !ctx.dislikedFoods.contains { matchesName(f, $0) }
        }
    }

    private static func recipeScore(_ r: PlannerRecipe, _ ctx: PlannerContext) -> Int {
        if ctx.preferredFoods.isEmpty { return 0 }
        return recipeKeys(r).filter { key in ctx.preferredFoods.contains { matchesName(food(key), $0) } }.count
    }

    /// Candidate recipes for a meal type, best first. Falls back to main/pre meals if allergies rule all out.
    static func candidates(for type: PlannerMealType, ctx: PlannerContext) -> [PlannerRecipe] {
        let order: [PlannerMealType] = type == .main ? [.main, .pre] : [type, .main, .pre]
        for t in order {
            let list = recipes.filter { $0.type == t && recipeAllowed($0, ctx) }
            if !list.isEmpty {
                return list.enumerated()
                    .map { (r: $0.element, i: $0.offset, s: recipeScore($0.element, ctx)) }
                    .sorted { $0.s != $1.s ? $0.s > $1.s : $0.i < $1.i }
                    .map(\.r)
            }
        }
        return []
    }

    // MARK: - Items, domains, nutrition

    static func roleForMacros(protein p: Double, carbs c: Double, fat f: Double) -> PlannerRole {
        let total = 4 * p + 4 * c + 9 * f
        if total <= 0 { return .veg }
        if (4 * p) / total >= 0.4 { return .protein }
        if (9 * f) / total >= 0.5 { return .fat }
        return .carb
    }

    /// Spec for any food that can sit in a plan: planner foods by id, otherwise a sensible custom spec.
    static func spec(for item: FoodItem) -> PlannerFood {
        if let known = byID[item.id] { return known }
        let grams = (item.servingGrams ?? 0) > 0 ? item.servingGrams : nil
        let p = item.proteinGrams ?? 0
        let c = item.carbohydrateGrams ?? 0
        let fat = item.fatGrams ?? 0
        return PlannerFood(
            key: "custom:\(item.id.uuidString.lowercased())",
            id: item.id,
            name: item.name,
            state: item.measurementState,
            unit: grams == nil,
            servingDescription: item.servingDescription,
            servingGrams: grams ?? 1,
            kcal: item.calories ?? (4 * p + 4 * c + 9 * fat),
            protein: p,
            carbs: c,
            fat: fat,
            role: roleForMacros(protein: p, carbs: c, fat: fat),
            step: grams == nil ? 0.5 : 10,
            min: grams == nil ? 0.5 : 20,
            max: grams == nil ? 4 : 400,
            optional: false,
            group: nil,
            allergens: Array(item.allergenTags),
            keywords: []
        )
    }

    static func foodItem(_ f: PlannerFood) -> FoodItem {
        FoodItem(
            id: f.id,
            name: f.name,
            source: f.key.hasPrefix("custom:") ? .customUser : .bundledGeneric,
            servingDescription: f.servingDescription,
            servingGrams: f.servingGrams,
            calories: f.kcal,
            proteinGrams: f.protein,
            carbohydrateGrams: f.carbs,
            fatGrams: f.fat,
            measurementState: f.state,
            isCustom: false,
            isVerified: true,
            allergenTags: Set(f.allergens)
        )
    }

    private struct Nutrients {
        var kcal: Double
        var p: Double
        var c: Double
        var fat: Double
    }

    private static func macros(_ f: PlannerFood, _ amount: Double) -> Nutrients {
        let k = f.unit ? amount : amount / f.servingGrams
        return Nutrients(kcal: f.kcal * k, p: f.protein * k, c: f.carbs * k, fat: f.fat * k)
    }

    /// Allowed amounts: practical grid min, min+step, …, max, plus 0 for optional components. Starch may only
    /// be dropped from a meal that also has vegetables (protein + veg is still a real plate).
    static func domain(of f: PlannerFood, mealHasVeg: Bool = true) -> [Double] {
        var values: [Double] = f.optional && (f.role != .carb || mealHasVeg) ? [0] : []
        let n = Int(((f.max - f.min) / f.step).rounded())
        for i in 0...max(n, 0) {
            values.append(((f.min + Double(i) * f.step) * 1000).rounded() / 1000)
        }
        return values
    }

    private static func snap(_ domain: [Double], _ value: Double) -> Double {
        var best = domain[0]
        for v in domain where abs(v - value) < abs(best - value) - 1e-9 {
            best = v
        }
        return best
    }

    private final class WorkItem {
        let id: UUID
        let meal: Int
        let spec: PlannerFood
        let domain: [Double]
        var amount: Double
        let locked: Bool

        init(id: UUID, meal: Int, spec: PlannerFood, domain: [Double], amount: Double, locked: Bool) {
            self.id = id
            self.meal = meal
            self.spec = spec
            self.domain = domain
            self.amount = amount
            self.locked = locked
        }
    }

    private struct Targets {
        var p: Double
        var c: Double
        var f: Double
        var kcal: Double
    }

    private static func totals(_ items: [WorkItem]) -> Nutrients {
        var t = Nutrients(kcal: 0, p: 0, c: 0, fat: 0)
        for it in items {
            let m = macros(it.spec, it.amount)
            t.p += m.p
            t.c += m.c
            t.fat += m.fat
            t.kcal += m.kcal
        }
        return t
    }

    private static func objective(_ items: [WorkItem], _ t: Targets, _ mealCount: Int) -> Double {
        var mealP = [Double](repeating: 0, count: mealCount)
        var p = 0.0
        var c = 0.0
        var f = 0.0
        for it in items {
            let m = macros(it.spec, it.amount)
            p += m.p
            c += m.c
            f += m.fat
            mealP[it.meal] += m.p
        }
        let kcal = 4 * p + 4 * c + 9 * f
        let perMeal = t.p / Double(mealCount)
        var dist = 0.0
        for mp in mealP { dist += (mp - perMeal) * (mp - perMeal) }
        let dk = (kcal - t.kcal) / 4
        return PlannerConfig.weightProtein * (p - t.p) * (p - t.p)
            + PlannerConfig.weightCarbs * (c - t.c) * (c - t.c)
            + PlannerConfig.weightFat * (f - t.f) * (f - t.f)
            + PlannerConfig.weightKcal * dk * dk
            + PlannerConfig.weightDistribution * dist
    }

    /// Coordinate descent over the practical grids: one step at a time, best improvement first.
    @discardableResult
    private static func optimize(_ items: [WorkItem], _ t: Targets, _ mealCount: Int) -> Double {
        var current = objective(items, t, mealCount)
        for _ in 0..<PlannerConfig.maxIterations {
            var bestJ = current
            var bestItem = -1
            var bestValue = 0.0
            for (i, it) in items.enumerated() {
                if it.locked || it.spec.role == .supplement { continue }
                guard let idx = it.domain.firstIndex(of: it.amount) else { continue }
                for d in [-1, 1] {
                    let j = idx + d
                    if j < 0 || j >= it.domain.count { continue }
                    let saved = it.amount
                    it.amount = it.domain[j]
                    let val = objective(items, t, mealCount)
                    it.amount = saved
                    if val < bestJ - 1e-9 {
                        bestJ = val
                        bestItem = i
                        bestValue = it.domain[j]
                    }
                }
            }
            if bestItem < 0 { break }
            items[bestItem].amount = bestValue
            current = bestJ
        }
        return current
    }

    // MARK: - Validation

    private static func targets(of target: DailyNutritionTarget) -> Targets {
        let m = target.macros
        return Targets(p: m.protein, c: m.carbohydrates, f: m.fat, kcal: 4 * m.protein + 4 * m.carbohydrates + 9 * m.fat)
    }

    static func databaseKcalConsistent(_ f: PlannerFood) -> Bool {
        let per = 100 / f.servingGrams
        let label = f.kcal * per
        let fromMacros = (4 * f.protein + 4 * f.carbs + 9 * f.fat) * per
        return abs(label - fromMacros) <= Swift.max(
            PlannerConfig.databaseKcalToleranceFraction * label,
            PlannerConfig.databaseKcalToleranceMin
        )
    }

    private static func rounded(_ x: Double) -> Int { Int(x.rounded()) }

    private static func validate(_ items: [WorkItem], _ t: Targets, _ mealCount: Int) -> PlanValidation {
        let tot = totals(items)
        let kcal = 4 * tot.p + 4 * tot.c + 9 * tot.fat
        var issues: [String] = []
        if tot.p < t.p - PlannerConfig.proteinUnderToleranceG {
            issues.append("Protein \(rounded(tot.p)) g is below the \(rounded(t.p)) g target.")
        }
        if tot.p > t.p + PlannerConfig.proteinOverToleranceG {
            issues.append("Protein \(rounded(tot.p)) g is well above the \(rounded(t.p)) g target.")
        }
        if abs(kcal - t.kcal) > Swift.max(PlannerConfig.calorieToleranceFraction * t.kcal, PlannerConfig.calorieToleranceMinKcal) {
            issues.append("Calories \(rounded(kcal)) kcal miss the \(rounded(t.kcal)) kcal target.")
        }
        if abs(tot.c - t.c) > Swift.max(PlannerConfig.carbToleranceFraction * t.c, PlannerConfig.carbToleranceMinG) {
            issues.append("Carbs \(rounded(tot.c)) g miss the \(rounded(t.c)) g target.")
        }
        if abs(tot.fat - t.f) > Swift.max(PlannerConfig.fatToleranceFraction * t.f, PlannerConfig.fatToleranceMinG) {
            issues.append("Fat \(rounded(tot.fat)) g misses the \(rounded(t.f)) g target.")
        }

        var failing = Set<Int>()
        for m in 0..<mealCount {
            let mealItems = items.filter { $0.meal == m && $0.amount > 0 }
            let sources = Set(mealItems.filter { $0.spec.role == .protein }.map { $0.spec.group ?? $0.spec.key })
            if sources.count != 1 { failing.insert(m) }
            for it in mealItems {
                if it.spec.state == .cooked { failing.insert(m) }
                if it.spec.role != .supplement, !it.domain.contains(it.amount) { failing.insert(m) }
            }
        }
        var warnings: [String] = []
        for it in items where !databaseKcalConsistent(it.spec) {
            let w = "\(it.spec.name): label calories don't match its macros."
            if !warnings.contains(w) { warnings.append(w) }
        }
        return PlanValidation(
            ok: issues.isEmpty && failing.isEmpty,
            issues: issues,
            failingMeals: failing.sorted(),
            protein: tot.p,
            carbs: tot.c,
            fat: tot.fat,
            kcal: kcal,
            databaseKcal: tot.kcal,
            databaseWarnings: warnings
        )
    }

    // MARK: - Building meals

    private static func timeForSlot(_ slot: MealSlot, _ trainingTime: TrainingTimePreference, _ index: Int) -> Int {
        let trainingMinutes: Int
        switch trainingTime {
        case .morning: trainingMinutes = 8 * 60
        case .midday: trainingMinutes = 12 * 60
        case .afternoon: trainingMinutes = 15 * 60
        case .evening: trainingMinutes = 18 * 60
        case .variable: trainingMinutes = 17 * 60
        }
        switch slot {
        case .breakfast: return 8 * 60
        case .snack: return 10 * 60 + 30
        case .lunch: return 13 * 60
        case .afternoonSnack: return 16 * 60
        case .dinner: return 19 * 60
        case .preWorkout: return trainingMinutes - 90
        case .intraWorkout: return trainingMinutes
        case .postWorkout: return trainingMinutes + 60
        case .custom: return 10 * 60 + index * 180
        }
    }

    private static func items(for recipe: PlannerRecipe, meal: Int, perMealProtein: Double) -> [WorkItem] {
        var out: [WorkItem] = []
        let hasVeg = recipe.veg != nil
        func add(_ key: String, _ amount: Double) {
            let spec = food(key)
            let d = domain(of: spec, mealHasVeg: hasVeg)
            out.append(WorkItem(id: UUID(), meal: meal, spec: spec, domain: d, amount: snap(d, amount), locked: false))
        }
        if recipe.protein.count == 2, recipe.protein[0] == "egg" {
            let egg = food("egg")
            let whites = food("eggWhites")
            add("egg", 2)
            add("eggWhites", ((perMealProtein - 2 * egg.protein) / whites.protein) * whites.servingGrams)
        } else {
            let p = food(recipe.protein[0])
            add(recipe.protein[0], p.unit ? perMealProtein / p.protein : (perMealProtein / p.protein) * p.servingGrams)
        }
        if let veg = recipe.veg { add(veg, PlannerConfig.vegDefaultG) }
        if let fruit = recipe.fruit { add(fruit, food(fruit).min) }
        if let fat = recipe.fat { add(fat, food(fat).min) }
        if let carb = recipe.carb { add(carb, food(carb).min) }
        return out
    }

    private static func intraItems(meal: Int, ctx: PlannerContext) -> [WorkItem] {
        let intra = NutritionEngine().intraWorkoutTargets(weightKg: ctx.weightKg, goal: ctx.goal)
        return [("dextrose", intra.dextroseGrams), ("eaa", intra.eaaGrams)].map { key, amount in
            WorkItem(id: UUID(), meal: meal, spec: food(key), domain: [amount], amount: amount, locked: true)
        }
    }

    private static func sizeCarbs(_ items: [WorkItem], _ t: Targets, _ types: [PlannerMealType]) {
        let carbItems = items.filter { $0.spec.role == .carb && !$0.locked }
        if carbItems.isEmpty { return }
        let carbIDs = Set(carbItems.map { ObjectIdentifier($0) })
        let nonCarb = items.filter { !carbIDs.contains(ObjectIdentifier($0)) }
        let fixedCarbs = totals(nonCarb).c
        let budget = Swift.max(0, t.c - fixedCarbs)
        let weightSum = carbItems.reduce(0.0) { $0 + carbWeight(types[$1.meal]) }
        for it in carbItems {
            let share = (budget * carbWeight(types[it.meal])) / weightSum
            let perAmount = it.spec.unit ? it.spec.carbs : it.spec.carbs / it.spec.servingGrams
            it.amount = snap(it.domain, perAmount > 0 ? share / perAmount : it.spec.min)
        }
    }

    private static func mealItem(_ it: WorkItem) -> MealItem {
        let m = macros(it.spec, it.amount)
        return MealItem(
            id: it.id,
            food: foodItem(it.spec),
            grams: it.spec.unit ? nil : it.amount,
            servings: it.spec.unit ? it.amount : nil,
            isLocked: it.locked && it.spec.role != .supplement,
            calories: m.kcal,
            macros: MacroGrams(protein: m.p, carbohydrates: m.c, fat: m.fat)
        )
    }

    private static func message(for v: PlanValidation) -> String? {
        var notes: [String] = []
        if !v.ok {
            notes.append(
                v.issues.isEmpty
                    ? "Some meals couldn't be built from practical portions with your current foods."
                    : "Closest practical plan with these foods: \(v.issues.joined(separator: " "))"
            )
        }
        if !v.databaseWarnings.isEmpty { notes.append(v.databaseWarnings.joined(separator: " ")) }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    private struct Built {
        var items: [WorkItem]
        var recipeIDs: [String?]
        var validation: PlanValidation
        var score: Double
    }

    private static func buildDay(
        _ chosen: [PlannerRecipe?], _ types: [PlannerMealType], _ slots: [MealSlot], _ t: Targets, _ ctx: PlannerContext
    ) -> Built {
        let n = slots.count
        let perMealProtein = t.p / Double(n)
        var items: [WorkItem] = []
        for (m, recipe) in chosen.enumerated() {
            if let recipe { items += Self.items(for: recipe, meal: m, perMealProtein: perMealProtein) }
            if slots[m] == .preWorkout, ctx.intraWorkoutEnabled { items += intraItems(meal: m, ctx: ctx) }
        }
        sizeCarbs(items, t, types)
        let j = optimize(items, t, n)
        let v = validate(items, t, n)
        return Built(
            items: items,
            recipeIDs: chosen.map { $0?.id },
            validation: v,
            score: j + Double(v.issues.count + v.failingMeals.count) * 1e6
        )
    }

    /// Generate a validated day. Retries with alternative recipes for failing meals; keeps the best attempt.
    static func generateDay(
        date: Date,
        weekday: Weekday,
        isTrainingDay: Bool,
        target: DailyNutritionTarget,
        context ctx: PlannerContext
    ) -> MealPlanDay {
        let slots = MealSlot.slots(isTrainingDay: isTrainingDay)
        let types = slots.map(mealType(for:))
        let t = targets(of: target)
        let cands = types.map { candidates(for: $0, ctx: ctx) }
        let dayIndex = weekday.rawValue - 1

        var base: [Int] = []
        var used = Set<String>()
        for (m, list) in cands.enumerated() {
            guard let first = list.first else {
                base.append(0)
                continue
            }
            let topScore = recipeScore(first, ctx)
            let top = list.filter { recipeScore($0, ctx) == topScore }
            let start = (dayIndex * 3 + m) % top.count
            var found: PlannerRecipe?
            for k in 0..<top.count {
                let r = top[(start + k) % top.count]
                if !used.contains(r.protein[0]) {
                    found = r
                    break
                }
            }
            // Every best match repeats a protein already used today → accept one fewer preferred food for variety.
            if found == nil {
                found = list.first { recipeScore($0, ctx) >= topScore - 1 && !used.contains($0.protein[0]) }
            }
            let pick = found ?? top[start]
            used.insert(pick.protein[0])
            base.append(list.firstIndex(of: pick) ?? 0)
        }

        var offsets = [Int](repeating: 0, count: slots.count)
        var best: Built?
        var last: Built?
        for attempt in 0..<PlannerConfig.maxAttempts {
            if attempt > 0 {
                let failing = last?.validation.failingMeals ?? []
                let m = failing.isEmpty ? (attempt - 1) % slots.count : failing[(attempt - 1) % failing.count]
                offsets[m] += 1
            }
            let chosen: [PlannerRecipe?] = cands.enumerated().map { m, list in
                list.isEmpty ? nil : list[(base[m] + offsets[m]) % list.count]
            }
            let built = buildDay(chosen, types, slots, t, ctx)
            last = built
            if best == nil || built.score < best!.score { best = built }
            if built.validation.ok { break }
        }

        let result = best!
        var times = slots.enumerated().map { m, slot in timeForSlot(slot, ctx.trainingTime, m) }
        // Dinner comes at least 2.5 h after the post-workout meal on evening-training days.
        if let post = slots.firstIndex(of: .postWorkout), let dinner = slots.firstIndex(of: .dinner) {
            times[dinner] = Swift.max(times[dinner], times[post] + 150)
        }
        let meals: [Meal] = slots.enumerated().map { m, slot in
            Meal(
                slot: slot,
                name: slot.displayName,
                scheduledTimeMinutes: times[m],
                items: result.items.filter { $0.meal == m && $0.amount > 0 }.map(mealItem),
                recipeID: result.recipeIDs[m]
            )
        }
        return MealPlanDay(
            localDate: date,
            weekday: weekday,
            isTrainingDay: isTrainingDay,
            target: target,
            meals: meals,
            solverMessage: message(for: result.validation)
        )
    }

    // MARK: - Re-optimisation after swaps / locks

    private static func work(from plan: MealPlanDay) -> [WorkItem] {
        var items: [WorkItem] = []
        for (m, meal) in plan.meals.enumerated() {
            let hasVeg = meal.items.contains { spec(for: $0.food).role == .veg }
            for it in meal.items {
                let spec = spec(for: it.food)
                let amount = it.grams ?? it.servings ?? 0
                let isSupplement = spec.role == .supplement
                let d = isSupplement ? [amount] : domain(of: spec, mealHasVeg: hasVeg)
                items.append(
                    WorkItem(
                        id: it.id,
                        meal: m,
                        spec: spec,
                        domain: d,
                        amount: isSupplement ? amount : snap(d, amount),
                        locked: it.isLocked || isSupplement
                    )
                )
            }
        }
        return items
    }

    /// Re-fit unlocked portions to the day's targets, then validate. Keeps every food and lock as chosen.
    static func reoptimize(_ plan: MealPlanDay, extraMessage: String? = nil) -> MealPlanDay {
        let t = targets(of: plan.target)
        let items = work(from: plan)
        optimize(items, t, plan.meals.count)
        let v = validate(items, t, plan.meals.count)
        var next = plan
        for m in next.meals.indices {
            next.meals[m].items = items.filter { $0.meal == m && $0.amount > 0 }.map(mealItem)
        }
        let msg = [extraMessage, message(for: v)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        next.solverMessage = msg.isEmpty ? nil : msg
        return next
    }

    static func validate(_ plan: MealPlanDay) -> PlanValidation {
        validate(work(from: plan), targets(of: plan.target), plan.meals.count)
    }

    /// Raw/dry planner foods that can replace an item of this role (plus custom foods of the same role).
    static func swapOptions(for item: MealItem, customFoods: [FoodItem], allergies: Set<FoodAllergy>) -> [FoodItem] {
        let role = spec(for: item.food).role
        let banned = allergies.filter { $0 != .none }
        let library = foods.filter { $0.role == role && $0.key != "eggWhites" }.map(foodItem)
        let custom = customFoods.filter { spec(for: $0).role == role && $0.measurementState != .cooked }
        return (library + custom).filter { $0.id != item.food.id && $0.allergenTags.isDisjoint(with: banned) }
    }

    /// Map a food to the version the planner weighs: cooked catalog entries → their raw/dry planner entry.
    static func rawEquivalent(_ item: FoodItem) -> FoodItem? {
        if let known = byID[item.id] { return foodItem(known) }
        if item.measurementState != .cooked { return item }
        return foods.first { $0.name.lowercased() == item.name.lowercased() }.map(foodItem)
    }

    /// Swap one ingredient: keep roughly the same calories, re-fit the day, validate.
    static func swapItem(_ plan: MealPlanDay, itemID: UUID, with replacement: FoodItem) -> (plan: MealPlanDay, message: String?) {
        guard let raw = rawEquivalent(replacement) else {
            return (plan, "\(replacement.name) is a cooked entry with no raw version — pick a raw or dry food so it can be weighed raw.")
        }
        var swapped = false
        var next = plan
        for m in next.meals.indices {
            guard let target = next.meals[m].items.first(where: { $0.id == itemID }) else { continue }
            let newSpec = spec(for: raw)
            let oldSpec = spec(for: target.food)
            let isEggGroup = oldSpec.group == "egg"
            let d = domain(of: newSpec, mealHasVeg: next.meals[m].items.contains { spec(for: $0.food).role == .veg })
            let perAmount = macros(newSpec, newSpec.unit ? 1 : newSpec.servingGrams).kcal / (newSpec.unit ? 1 : newSpec.servingGrams)
            let amount = snap(d, perAmount > 0 ? target.calories / perAmount : newSpec.min)
            let replacementItem = mealItem(WorkItem(id: target.id, meal: 0, spec: newSpec, domain: d, amount: amount, locked: target.isLocked))
            swapped = true
            next.meals[m].items = next.meals[m].items
                .filter { !(isEggGroup && newSpec.role == .protein && $0.id != itemID && spec(for: $0.food).group == "egg") }
                .map { $0.id == itemID ? replacementItem : $0 }
            next.meals[m].recipeID = nil
        }
        guard swapped else { return (plan, nil) }
        let note = replacement.measurementState == .cooked ? "Swapped to raw \(raw.name) — weigh it raw." : nil
        return (reoptimize(next, extraMessage: note), nil)
    }

    /// Replace a whole meal with the next suitable recipe of its type, then re-fit the day.
    static func swapMeal(_ plan: MealPlanDay, mealID: UUID, context ctx: PlannerContext) -> MealPlanDay {
        guard let m = plan.meals.firstIndex(where: { $0.id == mealID }) else { return plan }
        let meal = plan.meals[m]
        let list = candidates(for: mealType(for: meal.slot), ctx: ctx)
        guard !list.isEmpty else { return plan }
        let recipeByID = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
        var usedElsewhere = Set<String>()
        for (i, other) in plan.meals.enumerated() where i != m {
            if let id = other.recipeID, let r = recipeByID[id] { usedElsewhere.insert(r.protein[0]) }
        }
        let current = meal.recipeID.flatMap { id in list.firstIndex { $0.id == id } } ?? -1
        var next = list[(current + 1) % list.count]
        for k in 1...list.count {
            let r = list[(current + k + list.count) % list.count]
            if r.id != meal.recipeID, !usedElsewhere.contains(r.protein[0]) {
                next = r
                break
            }
        }
        let t = targets(of: plan.target)
        var work = items(for: next, meal: 0, perMealProtein: t.p / Double(plan.meals.count))
        if meal.slot == .preWorkout, ctx.intraWorkoutEnabled { work += intraItems(meal: 0, ctx: ctx) }
        var updated = plan
        updated.meals[m].recipeID = next.id
        updated.meals[m].items = work.filter { $0.amount > 0 }.map(mealItem)
        return reoptimize(updated)
    }
}
