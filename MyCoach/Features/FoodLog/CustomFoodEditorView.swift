import SwiftUI

struct CustomFoodEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var existing: FoodItem? = nil
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

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle(existing == nil ? "Create Food" : "Edit Nutrition")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    brand = existing.brand ?? ""
                    servingDescription = existing.servingDescription
                    servingGrams = existing.servingGrams.map { String(format: "%.0f", $0) } ?? ""
                    calories = existing.calories.map { String(format: "%.0f", $0) } ?? ""
                    protein = existing.proteinGrams.map { String(format: "%.1f", $0) } ?? ""
                    carbs = existing.carbohydrateGrams.map { String(format: "%.1f", $0) } ?? ""
                    fat = existing.fatGrams.map { String(format: "%.1f", $0) } ?? ""
                    fibre = existing.fibreGrams.map { String(format: "%.1f", $0) } ?? ""
                    measurementState = existing.measurementState
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(calories) != nil
    }

    private func save() {
        let food = FoodItem(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.isEmpty ? nil : brand,
            source: .customUser,
            servingDescription: servingDescription,
            servingGrams: Double(servingGrams),
            calories: Double(calories),
            proteinGrams: Double(protein),
            carbohydrateGrams: Double(carbs),
            fatGrams: Double(fat),
            fibreGrams: Double(fibre),
            measurementState: measurementState,
            isCustom: true,
            isVerified: false
        )
        onSave(food)
        dismiss()
    }
}

#Preview {
    CustomFoodEditorView { _ in }
}
