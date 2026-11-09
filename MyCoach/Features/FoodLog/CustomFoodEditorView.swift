import SwiftUI

struct CustomFoodEditorView: View {
    @Environment(\.dismiss) private var dismiss

    /// Food being edited (keeps its id).
    var existing: FoodItem? = nil
    /// Starting values for a *new* food, e.g. a scanned product — saved with its id and barcode.
    var prefill: FoodItem? = nil
    /// Shown above the form (e.g. data source or "not found" guidance).
    var notice: String? = nil
    var title: String? = nil
    var onSave: (FoodItem) -> Void

    @State private var name = ""
    @State private var brand = ""
    @State private var servingDescription = "100 g"
    @State private var servingGrams = "100"
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fibre = ""
    @State private var measurementState: MeasurementState = .prepared
    @State private var loaded = false

    private var base: FoodItem? { existing ?? prefill }

    var body: some View {
        NavigationStack {
            Form {
                if notice != nil || base?.barcode != nil {
                    Section {
                        if let notice {
                            Label(notice, systemImage: "info.circle")
                                .font(MCTheme.Typography.subheadline)
                        }
                        if let barcode = base?.barcode {
                            Label("Barcode \(barcode)", systemImage: "barcode")
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Identity") {
                    TextField("Food name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    Picker("Measurement", selection: $measurementState) {
                        ForEach(MeasurementState.allCases) { state in
                            Text(state.displayName).tag(state)
                        }
                    }
                    TextField("Serving description", text: $servingDescription)
                    TextField("Serving grams", text: $servingGrams)
                        .keyboardType(.decimalPad)
                }

                Section("Nutrition (per serving)") {
                    TextField("Calories", text: $calories).keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbs).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat).keyboardType(.decimalPad)
                    TextField("Fibre (g, optional)", text: $fibre).keyboardType(.decimalPad)
                }

                Section {
                    Text("Saved as your custom food. Meal plan calculations will use these values.")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title ?? (existing == nil ? "Create Food" : "Edit Nutrition"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private static func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let base else { return }
        name = base.name
        brand = base.brand ?? ""
        servingDescription = base.servingDescription
        servingGrams = base.servingGrams.map { String(format: "%.0f", $0) } ?? ""
        calories = base.calories.map { String(format: "%.0f", $0) } ?? ""
        protein = base.proteinGrams.map { String(format: "%.1f", $0) } ?? ""
        carbs = base.carbohydrateGrams.map { String(format: "%.1f", $0) } ?? ""
        fat = base.fatGrams.map { String(format: "%.1f", $0) } ?? ""
        fibre = base.fibreGrams.map { String(format: "%.1f", $0) } ?? ""
        measurementState = base.measurementState
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && Self.parse(calories) != nil
    }

    private func save() {
        let food = FoodItem(
            id: base?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.isEmpty ? nil : brand,
            source: base?.barcode != nil ? .barcode : .customUser,
            servingDescription: servingDescription,
            servingGrams: Self.parse(servingGrams),
            calories: Self.parse(calories),
            proteinGrams: Self.parse(protein) ?? 0,
            carbohydrateGrams: Self.parse(carbs) ?? 0,
            fatGrams: Self.parse(fat) ?? 0,
            fibreGrams: Self.parse(fibre),
            measurementState: measurementState,
            barcode: base?.barcode,
            isCustom: true,
            isVerified: false,
            allergenTags: base?.allergenTags ?? [],
            isFavorite: base?.isFavorite ?? false
        )
        onSave(food)
        dismiss()
    }
}

#Preview {
    CustomFoodEditorView { _ in }
}
