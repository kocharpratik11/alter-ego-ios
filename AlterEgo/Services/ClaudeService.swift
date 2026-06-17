import Foundation

// MARK: - Intent types (mirrors the Node.js router)
enum Intent: String {
    case grocery        = "GROCERY"
    case babyLog        = "BABY_LOG"
    case todo           = "TODO"
    case delegatedTodo  = "DELEGATED_TODO"
    case mealIdea       = "MEAL_IDEA"
    case question       = "QUESTION"
    case freeformNote   = "FREEFORM_NOTE"
    case unknown        = "UNKNOWN"
}

struct RouteResult {
    let intent: Intent
    let action: [String: Any]
    let confirmation: String
}

// MARK: - Claude API response models (private)
private struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [ClaudeMessage]
}
private struct ClaudeMessage: Encodable {
    let role: String
    let content: String
}
private struct ClaudeResponse: Decodable {
    struct Content: Decodable { let text: String }
    let content: [Content]
}

// MARK: - Main service
final class ClaudeService {
    static let shared = ClaudeService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model    = "claude-haiku-4-5"

    private let systemPrompt = """
        You are a home assistant router for a family app called Alter Ego.
        You receive voice commands from family members and must classify and extract structured actions.

        Family members:
        - Mom (ID: 00000000-0000-0000-0000-000000000001)
        - Dad (ID: 00000000-0000-0000-0000-000000000002)
        - Nanny (ID: 00000000-0000-0000-0000-000000000003)
        - Baby Aurik (ID: 00000000-0000-0000-0000-000000000010)

        Available stores: Costco, Weee, Felipe, Apni Mandi, Namaste Plaza, Other

        Respond ONLY with valid JSON in this exact format:
        {
          "intent": "INTENT_NAME",
          "action": { ... intent-specific fields ... },
          "confirmation": "Short verbal confirmation to read aloud"
        }

        Intent types and their action schemas:

        GROCERY: Add items to shopping list
        action: { "name": string, "store": string|null, "quantity": string|null }

        BABY_LOG: Log baby care event
        action: { "log_type": "feed"|"sleep"|"solid"|"diaper"|"other", "duration_minutes": int|null, "amount": string|null, "value": string|null, "notes": string|null }

        TODO: Create a task for the current user
        action: { "title": string, "priority": "low"|"medium"|"high" }

        DELEGATED_TODO: Create a task assigned to someone else
        action: { "title": string, "assigned_to_name": "Mom"|"Dad"|"Nanny", "priority": "low"|"medium"|"high" }

        MEAL_IDEA: Schedule a meal or save a meal idea
        action: { "title": string, "date": "today"|"tomorrow"|"monday"|"tuesday"|"wednesday"|"thursday"|"friday"|"saturday"|"sunday"|null, "meal_type": "mom_breakfast"|"mom_lunch"|"mom_dinner"|"dad_breakfast"|"dad_lunch"|"dad_dinner"|"baby_breakfast"|"baby_lunch"|"baby_dinner"|null }
        Rules:
        - Map person+meal_time to meal_type: "Mom breakfast"→"mom_breakfast", "Dad dinner"→"dad_dinner", "Aurik lunch"/"baby lunch"→"baby_lunch", etc.
        - For date: use "today" for "today/tonight/this morning/this evening", "tomorrow" for tomorrow, or the lowercase day name ("monday", "tuesday"…) for named days. NEVER output a YYYY-MM-DD date string.
        - If meal_type is specified but no date is mentioned, set date to "today".
        - Set BOTH date AND meal_type to null ONLY when neither a person+meal_time NOR a date is mentioned — the title saves as a general meal idea.

        QUESTION: Answer a question about the household data
        action: { "about": "grocery"|"baby"|"todos", "query": string }

        FREEFORM_NOTE: Anything that doesn't fit above
        action: { "text": string }

        Be concise in confirmations. Examples:
        - "Added oat milk to Costco list"
        - "Logged Aurik's 45-minute nap"
        - "Scheduled pasta for Mom's dinner on Monday"
        - "Added chicken curry to the meal ideas bank"
        """

    func route(text: String) async throws -> RouteResult {
        let start = Date()

        let requestBody = ClaudeRequest(
            model: model,
            maxTokens: 512,
            system: systemPrompt,
            messages: [ClaudeMessage(role: "user", content: text)]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(requestBody)

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(Config.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Claude", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let claudeResp = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let rawText = claudeResp.content.first?.text else {
            throw NSError(domain: "Claude", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Empty response"])
        }

        // Strip markdown code fences if present
        let cleaned = rawText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw NSError(domain: "Claude", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON: \(cleaned)"])
        }

        let intentStr   = parsed["intent"]       as? String ?? "UNKNOWN"
        let action      = parsed["action"]        as? [String: Any] ?? [:]
        let confirmation = parsed["confirmation"] as? String ?? "Done."
        let intent      = Intent(rawValue: intentStr) ?? .unknown

        let latency = Int(Date().timeIntervalSince(start) * 1000)

        // Log to Supabase asynchronously (fire-and-forget)
        Task {
            try? await SupabaseService.shared.logInput(
                rawText:      text,
                intent:       intentStr,
                actionJSON:   action,
                confirmation: confirmation,
                latencyMs:    latency
            )
        }

        return RouteResult(intent: intent, action: action, confirmation: confirmation)
    }
}

// MARK: - Command processor (routes intent → Supabase write)
final class VoiceCommandProcessor {
    static let shared = VoiceCommandProcessor()

    struct ProcessResult {
        let confirmation: String
        let success: Bool
    }

    func process(_ text: String) async -> ProcessResult {
        do {
            let route = try await ClaudeService.shared.route(text: text)
            try await dispatch(route: route)
            return ProcessResult(confirmation: route.confirmation, success: true)
        } catch {
            return ProcessResult(
                confirmation: "Sorry, something went wrong. \(error.localizedDescription)",
                success: false
            )
        }
    }

    private func dispatch(route: RouteResult) async throws {
        let a = route.action

        switch route.intent {
        case .grocery:
            let name  = a["name"]     as? String ?? ""
            let store = a["store"]    as? String
            let qty   = a["quantity"] as? String
            _ = try await SupabaseService.shared.addGroceryItem(name: name, store: store, quantity: qty)

        case .babyLog:
            let logType = a["log_type"]         as? String ?? "other"
            let mins    = a["duration_minutes"] as? Int
            let amount  = a["amount"]           as? String
            let value   = a["value"]            as? String
            let notes   = a["notes"]            as? String
            _ = try await SupabaseService.shared.addBabyLog(
                logType: logType,
                durationMinutes: mins,
                amount: amount,
                value: value,
                notes: notes
            )

        case .todo:
            let title    = a["title"]    as? String ?? ""
            let priority = a["priority"] as? String ?? "medium"
            _ = try await SupabaseService.shared.addTodo(
                title: title,
                assignedTo: Config.currentUserID,
                priority: priority
            )

        case .delegatedTodo:
            let title    = a["title"]            as? String ?? ""
            let name     = a["assigned_to_name"] as? String ?? ""
            let priority = a["priority"]         as? String ?? "medium"
            let assignee = userID(for: name)
            _ = try await SupabaseService.shared.addTodo(
                title: title,
                assignedTo: assignee,
                priority: priority
            )

        case .mealIdea:
            let title    = a["title"]     as? String ?? ""
            let dateStr  = a["date"]      as? String
            let mealType = a["meal_type"] as? String
            guard !title.isEmpty else { break }

            if let mealType, !mealType.isEmpty {
                let date = resolveRelativeDate(dateStr)
                try await SupabaseService.shared.upsertMealSlot(
                    date: date,
                    mealType: mealType,
                    title: title
                )
            } else {
                _ = try await SupabaseService.shared.addMealIdea(title: title)
            }

        case .freeformNote, .question, .unknown:
            // Nothing to write for these intents
            break
        }
    }

    /// Converts a relative date token from Claude ("today", "tomorrow", "monday", …)
    /// to a real Date using Swift's calendar, so the year is always correct.
    private func resolveRelativeDate(_ token: String?) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let raw = token?.lowercased().trimmingCharacters(in: .whitespaces),
              !raw.isEmpty else { return today }

        switch raw {
        case "today", "tonight": return today
        case "tomorrow": return cal.date(byAdding: .day, value: 1, to: today)!
        default:
            let weekdayMap: [String: Int] = [
                "sunday": 1, "monday": 2, "tuesday": 3,
                "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7
            ]
            if let target = weekdayMap[raw] {
                let current = cal.component(.weekday, from: today)
                var diff = target - current
                if diff <= 0 { diff += 7 }   // always the upcoming occurrence
                return cal.date(byAdding: .day, value: diff, to: today)!
            }
            return today   // unknown token → default to today
        }
    }

    private func userID(for name: String) -> UUID {
        switch name.lowercased() {
        case "mom":   return Config.momID
        case "nanny": return Config.nannyID
        default:      return Config.dadID
        }
    }
}
