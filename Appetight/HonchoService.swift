//
//  HonchoService.swift
//  Appetight
//
//  Manages Honcho peer memory and coach chat via REST.
//

import Foundation

actor HonchoService {
    static let shared = HonchoService()

    private let baseURL = "https://api.honcho.dev/v1"
    private let workspaceId = "appetight-app"
    private let sessionId = "main-session"

    private let coachSystemPrompt = """
    You are an adaptive fitness coach. You know this user's meal history, fitness goals, and patterns. \
    Be encouraging but honest. Keep responses under 3 sentences. Personalize based on everything you know.
    """

    private func apiKey() -> String { APIKeyStore.honcho }

    // MARK: - Public API

    func ensurePeer(name: String) async throws {
        let key = apiKey()
        guard !key.isEmpty else { throw HonchoError.missingKey }
        let peerId = slugify(name)
        let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/peers/\(peerId)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw HonchoError.invalidResponse }
        // 200 = created, 409 = already exists — both are fine
        guard http.statusCode < 400 || http.statusCode == 409 else {
            throw HonchoError.httpError(http.statusCode)
        }
    }

    func logMessage(_ text: String, peerName: String) async throws {
        let key = apiKey()
        guard !key.isEmpty else { throw HonchoError.missingKey }
        let peerId = slugify(peerName)
        let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/peers/\(peerId)/sessions/\(sessionId)/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "content": text,
            "is_user": true
        ])

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw HonchoError.invalidResponse
        }
    }

    /// Posts the structured persona summary as a context message so Honcho's memory
    /// layer incorporates both semantic history and aggregated eating statistics.
    func logPersonaSnapshot(_ context: String, peerName: String) async throws {
        try await logMessage("[Eating profile snapshot]\n\(context)", peerName: peerName)
    }

    func coachResponse(query: String, peerName: String, personaContext: String? = nil) async throws -> String {
        let key = apiKey()
        guard !key.isEmpty else { throw HonchoError.missingKey }
        let peerId = slugify(peerName)
        let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/peers/\(peerId)/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Combine system prompt + structured local stats + user query so Honcho's
        // semantic memory and the derived analytics both inform the response.
        let contextSection = personaContext.map { "\n\n\($0)" } ?? ""
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": "\(coachSystemPrompt)\(contextSection)\n\n\(query)",
            "session_id": sessionId
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw HonchoError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HonchoError.invalidResponse
        }

        // Try common response field names from dialectic APIs
        if let content = json["content"] as? String { return content }
        if let response = json["response"] as? String { return response }
        if let message = json["message"] as? String { return message }
        if let text = json["text"] as? String { return text }

        throw HonchoError.parseError
    }

    // MARK: - Helpers

    private func slugify(_ name: String) -> String {
        name.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}

enum HonchoError: LocalizedError {
    case missingKey
    case invalidResponse
    case httpError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Honcho API key not set."
        case .invalidResponse: return "Invalid response from Honcho."
        case .httpError(let code): return "Honcho error \(code)."
        case .parseError: return "Could not parse Honcho response."
        }
    }
}
