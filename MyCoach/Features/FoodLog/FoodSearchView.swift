import SwiftUI

struct FoodSearchView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let mealSlot: MealSlot
    let date: Date

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var results: [FoodItem] = []
    @State private var isSearching = false
    @State private var selectedFood: FoodItem?
    @State private var amountText = "100"
    @State private var useServings = false
    @State private var searchTask: Task<Void, Never>?
    @State private var showScanner = false
    @State private var scannedFood: FoodItem?

    var body: some View {
        NavigationStack {
            Group {
                if let selectedFood {
                    logDetail(selectedFood)
                } else {
                    searchList
                }
            }
            .navigationTitle(selectedFood == nil ? "Add Food" : "Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedFood == nil ? "Close" : "Back") {
                        if selectedFood != nil {
                            selectedFood = nil
                        } else {
                            dismiss()
                        }
                    }
                }
                if selectedFood == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                        .accessibilityLabel("Scan barcode")
                    }
                }
            }
            .sheet(isPresented: $showScanner, onDismiss: {
                if let scannedFood {
                    select(scannedFood)
                    self.scannedFood = nil
                }
            }) {
                ScanFoodFlowView { food in
                    scannedFood = food
                    showScanner = false
                }
            }
            .onAppear {
                Task { results = await env.searchFoods(query: "") }
            }
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    isSearching = true
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    guard !Task.isCancelled else { return }
                    debouncedQuery = newValue
                    results = await env.searchFoods(query: newValue)
                    isSearching = false
                }
            }
        }
    }

    private var searchList: some View {
        List {
            if isSearching {
                HStack {
                    ProgressView()
                    Text("Searching…")
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
            }
            if results.isEmpty && !debouncedQuery.isEmpty && !isSearching {
                ContentUnavailableView(
                    "No foods found",
                    systemImage: "magnifyingglass",
                    description: Text("Try another name, or create a custom food.")
                )
            }
            ForEach(results) { food in
                Button {
                    select(food)
                } label: {
                    MCFoodRow(food: food, showsChevron: true)
                }
            }
        }
        .searchable(text: $query, prompt: "Search chicken, rice, yogurt…")
    }

    private func select(_ food: FoodItem) {
        selectedFood = food
        useServings = food.servingGrams == nil
        amountText = useServings ? "1" : "100"
    }

    private func logDetail(_ food: FoodItem) -> some View {
        Form {
            Section {
                MCFoodRow(food: food)
            }
            Section("Amount") {
                Toggle("Log as servings", isOn: $useServings)
                TextField(useServings ? "Servings" : "Grams", text: $amountText)
                    .keyboardType(.decimalPad)
                if let preview = nutritionPreview(for: food) {
                    LabeledContent("Calories", value: "\(Int(preview.calories.rounded())) kcal")
                    LabeledContent("Protein", value: "\(Int(preview.macros.protein.rounded())) g")
                    LabeledContent("Carbs", value: "\(Int(preview.macros.carbohydrates.rounded())) g")
                    LabeledContent("Fat", value: "\(Int(preview.macros.fat.rounded())) g")
                }
            }
            Section {
                Button("Add to \(mealSlot.displayName)") {
                    guard let preview = nutritionPreview(for: food),
                          let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) else { return }
                    env.logFood(
                        food,
                        amount: amount,
                        amountIsServings: useServings,
                        mealSlot: mealSlot,
                        on: date,
                        calories: preview.calories,
                        macros: preview.macros
                    )
                    dismiss()
                }
                .font(MCTheme.Typography.headline)
                .foregroundStyle(MCTheme.ColorToken.primary)
            }
        }
    }

    private func nutritionPreview(for food: FoodItem) -> (calories: Double, macros: MacroGrams)? {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard amount > 0 else { return nil }
        if useServings {
            let cal = (food.calories ?? 0) * amount
            let macros = MacroGrams(
                protein: (food.proteinGrams ?? 0) * amount,
                carbohydrates: (food.carbohydrateGrams ?? 0) * amount,
                fat: (food.fatGrams ?? 0) * amount
            )
            return (cal, macros)
        }
        return food.scaled(toGrams: amount)
    }
}

#Preview {
    FoodSearchView(mealSlot: .breakfast, date: Date())
        .environment(AppEnvironment())
}
