import SwiftUI

/// Every food the app knows: the user's own, scanned products, and the bundled generic database.
struct FoodsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case mine = "My Foods"
        case scanned = "Scanned"
        case generic = "Generic"
        var id: String { rawValue }
    }

    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var detail: FoodItem?
    @State private var showScanner = false
    @State private var showCreate = false
    @State private var pendingDetail: FoodItem?

    private var foods: [FoodItem] {
        let tokens = query.lowercased().split(separator: " ").map(String.init)
        var seen = Set<UUID>()
        return env.catalogFoods.filter { food in
            guard seen.insert(food.id).inserted else { return false }
            switch filter {
            case .all: break
            case .mine: guard food.isCustom else { return false }
            case .scanned: guard food.barcode != nil else { return false }
            case .generic: guard food.source == .bundledGeneric else { return false }
            }
            let haystack = [food.name, food.brand ?? "", food.servingDescription, food.barcode ?? ""]
                .joined(separator: " ")
                .lowercased()
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }

    var body: some View {
        let all = foods
        let mine = all.filter(\.isCustom)
        let generic = all.filter { !$0.isCustom }
        NavigationStack {
            List {
                Section {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan a Barcode", systemImage: "barcode.viewfinder")
                            .font(MCTheme.Typography.headline)
                    }
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("\(all.count) \(all.count == 1 ? "food" : "foods")")
                }

                if all.isEmpty {
                    ContentUnavailableView(
                        filter == .scanned && query.isEmpty ? "No scanned foods yet" : "No foods found",
                        systemImage: filter == .scanned ? "barcode" : "magnifyingglass",
                        description: Text(
                            filter == .scanned && query.isEmpty
                                ? "Scan a packaged food's barcode to add it with its label nutrition."
                                : "Try another search, scan a barcode, or create a food."
                        )
                    )
                }
                if !mine.isEmpty {
                    Section("My Foods (\(mine.count))") {
                        ForEach(mine) { food in row(food) }
                    }
                }
                if !generic.isEmpty {
                    Section("Generic Database (\(generic.count))") {
                        ForEach(generic) { food in row(food) }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search foods, brands or barcodes")
            .navigationTitle("Foods")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Create food")
                }
            }
            .sheet(item: $detail) { food in
                FoodDetailView(foodID: food.id, fallback: food)
            }
            .sheet(isPresented: $showScanner, onDismiss: {
                // Present the detail only after the scanner sheet has fully dismissed.
                if let pendingDetail {
                    detail = pendingDetail
                    self.pendingDetail = nil
                }
            }) {
                ScanFoodFlowView { food in
                    pendingDetail = food
                    showScanner = false
                }
            }
            .sheet(isPresented: $showCreate) {
                CustomFoodEditorView { food in env.saveCustomFood(food) }
            }
        }
    }

    private func row(_ food: FoodItem) -> some View {
        Button {
            detail = food
        } label: {
            HStack {
                MCFoodRow(food: food, showsChevron: true)
                if food.barcode != nil {
                    Image(systemName: "barcode")
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct FoodDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let foodID: UUID
    let fallback: FoodItem

    @State private var showLog = false
    @State private var showEdit = false
    @State private var confirmDelete = false

    /// Re-read from the store so edits show immediately.
    private var food: FoodItem {
        env.customFoods.first { $0.id == foodID } ?? fallback
    }

    var body: some View {
        let food = self.food
        // Second column only when the serving isn't already 100 g.
        let per = food.servingGrams == 100 ? nil : food.nutritionPerGram()
        let allergens = food.allergenTags.filter { $0 != .none }
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).font(MCTheme.Typography.title2)
                        Text("\(food.displaySubtitle) · \(food.measurementState.displayName)")
                            .font(MCTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                        if let barcode = food.barcode {
                            Label(barcode, systemImage: "barcode")
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !allergens.isEmpty {
                    Section {
                        let conflicts = allergens.contains { env.profile.allergies.contains($0) }
                        Label(
                            "Allergens: \(allergens.map(\.displayName).sorted().joined(separator: ", "))",
                            systemImage: conflicts ? "exclamationmark.triangle.fill" : "info.circle"
                        )
                        .foregroundStyle(conflicts ? MCTheme.ColorToken.warning : .secondary)
                    }
                }
                Section {
                    nutritionRow("Calories", food.calories, per.map { $0.calories * 100 }, unit: "kcal")
                    nutritionRow("Protein", food.proteinGrams, per.map { $0.protein * 100 }, unit: "g")
                    nutritionRow("Carbs", food.carbohydrateGrams, per.map { $0.carbs * 100 }, unit: "g")
                    nutritionRow("Fat", food.fatGrams, per.map { $0.fat * 100 }, unit: "g")
                    nutritionRow(
                        "Fibre",
                        food.fibreGrams,
                        food.fibreGrams.flatMap { f in food.servingGrams.map { f / $0 * 100 } },
                        unit: "g"
                    )
                } header: {
                    HStack {
                        Text("Nutrition")
                        Spacer()
                        Text("Per \(food.servingDescription)")
                        if per != nil { Text("· Per 100 g") }
                    }
                } footer: {
                    if food.source == .barcode {
                        Text("Product data from Open Food Facts (ODbL), checked by you when saved.")
                    }
                }
                Section {
                    Button("Log This Food") { showLog = true }
                    if food.isCustom {
                        Button("Edit Nutrition") { showEdit = true }
                        Button("Delete Food", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle("Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showLog) {
                QuickLogFoodView(food: food)
            }
            .sheet(isPresented: $showEdit) {
                CustomFoodEditorView(existing: food) { env.saveCustomFood($0) }
            }
            .confirmationDialog("Delete \(food.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    env.deleteCustomFood(food)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Past food-log entries keep their values.")
            }
        }
    }

    private func nutritionRow(_ label: String, _ serving: Double?, _ per100: Double?, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(format(serving, unit)).monospacedDigit()
            if food.servingGrams != 100, food.nutritionPerGram() != nil {
                Text(format(per100, unit))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70, alignment: .trailing)
            }
        }
    }

    private func format(_ value: Double?, _ unit: String) -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }
}

/// Log a food to any of today's meals (used from the Foods tab).
private struct QuickLogFoodView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let food: FoodItem

    @State private var slot: MealSlot = .breakfast
    @State private var useServings = false
    @State private var amountText = ""

    private var slots: [MealSlot] {
        MealSlot.slots(isTrainingDay: env.profile.trainingSchedule.isTrainingDay(env.weekday(for: env.today)))
    }

    private var preview: (calories: Double, macros: MacroGrams)? {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard amount > 0 else { return nil }
        if useServings {
            return (
                (food.calories ?? 0) * amount,
                MacroGrams(
                    protein: (food.proteinGrams ?? 0) * amount,
                    carbohydrates: (food.carbohydrateGrams ?? 0) * amount,
                    fat: (food.fatGrams ?? 0) * amount
                )
            )
        }
        return food.scaled(toGrams: amount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MCFoodRow(food: food)
                }
                Section("Meal") {
                    Picker("Meal", selection: $slot) {
                        ForEach(slots, id: \.self) { Text(env.preferences.mealName(for: $0)).tag($0) }
                    }
                }
                Section("Amount") {
                    if food.servingGrams != nil {
                        Toggle("Log as servings", isOn: $useServings)
                    }
                    TextField(useServings ? "Servings (\(food.servingDescription))" : "Grams", text: $amountText)
                        .keyboardType(.decimalPad)
                    if let preview {
                        LabeledContent("Calories", value: "\(Int(preview.calories.rounded())) kcal")
                        LabeledContent("Protein", value: "\(Int(preview.macros.protein.rounded())) g")
                        LabeledContent("Carbs", value: "\(Int(preview.macros.carbohydrates.rounded())) g")
                        LabeledContent("Fat", value: "\(Int(preview.macros.fat.rounded())) g")
                    }
                }
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let preview,
                              let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) else { return }
                        env.logFood(
                            food,
                            amount: amount,
                            amountIsServings: useServings,
                            mealSlot: slot,
                            on: env.today,
                            calories: preview.calories,
                            macros: preview.macros
                        )
                        dismiss()
                    }
                    .disabled(preview == nil)
                }
            }
            .onAppear {
                slot = slots.first ?? .breakfast
                useServings = food.servingGrams == nil
                amountText = useServings ? "1" : String(format: "%.0f", food.servingGrams ?? 100)
            }
            .onChange(of: useServings) { _, servings in
                amountText = servings ? "1" : String(format: "%.0f", food.servingGrams ?? 100)
            }
        }
    }
}
