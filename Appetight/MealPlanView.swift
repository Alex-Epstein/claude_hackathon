//
//  MealPlanView.swift
//  Appetight
//

import SwiftUI
import EventKit

struct MealPlanView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var calendarSvc = CalendarService.shared

    @State private var events: [CalendarEvent] = []
    @State private var routeStops: [RouteStop] = []
    @State private var isGenerating = false
    @State private var generatingStep = ""
    @State private var errorMessage: String?
    @State private var addedToCalendar: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("🗺️")
                    .font(.system(size: 40))
                Text("Route Meal Planner")
                    .font(.title2.bold())
                Text("Claude finds restaurants on your route between events. Add \"@ location\" to event names for best results.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Connect calendar / generate button
            if !calendarSvc.authorized {
                Button {
                    Task {
                        let granted = await calendarSvc.requestAccess()
                        if granted { events = calendarSvc.restOfDayEvents() }
                    }
                } label: {
                    Label("Connect Calendar", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    Task { await generate() }
                } label: {
                    HStack {
                        if isGenerating { ProgressView().tint(.white) }
                        Image(systemName: "map.fill")
                        Text(isGenerating ? generatingStep : "Plan My Route")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isGenerating)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption).foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
            }

            // Route timeline
            if !events.isEmpty {
                routeTimeline
            }
        }
    }

    // MARK: - Route Timeline

    private var routeTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                eventNode(event)

                // Show food stop between this event and the next
                if idx < events.count - 1 {
                    if idx < routeStops.count {
                        stopView(routeStops[idx])
                    } else if isGenerating {
                        loadingConnector
                    } else {
                        emptyConnector
                    }
                }
            }
        }
    }

    // MARK: - Event node

    private func eventNode(_ event: CalendarEvent) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Brand.blue)
                .frame(width: 10, height: 10)
                .padding(.leading, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(event.startString) – \(event.endString)")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(event.title)
                    .font(.subheadline.bold())
                if let loc = event.extractedLocation {
                    Label(loc, systemImage: "mappin.fill")
                        .font(.caption2)
                        .foregroundStyle(Brand.green)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(Brand.blue.opacity(0.07), in: .rect(cornerRadius: 10))
    }

    // MARK: - Stop views

    private func stopView(_ stop: RouteStop) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            connectorBar(height: 10)

            if stop.restaurants.isEmpty {
                HStack {
                    connectorBar(height: 30)
                    Text("No restaurants found on this stretch")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.leading, 10)
                }
                connectorBar(height: 10)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        connectorBar(height: 8)
                        Circle().fill(.gray.opacity(0.3)).frame(width: 6, height: 6).padding(.leading, 5.5)
                        connectorBar(height: 8)
                        Spacer()
                        connectorBar(height: 8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Eat on the way", systemImage: "fork.knife")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.leading, 10)

                        ForEach(stop.restaurants) { restaurant in
                            restaurantCard(restaurant, stop: stop)
                        }
                    }
                    .padding(.bottom, 8)
                }
                connectorBar(height: 10)
            }
        }
    }

    private var loadingConnector: some View {
        HStack {
            connectorBar(height: 40)
            ProgressView().controlSize(.small).padding(.leading, 10)
            Text("Finding spots…").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var emptyConnector: some View {
        connectorBar(height: 20)
    }

    private func connectorBar(height: CGFloat) -> some View {
        Capsule()
            .fill(.gray.opacity(0.25))
            .frame(width: 2, height: height)
            .padding(.leading, 9)
    }

    // MARK: - Restaurant card

    private func restaurantCard(_ restaurant: RouteRestaurant, stop: RouteStop) -> some View {
        // Schedule the meal for the midpoint of the gap between the two events
        let mealTime: Date = {
            let gap = stop.toEvent.startDate.timeIntervalSince(stop.fromEvent.endDate)
            return stop.fromEvent.endDate.addingTimeInterval(max(gap / 2, 0))
        }()

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Brand.green).font(.subheadline)
                VStack(alignment: .leading, spacing: 1) {
                    Text(restaurant.name).font(.subheadline.bold())
                    Text("\(restaurant.distanceLabel) · \(restaurant.vicinity)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
            .padding(.bottom, 8)

            Divider()

            // Menu items
            ForEach(Array(restaurant.menuItems.enumerated()), id: \.offset) { idx, item in
                menuItemRow(item, restaurantName: restaurant.name, mealTime: mealTime)
                if idx < restaurant.menuItems.count - 1 {
                    Divider().padding(.leading, 4)
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.15)))
        .padding(.leading, 10)
    }

    // MARK: - Menu item row

    private func menuItemRow(_ item: MenuItem, restaurantName: String, mealTime: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.caption.bold()).lineLimit(2)
                Text(item.description)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(item.calories) kcal")
                        .font(.caption2.bold()).foregroundStyle(Brand.green)
                    Text(item.price)
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(item.whyHealthy)
                        .font(.caption2.italic()).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                // Log to today's intake
                Button {
                    appState.addMeal(MealLog(
                        name: item.name,
                        calories: item.calories,
                        proteinG: item.proteinG,
                        carbsG: item.carbsG,
                        fatG: item.fatG,
                        source: .restaurant,
                        restaurantName: restaurantName
                    ))
                } label: {
                    Label("Log", systemImage: "checkmark")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Brand.green.opacity(0.15), in: .capsule)
                        .foregroundStyle(Brand.green)
                }
                .buttonStyle(.plain)

                // Add to calendar
                if addedToCalendar.contains(item.id) {
                    Label("Added ✓", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Brand.green)
                } else {
                    Button {
                        addToCalendar(item, restaurantName: restaurantName, at: mealTime)
                    } label: {
                        Label("Add to Calendar", systemImage: "calendar.badge.plus")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Add to Calendar helper

    private func addToCalendar(_ item: MenuItem, restaurantName: String, at date: Date) {
        do {
            try calendarSvc.addMealEvent(
                title: "\(item.name) @ \(restaurantName)",
                at: date,
                calories: item.calories,
                notes: "\(item.description)\n\(item.whyHealthy)"
            )
            addedToCalendar.insert(item.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Generate

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        routeStops = []
        defer { isGenerating = false; generatingStep = "" }

        generatingStep = "Reading calendar…"
        events = calendarSvc.restOfDayEvents()

        guard !events.isEmpty else {
            errorMessage = "No upcoming events found today."
            return
        }

        guard events.count >= 2 else {
            errorMessage = "Add at least 2 upcoming events to get route recommendations. Tip: add \"@ location\" to event names."
            return
        }

        // Get current location once as fallback
        generatingStep = "Getting your location…"
        var fallback: (lat: Double, lng: Double)?
        if let loc = try? await LocationService.shared.requestLocation() {
            fallback = (loc.coordinate.latitude, loc.coordinate.longitude)
        }

        let goal = appState.profile?.goal.goalDescription ?? "maintain weight"
        let remaining = appState.caloriesRemaining

        var stops: [RouteStop] = []

        for i in 0..<(events.count - 1) {
            let fromEvent = events[i]
            let toEvent   = events[i + 1]

            // Geocode both event locations
            var fromCoord: (lat: Double, lng: Double)?
            var toCoord:   (lat: Double, lng: Double)?

            if let locStr = fromEvent.extractedLocation {
                generatingStep = "Locating \(locStr)…"
                fromCoord = await PlacesService.shared.geocodeLocation(locStr)
            }
            if let locStr = toEvent.extractedLocation {
                generatingStep = "Locating \(locStr)…"
                toCoord = await PlacesService.shared.geocodeLocation(locStr)
            }

            // Best center point for the search
            let center: (lat: Double, lng: Double)
            if let f = fromCoord, let t = toCoord {
                center = ((f.lat + t.lat) / 2, (f.lng + t.lng) / 2)
            } else if let f = fromCoord { center = f }
            else if let t = toCoord     { center = t }
            else if let fb = fallback   { center = fb }
            else {
                stops.append(RouteStop(fromEvent: fromEvent, toEvent: toEvent))
                continue
            }

            // Find nearby restaurants
            generatingStep = "Searching restaurants…"
            guard let nearby = try? await PlacesService.shared.nearbyRestaurants(
                lat: center.lat, lng: center.lng, radius: 800
            ), !nearby.isEmpty else {
                stops.append(RouteStop(fromEvent: fromEvent, toEvent: toEvent))
                continue
            }

            let topRestaurants = Array(nearby.prefix(2))

            // Ask Claude for menu suggestions
            generatingStep = "Getting menu ideas…"
            let payload = topRestaurants.map { (name: $0.name, types: $0.types) }
            let recs = (try? await AnthropicService.shared.recommendRestaurantMeals(
                restaurants: payload,
                userGoal: goal,
                caloriesRemaining: remaining
            )) ?? []

            let routeRestaurants: [RouteRestaurant] = topRestaurants.indices.compactMap { idx in
                let restaurant = topRestaurants[idx]
                // Claude uses 1-based place_index; fall back to positional match
                let rec: RestaurantRecommendation? =
                    recs.first(where: { $0.placeIndex == idx + 1 }) ??
                    (idx < recs.count ? recs[idx] : nil)
                guard let rec else { return nil }

                let items = rec.menuItems.prefix(3).map { p in
                    MenuItem(
                        name: p.name,
                        calories: p.calories,
                        proteinG: p.proteinG,
                        carbsG: p.carbsG,
                        fatG: p.fatG,
                        description: p.description,
                        whyHealthy: p.whyHealthy,
                        price: p.price
                    )
                }
                return RouteRestaurant(
                    placeId: restaurant.placeId,
                    name: restaurant.name,
                    vicinity: restaurant.vicinity,
                    distanceMeters: restaurant.distanceMeters,
                    menuItems: Array(items)
                )
            }

            stops.append(RouteStop(fromEvent: fromEvent, toEvent: toEvent, restaurants: routeRestaurants))
        }

        routeStops = stops

        if stops.allSatisfy({ $0.restaurants.isEmpty }) {
            errorMessage = "Couldn't find restaurants between your events. Try adding \"@ place name\" to your event titles."
        }
    }
}
