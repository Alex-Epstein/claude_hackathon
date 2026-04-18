//
//  Config.swift
//  Appetight
//
//  API keys live in UserDefaults. Views bind via @AppStorage for reactivity.
//  Services read directly from UserDefaults at call time.
//

import Foundation

nonisolated enum APIKeyStore {
    static let anthropicKey = "anthropic_api_key"
    static let googleMapsKey = "google_maps_api_key"

    static var anthropic: String {
        UserDefaults.standard.string(forKey: anthropicKey) ?? ""
    }
    static var googleMaps: String {
        UserDefaults.standard.string(forKey: googleMapsKey) ?? ""
    }
}
