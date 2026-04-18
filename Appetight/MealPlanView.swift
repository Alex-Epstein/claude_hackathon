//
//  MealPlanView.swift
//  Appetight
//

import SwiftUI
import EventKit

struct MealPlanView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var calendar = CalendarService.shared

    @State private var loading = false
    @State private var plan: MealPlanResult?
    @State private var events: [CalendarEvent] = []
    @State private var errorMessage: String?
    @State private var addedToCalendar: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("📅")
                    .font(.system(size: 40))
                Text("Meal Planning")
                    .font(.title2.bold())
                Text("Claude reads your calendar and builds a meal plan around your day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Calendar access / generate button
            if !calendar.authorized {
                Button {
                    Task {
                        let granted = await calendar.requestAccess()
                        if granted { events = calendar.todayEvents() }
                    }
                } label: {
                    Label("Connect Calendar", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    Task { await generate() }
                } label: {
                    HStack {
                        if loading { ProgressView().tint(.white) }
                        Image(systemName: "wand.and.stars")
                        Text(loading ? "Planning..." : "Generate Today's Plan")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(loading)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption).foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
            }

            // Today's schedule preview
            if !events.isEmpty {
                scheduleStrip
            }

            // Meal plan
            if let plan {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Today's Meal Plan")
                            .font(.headline)
                        Spacer()
                        Text(plan.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 160)
                    }

                    ForEach(plan.meals) { meal in
                        mealCard(meal)
                    }
                }
            }
        }
    }

    // MARK: - Schedule strip

    private var scheduleStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Today's Calendar", systemImage: "calendar")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(events, id: \.startDate) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.caption2.bold())
                                .lineLimit(1)
                            Text("\(event.startString) – \(event.endString)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Brand.blue.opacity(0.1), in: .rect(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Meal card

    private func mealCard(_ meal: PlannedMeal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(spacing: 2) {
                Text(meal.timeLabel)
                    .font(.caption.bold())
                    .foregroundStyle(Brand.green)
                    .frame(width: 56)
            }
            .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name).font(.subheadline.bold())
                Text(meal.description).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text("\(meal.calories) kcal")
                        .font(.caption.bold())
                        .foregroundStyle(Brand.green)
                    Spacer()
                    Text(meal.reason)
                        .font(.caption2).italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }

                HStack(spacing: 8) {
                    Button {
                        appState.addMeal(MealLog(
                            name: meal.name,
                            calories: meal.calories,
                            proteinG: 0,
                            carbsG: 0,
                            fatG: 0,
                            source: .manual
                        ))
                    } label: {
                        Label("Log Now", systemImage: "checkmark")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)

                    if !addedToCalendar.contains(meal.id) {
                        Button {
                            addToCalendar(meal)
                        } label: {
                            Label("Add to Calendar", systemImage: "calendar.badge.plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    } else {
                        Label("Added ✓", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Brand.green)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.12)))
    }

    // MARK: - Actions

    private func generate() async {
        loading = true
        errorMessage = nil
        defer { loading = false }

        if calendar.authorized {
            events = calendar.todayEvents()
        }

        let eventPayload = events.map { (title: $0.title, start: $0.startString, end: $0.endString) }
        let goal = appState.profile?.goal.goalDescription ?? "maintain weight"
        let calories = appState.profile?.calorieGoal ?? 2000
        let ctx = appState.personaContext.isEmpty ? nil : appState.personaContext

        do {
            plan = try await AnthropicService.shared.generateMealPlan(
                events: eventPayload,
                calorieGoal: calories,
                goal: goal,
                personaContext: ctx
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addToCalendar(_ meal: PlannedMeal) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = meal.hour
        components.minute = meal.minute
        guard let date = Calendar.current.date(from: components) else { return }

        do {
            try calendar.addMealEvent(
                title: meal.name,
                at: date,
                calories: meal.calories,
                notes: meal.description
            )
            addedToCalendar.insert(meal.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
