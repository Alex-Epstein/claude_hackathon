//
//  Config.swift
//  Appetight
//
//  API keys live in UserDefaults. Views bind via @AppStorage for reactivity.
//  Services read directly from UserDefaults at call time.
//

import Foundation

// Keys are stored in Keys.swift (gitignored). See Keys.template.swift to set up.
nonisolated enum APIKeyStore {
    static let anthropic  = Keys.anthropic
    static let googleMaps = Keys.googleMaps
    static let honcho     = Keys.honcho
}
