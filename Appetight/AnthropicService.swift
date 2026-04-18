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
    let menuItems: [MenuItemPayload]

    enum CodingKeys: String, CodingKey {
        case placeIndex = "place_index"
        case restaurantName = "restaurant_name"
        case cuisine
        case menuItems = "menu_items"
    }
}

struct MenuItemPayload: Codable {
    let name: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let description: String
    let whyHealthy: String
    let price: String

    enum CodingKeys: String, CodingKey {
        case name, calories, description, price
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

    func analyzeFoodImage(base64Jpeg: String, personaContext: String? = nil) async throws -> FoodAnalysis {
        let key = apiKey()
        guard !key.isEmpty else { throw AnthropicError.missingKey }
        let systemPrompt = """
        You are a nutrition expert. Analyze food images and reply ONLY with a JSON object — no markdown, no code fences:
        {"name":"food name","calories":0,"protein_g":0,"carbs_g":0,"fat_g":0,"serving_description":"e.g. 1 cup"}
        If multiple foods, sum the totals. Start your response with { and end with }.
        \(personaContext ?? "")
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

    func analyzeVoiceLog(transcript: String, personaContext: String? = nil) async throws -> FoodAnalysis {
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
        \(personaContext ?? "")
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
        You are a nutrition expert. Output ONLY raw JSON — no markdown, no code fences, no explanation.
        Return a JSON array. Each element must follow this exact schema:
        {
          "place_index": 1,
          "restaurant_name": "Chipotle",
          "cuisine": "Mexican",
          "menu_items": [
            {
              "name": "Burrito Bowl (chicken, fajita veggies, black beans, salsa)",
              "calories": 540,
              "protein_g": 43,
              "carbs_g": 62,
              "fat_g": 11,
              "description": "High protein bowl, no cheese or sour cream",
              "why_healthy": "Low fat, high protein, complex carbs",
              "price": "$10.50"
            }
          ]
        }
        Include 3 menu items per restaurant ranked healthiest first. Use REAL estimated calorie counts — never 0. Start response with [ and end with ].
        """

        let userPrompt = """
        My goal is to \(userGoal). I have \(caloriesRemaining) calories remaining today.

        Nearby restaurants:
        \(list)

        For each restaurant, suggest the healthiest menu option that fits my remaining calories.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
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
        You are a gym analytics expert. Generate realistic gym busy time data for today. Reply ONLY with raw JSON — no markdown:
        {
          "gym_name": "name",
          "price_range": "$30-50/month",
          "busy_times": [{"hour": 6, "busyness": 30, "label": "6 AM"}, {"hour": 7, "busyness": 55, "label": "7 AM"}],
          "recommended_time": "2 PM",
          "recommended_hour": 14,
          "best_times": ["2 PM", "10 AM", "8 PM"],
          "reason": "brief explanation"
        }
        Include hours 5 through 23 in busy_times. Busyness is 0–100. Typical patterns: morning rush 7–9am, lunch 12–1pm, evening rush 5–7pm. Start response with {.
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

    // MARK: - Meal plan

    func generateMealPlan(
        events: [(title: String, start: String, end: String)],
        calorieGoal: Int,
        goal: String,
        personaContext: String?
    ) async throws -> MealPlanResult {
        let key = apiKey()
        guard !key.isEmpty else { throw AnthropicError.missingKey }

        let schedule = events.isEmpty
            ? "No calendar events today — free schedule."
            : events.map { "- \($0.title): \($0.start) – \($0.end)" }.joined(separator: "\n")

        let systemPrompt = """
        You are a nutrition coach. Output ONLY raw JSON — no markdown, no code fences. Schema:
        {
          "meals": [
            {"name":"Overnight oats","time_label":"7:30 AM","hour":7,"minute":30,"calories":420,"description":"High protein oats with berries","reason":"Before 9am meeting, easy prep"},
            ...
          ],
          "summary": "One sentence overall plan rationale"
        }
        Plan 3-5 meals/snacks spread across the day. Avoid scheduling meals during events. Use REAL calorie values summing to ~\(calorieGoal) kcal.
        \(personaContext ?? "")
        """

        let userPrompt = """
        Goal: \(goal). Daily calorie target: \(calorieGoal) kcal.

        Today's schedule:
        \(schedule)

        Create a personalized meal plan that works around this schedule.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt]],
        ]

        let raw = try await sendRequest(body: body, apiKey: key)
        guard let json = extractJSONObject(raw), let data = json.data(using: .utf8) else {
            throw AnthropicError.parseError(raw)
        }
        do {
            return try JSONDecoder().decode(MealPlanResult.self, from: data)
        } catch {
            throw AnthropicError.parseError(raw)
        }
    }

    // MARK: - Coach chat

    func coachReply(
        history: [(role: String, content: String)],
        personaContext: String?,
        userName: String
    ) async throws -> String {
        let key = apiKey()
        guard !key.isEmpty else { throw AnthropicError.missingKey }

        let systemPrompt = """
        You are \(userName)'s personal nutrition and fitness coach. Be warm, encouraging, and concise — keep replies to 2–3 sentences max.
        Personalize every response using what you know about them.
        \(personaContext ?? "")
        """

        let messages = history.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "system": systemPrompt,
            "messages": messages,
        ]

        return try await sendRequest(body: body, apiKey: key)
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

    /// Strip markdown code fences (```json ... ``` or ``` ... ```) then extract.
    private func stripFences(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove opening fence
        if t.hasPrefix("```") {
            if let newline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: newline)...])
            }
        }
        // Remove closing fence
        if t.hasSuffix("```") {
            t = String(t.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    private func extractJSONObject(_ text: String) -> String? {
        let t = stripFences(text)
        guard let start = t.firstIndex(of: "{"),
              let end = t.lastIndex(of: "}")
        else { return nil }
        return String(t[start ... end])
    }

    private func extractJSONArray(_ text: String) -> String? {
        let t = stripFences(text)
        guard let start = t.firstIndex(of: "["),
              let end = t.lastIndex(of: "]")
        else { return nil }
        return String(t[start ... end])
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
            let priceRange: String
            let busyTimes: [BusyTime]
            let recommendedTime: String
            let recommendedHour: Int
            let bestTimes: [String]
            let reason: String
            enum CodingKeys: String, CodingKey {
                case gymName = "gym_name"
                case priceRange = "price_range"
                case busyTimes = "busy_times"
                case recommendedTime = "recommended_time"
                case recommendedHour = "recommended_hour"
                case bestTimes = "best_times"
                case reason
            }
        }
        do {
            let p = try dec.decode(Payload.self, from: data)
            return GymData(
                gymName: p.gymName,
                priceRange: p.priceRange,
                busyTimes: p.busyTimes,
                recommendedTime: p.recommendedTime,
                recommendedHour: p.recommendedHour,
                bestTimes: p.bestTimes,
                reason: p.reason
            )
        } catch {
            throw AnthropicError.parseError(raw)
        }
    }
}
