//
//  HungryView.swift
//  Appetight
//

import SwiftUI
import CoreLocation

struct HungryView: View {
    @EnvironmentObject var appState: AppState

    @State private var loading = false
    @State private var restaurants: [Restaurant] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("🍽️")
                    .font(.system(size: 40))
                Text("I'm Hungry")
                    .font(.title2.bold())
                Text("We'll scan \(caloriesText) of restaurants near you and surface the healthiest options for your goal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await findFood() }
            } label: {
                HStack {
                    if loading { ProgressView().tint(.white) }
                    Text(loading ? "Finding healthy options..." : "Find Food Near Me")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.orange)
            .controlSize(.large)
            .disabled(loading)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
            }

            if !restaurants.isEmpty {
                HStack {
                    Text("Healthy Picks Near You")
                        .font(.headline)
                    Spacer()
                    Button {
                        restaurants = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)

                ForEach(restaurants) { r in
                    RestaurantCard(restaurant: r) {
                        logOption(r)
                    }
                }
            }
        }
    }

    private var caloriesText: String {
        "\(appState.caloriesRemaining) kcal remaining"
    }

    private func logOption(_ r: Restaurant) {
        guard let opt = r.healthiestOption else { return }
        appState.addMeal(MealLog(
            name: "\(opt.name) (\(r.name))",
            calories: opt.calories,
            proteinG: opt.proteinG,
            carbsG: opt.carbsG,
            fatG: opt.fatG,
            source: .restaurant,
            restaurantName: r.name
        ))
        restaurants = []
    }

    private func findFood() async {
        loading = true
        errorMessage = nil
        defer { loading = false }

        do {
            let loc = try await LocationService.shared.requestLocation()
            let places = try await PlacesService.shared.nearbyRestaurants(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude
            )
            if places.isEmpty {
                errorMessage = "No restaurants found nearby."
                return
            }

            let recs = try await AnthropicService.shared.recommendRestaurantMeals(
                restaurants: places.map { ($0.name, $0.types) },
                userGoal: appState.profile?.goal.goalDescription ?? "maintain weight",
                caloriesRemaining: appState.caloriesRemaining
            )

            var enriched = places
            for rec in recs {
                let idx = rec.placeIndex - 1
                guard idx >= 0, idx < enriched.count else { continue }
                enriched[idx].cuisine = rec.cuisine
                enriched[idx].healthiestOption = HealthyOption(
                    name: rec.healthiestOption.name,
                    calories: rec.healthiestOption.calories,
                    proteinG: rec.healthiestOption.proteinG,
                    carbsG: rec.healthiestOption.carbsG,
                    fatG: rec.healthiestOption.fatG,
                    description: rec.healthiestOption.description,
                    whyHealthy: rec.healthiestOption.whyHealthy
                )
            }
            restaurants = enriched.filter { $0.healthiestOption != nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RestaurantCard: View {
    let restaurant: Restaurant
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(restaurant.name).font(.subheadline.bold())
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill").font(.caption2)
                        Text(distance)
                        if restaurant.rating > 0 {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption2)
                            Text(String(format: "%.1f", restaurant.rating))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                    Text(cuisine)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.gray.opacity(0.12), in: .capsule)
                }
            }

            if let opt = restaurant.healthiestOption {
                VStack(alignment: .leading, spacing: 4) {
                    Text(opt.name).font(.subheadline.weight(.medium))
                    Text(opt.description).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("\(opt.calories) kcal").font(.caption.bold()).foregroundStyle(Brand.green)
                        Text("P:\(Int(opt.proteinG))g C:\(Int(opt.carbsG))g F:\(Int(opt.fatG))g")
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button(action: onLog) {
                            Label("Log", systemImage: "checkmark").font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                    Text(opt.whyHealthy)
                        .font(.caption2)
                        .italic()
                        .foregroundStyle(Brand.green)
                }
                .padding(10)
                .background(Brand.green.opacity(0.08), in: .rect(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(.white, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.15)))
    }

    private var distance: String {
        if restaurant.distanceMeters < 1000 {
            return "\(restaurant.distanceMeters)m"
        }
        return String(format: "%.1fkm", Double(restaurant.distanceMeters) / 1000)
    }
}
