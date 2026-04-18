//
//  ElevenLabsService.swift
//  Appetight
//

import Foundation

actor ElevenLabsService {
    static let shared = ElevenLabsService()

    // Clyde — gruff war-veteran voice, fits the drill-sergeant persona
    private let voiceId = "DGzg6RaUqxGRTHSBjfgF"
    private let endpoint = "https://api.elevenlabs.io/v1/text-to-speech"

    func synthesize(text: String) async throws -> Data {
        let key = APIKeyStore.elevenLabs
        guard !key.isEmpty else { throw ElevenLabsError.missingKey }

        let url = URL(string: "\(endpoint)/\(voiceId)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "xi-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.75]
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw ElevenLabsError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }
}

enum ElevenLabsError: LocalizedError {
    case missingKey
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "ElevenLabs API key not set in Config.swift."
        case .httpError(let code): return "ElevenLabs error \(code)."
        }
    }
}
