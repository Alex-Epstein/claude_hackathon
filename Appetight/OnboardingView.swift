//
//  OnboardingView.swift
//  Appetight
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState

    @State private var name = ""
    @State private var age = ""
    @State private var weightKg = ""
    @State private var heightCm = ""
    @State private var gender: Gender = .male
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: Goal = .maintain
    @State private var result: TDEEResult?

    struct TDEEResult: Equatable {
        let tdee: Int
        let calorieGoal: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    var canCalculate: Bool {
        !age.isEmpty && !weightKg.isEmpty && !heightCm.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("🥗")
                        .font(.system(size: 56))
                    Text("Appetight")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Brand.green)
                    Text("Your AI-powered nutrition coach")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                profileCard

                if let result {
                    resultCard(result)
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Brand.green.opacity(0.08), .white],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Profile")
                .font(.title3.bold())

            labeled("Name") {
                TextField("Your name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                labeled("Age") {
                    TextField("25", text: $age)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
                labeled("Weight (kg)") {
                    TextField("70", text: $weightKg)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                labeled("Height (cm)") {
                    TextField("170", text: $heightCm)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
            }

            labeled("Gender") {
                HStack(spacing: 6) {
                    ForEach(Gender.allCases) { g in
                        ChoiceButton(title: g.label, isSelected: gender == g) {
                            gender = g
                        }
                    }
                }
            }

            labeled("Activity Level") {
                VStack(spacing: 6) {
                    ForEach(ActivityLevel.allCases) { lvl in
                        ChoiceButton(title: lvl.label, isSelected: activity == lvl, alignment: .leading) {
                            activity = lvl
                        }
                    }
                }
            }

            labeled("Goal") {
                HStack(spacing: 6) {
                    ForEach(Goal.allCases) { g in
                        ChoiceButton(title: g.label, isSelected: goal == g) {
                            goal = g
                        }
                    }
                }
            }

            Button(action: calculate) {
                Text("Calculate")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canCalculate)
            .padding(.top, 4)
        }
        .padding()
        .background(.white, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    @ViewBuilder
    private func resultCard(_ r: TDEEResult) -> some View {
        VStack(spacing: 12) {
            Text("Your Results")
                .font(.title3.bold())
                .foregroundStyle(Brand.green)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                Text("\(r.calorieGoal)")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Brand.green)
                Text("calories per day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("TDEE: \(r.tdee) kcal")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.gray.opacity(0.12), in: .capsule)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                macroTile("\(r.protein)g", "Protein", Brand.blue.opacity(0.15))
                macroTile("\(r.carbs)g", "Carbs", Brand.yellow.opacity(0.2))
                macroTile("\(r.fat)g", "Fat", Brand.red.opacity(0.12))
            }

            Button(action: save) {
                Text("Save & Start Tracking")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(name.isEmpty)
        }
        .padding()
        .background(.white, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(Brand.green, lineWidth: 2)
        )
    }

    private func macroTile(_ value: String, _ label: String, _ bg: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(bg, in: .rect(cornerRadius: 10))
    }

    private func labeled<V: View>(_ title: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func calculate() {
        guard let ageInt = Int(age),
              let wkg = Double(weightKg),
              let hcm = Double(heightCm)
        else { return }
        let tdee = TDEE.calculateTDEE(weightKg: wkg, heightCm: hcm, age: ageInt, gender: gender, activity: activity)
        let calGoal = TDEE.calorieGoal(tdee: tdee, goal: goal)
        let m = TDEE.macros(calories: calGoal, goal: goal)
        result = TDEEResult(tdee: tdee, calorieGoal: calGoal, protein: m.protein, carbs: m.carbs, fat: m.fat)
    }

    private func save() {
        guard let result,
              let ageInt = Int(age),
              let wkg = Double(weightKg),
              let hcm = Double(heightCm)
        else { return }
        appState.profile = UserProfile(
            name: name,
            age: ageInt,
            weightKg: wkg,
            heightCm: hcm,
            gender: gender,
            activityLevel: activity,
            goal: goal,
            tdee: result.tdee,
            calorieGoal: result.calorieGoal
        )
    }
}

struct ChoiceButton: View {
    let title: String
    let isSelected: Bool
    var alignment: HorizontalAlignment = .center
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if alignment == .leading { Text(title); Spacer() }
                else { Spacer(); Text(title); Spacer() }
            }
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Brand.green : Color.gray.opacity(0.08))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
