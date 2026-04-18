//
//  HonchoService.swift
//  Appetight
//
//  Manages Honcho peer memory and coach chat via REST.
//

import Foundation

actor HonchoService {
    static let shared = HonchoService()

    private let baseURL = "https://api.honcho.dev"
    private let workspaceId = "claude_hackathon"
    private let sessionId = "appetight_app"

    private let coachSystemPrompt = """
    You are a drill sergeant coach. You know this user's meal history, fitness goals, and patterns. \
    Be firm like a real tough guy, be kinda evil too. Keep responses short and try to end with exclamation marks and emojis!! Keep responses very short (12 words / 1 sentence)
    """

    private func apiKey() -> String { APIKeyStore.honcho }

    // MARK: - Public API

    func ensurePeer(name: String) async throws {
        let key = apiKey()
        guard !key.isEmpty else { throw HonchoError.missingKey }
        let peerId = slugify(name)
        let url = URL(string: "\(baseURL)/v3/workspaces/\(workspaceId)/peers")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["id": peerId])

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw HonchoError.invalidResponse }
        guard http.statusCode < 400 || http.statusCode == 409 else {
            throw HonchoError.httpError(http.statusCode)
        }
    }

    func logMessage(_ text: String, peerName: String) async throws {
        let key = apiKey()
        guard !key.isEmpty else { throw HonchoError.missingKey }
        let peerId = slugify(peerName)
        let url = URL(string: "\(baseURL)/v3/workspaces/\(workspaceId)/sessions/\(sessionId)/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "messages": [["peer_id": peerId, "content": text]]
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
        let url = URL(string: "\(baseURL)/v3/workspaces/\(workspaceId)/peers/\(peerId)/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let contextSection = personaContext.map { "\n\n\($0)" } ?? ""
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": "\(coachSystemPrompt)\(contextSection)\n\n\(query)",
            "reasoning_level": "low"
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw HonchoError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let raw = String(data: data, encoding: .utf8) ?? "(empty)"
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HonchoError.parseError(raw)
        }
        if let content = json["content"] as? String { return content }
        if let answer = json["answer"] as? String { return answer }
        throw HonchoError.parseError(raw)
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
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Honcho API key not set."
        case .invalidResponse: return "Invalid response from Honcho."
        case .httpError(let code): return "Honcho HTTP \(code)."
        case .parseError(let raw): return "Parse error: \(raw.prefix(200))"
        }
    }
}
