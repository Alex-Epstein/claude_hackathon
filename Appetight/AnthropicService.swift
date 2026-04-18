//
//  AnthropicService.swift
//  Appetight
//

import Foundation

struct FoodAnalysis: Codable {
    let name: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let servingDescription: String?

    enum CodingKeys: String, CodingKey {
        case name, calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case servingDescription = "serving_description"
    }
}

struct RestaurantRecommendation: Codable {
    let placeIndex: Int
    let restaurantName: String
    let cuisine: String
    let healthiestOption: HealthyOptionPayload

    enum CodingKeys: String, CodingKey {
        case placeIndex = "place_index"
        case restaurantName = "restaurant_name"
        case cuisine
        case healthiestOption = "healthiest_option"
    }
}

struct HealthyOptionPayload: Codable {
    let name: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let description: String
    let whyHealthy: String

    enum CodingKeys: String, CodingKey {
        case name, calories, description
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case whyHealthy = "why_healthy"
    }
}

enum AnthropicError: LocalizedError {
    case missingKey
    case invalidResponse
    case httpError(Int, String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Anthropic API key not set — add it in Settings."
        case .invalidResponse: return "Invalid response from Claude."
        case .httpError(let code, let msg): return "API error \(code): \(msg)"
        case .parseError(let raw): return "Could not parse response: \(raw.prefix(120))"
        }
    }
}

actor AnthropicService {
    static let shared = AnthropicService()

    private let model = "claude-haiku-4-5-20251001"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private func apiKey() -> String { APIKeyStore.anthropic }

    // MARK: - Food image analysis

    func analyzeFoodImage(base64Jpeg: String) async throws -> FoodAnalysis {
        let key = apiKey()
        guard !key.isEmpty else { throw AnthropicError.missingKey }

        let systemPrompt = """
        You are a nutrition expert. Analyze food images and reply ONLY with a JSON object:
        {
          "name": "food name",
          "calories": number,
          "protein_g": number,
          "carbs_g": number,
          "fat_g": number,
          "serving_description": "e.g. 1 cup, 200g"
        }
        If multiple foods, sum the totals. Be accurate and concise.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64Jpeg,
                        ],
                    ],
                    ["type": "text", "text": "What is this food and what are its nutrition facts?"],
                ],
            ]],
        ]

        let raw = try await sendRequest(body: body, apiKey: key)
        return try decodeJSON(raw)
    }

    // MARK: - Voice transcript → food analysis

    func analyzeVoiceLog(transcript: String) async throws -> FoodAnalysis {
        let key = apiKey()
        guard !key.isEmpty else { throw AnthropicError.missingKey }

        let systemPrompt = """
        You are a nutrition expert. Parse food descriptions and reply ONLY with a JSON object:
        {
          "name": "food name",
          "calories": number,
          "protein_g": number,
          "carbs_g": number,
          "fat_g": number
        }
        Use standard portion sizes if not specified.

        If multiple, show the aggregate macros. Be accurate and concise - overestimate if needed.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "system": systemPrompt,
            "messages": [[
                "role": "user",
                "content": "I ate: \(transcript)",
            ]],
        ]

        let raw = try await sendRequest(body: body, apiKey: key)
        return try decodeJSON(raw)
    }

    // MARK: - Restaurant recommendations

    func recommendRestaurantMeals(
        restaurants: [(name: String, types: [String])],
        userGoal: String,
        caloriesRemaining: Int
    ) async throws -> [RestaurantRecommendation] {
        let key = apiKey()
        guard !key.isEmpty else { throw AnthropicError.missingKey }

        let list = restaurants.enumerated().map { i, r in
            "\(i + 1). \(r.name) (\(r.types.prefix(2).joined(separator: ", ")))"
        }.joined(separator: "\n")

        let systemPrompt = """
        You are a nutrition expert helping someone make healthy restaurant choices. Reply ONLY with a JSON array of recommendations — one for each restaurant. Format:
        [{
          "place_index": number,
          "restaurant_name": "name",
          "cuisine": "type",
          "healthiest_option": {
            "name": "dish name",
            "calories": number,
            "protein_g": number,
            "carbs_g": number,
            "fat_g": number,
            "description": "brief description",
            "why_healthy": "one sentence"
          }
        }]
        """

        let userPrompt = """
        My goal is to \(userGoal). I have \(caloriesRemaining) calories remaining today.

        Nearby restaurants:
        \(list)

        For each restaurant, suggest the healthiest menu option that fits my remaining calories.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt]],
        ]

        let raw = try await sendRequest(body: body, apiKey: key)
        return try decodeJSONArray(raw)
    }

    // MARK: - Gym busy times

    func gymBusyTimes(gymName: String) async throws -> GymData {
        let key = apiKey()
        guard !key.isEmpty else { throw AnthropicError.missingKey }

        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        let dayOfWeek = df.string(from: now)
        let hour = Calendar.current.component(.hour, from: now)

        let systemPrompt = """
        You are a gym analytics expert. Generate realistic gym busy time data for today. Reply ONLY with JSON:
        {
          "gym_name": "name",
          "busy_times": [{"hour": 6, "busyness": 30, "label": "6 AM"}, …for hours 5 through 23],
          "recommended_time": "e.g. 2 PM",
          "recommended_hour": 14,
          "reason": "brief explanation"
        }
        Busyness is 0–100. Typical patterns: morning rush 7–9am, lunch 12–1pm, evening rush 5–7pm.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [[
                "role": "user",
                "content": "Gym: \(gymName). Today is \(dayOfWeek). Current time: \(hour):00. What are the busy times and when should I go?",
            ]],
        ]

        let raw = try await sendRequest(body: body, apiKey: key)
        return try decodeGymData(raw)
    }

    // MARK: - HTTP

    private func sendRequest(body: [String: Any], apiKey: String) async throws -> String {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        if http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw AnthropicError.httpError(http.statusCode, msg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String
        else {
            throw AnthropicError.invalidResponse
        }
        return text
    }

    // MARK: - JSON extraction

    private func extractJSONObject(_ text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}")
        else { return nil }
        return String(text[start ... end])
    }

    private func extractJSONArray(_ text: String) -> String? {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]")
        else { return nil }
        return String(text[start ... end])
    }

    private func decodeJSON(_ raw: String) throws -> FoodAnalysis {
        guard let json = extractJSONObject(raw),
              let data = json.data(using: .utf8)
        else { throw AnthropicError.parseError(raw) }
        do {
            return try JSONDecoder().decode(FoodAnalysis.self, from: data)
        } catch {
            throw AnthropicError.parseError(raw)
        }
    }

    private func decodeJSONArray(_ raw: String) throws -> [RestaurantRecommendation] {
        guard let json = extractJSONArray(raw),
              let data = json.data(using: .utf8)
        else { throw AnthropicError.parseError(raw) }
        do {
            return try JSONDecoder().decode([RestaurantRecommendation].self, from: data)
        } catch {
            throw AnthropicError.parseError(raw)
        }
    }

    private func decodeGymData(_ raw: String) throws -> GymData {
        guard let json = extractJSONObject(raw),
              let data = json.data(using: .utf8)
        else { throw AnthropicError.parseError(raw) }

        // We accept snake_case from Claude
        let dec = JSONDecoder()
        struct Payload: Codable {
            let gymName: String
            let busyTimes: [BusyTime]
            let recommendedTime: String
            let recommendedHour: Int
            let reason: String
            enum CodingKeys: String, CodingKey {
                case gymName = "gym_name"
                case busyTimes = "busy_times"
                case recommendedTime = "recommended_time"
                case recommendedHour = "recommended_hour"
                case reason
            }
        }
        do {
            let p = try dec.decode(Payload.self, from: data)
            return GymData(
                gymName: p.gymName,
                busyTimes: p.busyTimes,
                recommendedTime: p.recommendedTime,
                recommendedHour: p.recommendedHour,
                reason: p.reason
            )
        } catch {
            throw AnthropicError.parseError(raw)
        }
    }
}
