//
//  QuickAddView.swift
//  Appetight
//

import SwiftUI

struct QuickAddView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you eat?") {
                    TextField("Food name", text: $name)
                    TextField("Calories (kcal)", text: $calories)
                        .keyboardType(.numberPad)
                }
                Section("Macros (optional)") {
                    TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbs).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.isEmpty || Int(calories) == nil)
                }
            }
        }
    }

    private func save() {
        appState.addMeal(MealLog(
            name: name,
            calories: Int(calories) ?? 0,
            proteinG: Double(protein) ?? 0,
            carbsG: Double(carbs) ?? 0,
            fatG: Double(fat) ?? 0,
            source: .manual
        ))
        dismiss()
    }
}
