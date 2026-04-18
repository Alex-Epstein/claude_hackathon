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
    static let anthropic = "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"
    static let googleMaps = ""
    static let honcho = "hch-v3-p462qg5bz8whte3yw6cq91ju5vtjznl8abq2jhunldsa0coy06tjb2kwep202hru"
    static let elevenLabs = "sk_9c9acaba4fb7b044e670026ba8feddba2a860f742221ca13"  // paste your ElevenLabs API key here
}
