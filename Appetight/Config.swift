//
//  Config.swift
//  Appetight
//
//  API keys live in UserDefaults. Views bind via @AppStorage for reactivity.
//  Services read directly from UserDefaults at call time.
//

import Foundation

nonisolated enum APIKeyStore {
    // Paste your keys here before building
    static let anthropic = ""
    static let googleMaps = ""
}
