//
//  PlacesService.swift
//  Appetight
//

import Foundation
import CoreLocation

enum PlacesError: LocalizedError {
    case missingKey
    case noResults
    case httpError(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Google Maps API key not set — add it in Settings."
        case .noResults: return "No places found nearby."
        case .httpError(let m): return m
        }
    }
}

actor PlacesService {
    static let shared = PlacesService()

    private func apiKey() -> String { APIKeyStore.googleMaps }

    func nearbyRestaurants(lat: Double, lng: Double, radius: Int = 1500) async throws -> [Restaurant] {
        let key = apiKey()
        guard !key.isEmpty else { throw PlacesError.missingKey }

        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(lat),\(lng)&radius=\(radius)&type=restaurant&key=\(key)"
        guard let url = URL(string: urlString) else { throw PlacesError.httpError("Bad URL") }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try parseRestaurants(data: data, originLat: lat, originLng: lng)
    }

    func fetchPhoneNumber(placeId: String) async -> String? {
        let key = apiKey()
        guard !key.isEmpty else { return nil }
        let urlString = "https://maps.googleapis.com/maps/api/place/details/json?place_id=\(placeId)&fields=formatted_phone_number&key=\(key)"
        guard let url = URL(string: urlString) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let phone = result["formatted_phone_number"] as? String
        else { return nil }
        return phone
    }

    func nearbyGyms(lat: Double, lng: Double, radius: Int = 5000) async throws -> [NearbyGym] {
        let key = apiKey()
        guard !key.isEmpty else { throw PlacesError.missingKey }

        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(lat),\(lng)&radius=\(radius)&type=gym&key=\(key)"
        guard let url = URL(string: urlString) else { throw PlacesError.httpError("Bad URL") }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else { return [] }

        return results.prefix(5).compactMap { raw -> NearbyGym? in
            guard let placeId = raw["place_id"] as? String,
                  let name = raw["name"] as? String,
                  let geometry = raw["geometry"] as? [String: Any],
                  let location = geometry["location"] as? [String: Any],
                  let rlat = location["lat"] as? Double,
                  let rlng = location["lng"] as? Double
            else { return nil }
            let vicinity = (raw["vicinity"] as? String) ?? ""
            let rating = (raw["rating"] as? Double) ?? 0
            let dLat = (rlat - lat) * 111320
            let dLng = (rlng - lng) * 111320 * cos(lat * .pi / 180)
            let dist = Int(sqrt(dLat * dLat + dLng * dLng).rounded())
            return NearbyGym(placeId: placeId, name: name, vicinity: vicinity, rating: rating, distanceMeters: dist)
        }
    }

    private func parseRestaurants(data: Data, originLat: Double, originLng: Double) throws -> [Restaurant] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else {
            throw PlacesError.noResults
        }
        if let status = json["status"] as? String, status != "OK", status != "ZERO_RESULTS" {
            let msg = (json["error_message"] as? String) ?? status
            throw PlacesError.httpError(msg)
        }

        let limited = results.prefix(8)
        return limited.compactMap { raw in
            guard let placeId = raw["place_id"] as? String,
                  let name = raw["name"] as? String,
                  let geometry = raw["geometry"] as? [String: Any],
                  let location = geometry["location"] as? [String: Any],
                  let rlat = location["lat"] as? Double,
                  let rlng = location["lng"] as? Double
            else { return nil }

            let vicinity = (raw["vicinity"] as? String) ?? ""
            let rating = (raw["rating"] as? Double) ?? 0
            let types = (raw["types"] as? [String]) ?? []

            let dLat = (rlat - originLat) * 111320
            let dLng = (rlng - originLng) * 111320 * cos(originLat * .pi / 180)
            let dist = Int(sqrt(dLat * dLat + dLng * dLng).rounded())

            return Restaurant(
                placeId: placeId,
                name: name,
                vicinity: vicinity,
                rating: rating,
                distanceMeters: dist,
                types: types
            )
        }
    }
}
