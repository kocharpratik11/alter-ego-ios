import Foundation

// MARK: - Supabase REST client (no SDK dependency required)
// Uses Supabase REST API directly via URLSession.

final class SupabaseService {
    static let shared = SupabaseService()

    private let baseURL: URL
    private let anonKey: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        self.baseURL = URL(string: Config.supabaseURL + "/rest/v1")!
        self.anonKey = Config.supabaseAnonKey

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Supabase returns timestamps like "2024-01-15T10:30:00.123456+00:00"
        // DateFormatter's Z specifier does NOT handle "+00:00" — only "+0000".
        // ISO8601DateFormatter handles both formats correctly.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)

            let iso = ISO8601DateFormatter()

            // With fractional seconds: "2024-01-15T10:30:00.123456+00:00"
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }

            // Without fractional seconds: "2024-01-15T10:30:00+00:00"
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }

            // Date only: "2024-01-15"
            let df = DateFormatter()
            df.locale   = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(identifier: "UTC")
            df.dateFormat = "yyyy-MM-dd"
            if let date = df.date(from: str) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(str)"
            )
        }

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Generic request

    private func request<T: Decodable>(
        table: String,
        method: String = "GET",
        query: [String: String] = [:],
        body: Data? = nil,
        returning: T.Type
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if method != "GET" {
            req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Supabase", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return try decoder.decode(T.self, from: data)
    }

    private func execute(
        table: String,
        method: String,
        query: [String: String] = [:],
        body: Data? = nil
    ) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Supabase", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    // MARK: - Grocery

    func fetchGroceryItems(status: String? = nil) async throws -> [GroceryItem] {
        var q: [String: String] = ["order": "created_at.desc"]
        if let s = status { q["status"] = "eq.\(s)" }
        return try await request(table: "grocery_items", query: q, returning: [GroceryItem].self)
    }

    func addGroceryItem(name: String, store: String?, quantity: String?) async throws -> GroceryItem {
        var payload: [String: Any] = [
            "name": name,
            "status": "needed",
            "added_by": Config.currentUserID.uuidString,
            "source": "ios"
        ]
        if let s = store    { payload["store"]    = s }
        if let q = quantity { payload["quantity"] = q }

        let data = try JSONSerialization.data(withJSONObject: payload)
        let items = try await request(table: "grocery_items", method: "POST", body: data, returning: [GroceryItem].self)
        guard let item = items.first else { throw NSError(domain: "Supabase", code: 0, userInfo: [NSLocalizedDescriptionKey: "No item returned"]) }
        return item
    }

    func updateGroceryStatus(id: UUID, status: String) async throws {
        let payload = ["status": status]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await execute(table: "grocery_items", method: "PATCH",
                          query: ["id": "eq.\(id.uuidString)"], body: data)
    }

    func deleteGroceryItem(id: UUID) async throws {
        try await execute(table: "grocery_items", method: "DELETE",
                          query: ["id": "eq.\(id.uuidString)"])
    }

    // MARK: - Baby Logs

    func fetchBabyLogs(days: Int = 7, logType: String? = nil) async throws -> [BabyLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let df = ISO8601DateFormatter()
        let cutoffStr = df.string(from: cutoff)

        var q: [String: String] = [
            "baby_id": "eq.\(Config.babyID.uuidString)",
            "started_at": "gte.\(cutoffStr)",
            "order": "started_at.desc"
        ]
        if let t = logType { q["log_type"] = "eq.\(t)" }
        return try await request(table: "baby_logs", query: q, returning: [BabyLog].self)
    }

    func fetchTodayBabyLogs() async throws -> [BabyLog] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let df = ISO8601DateFormatter()
        let q: [String: String] = [
            "baby_id": "eq.\(Config.babyID.uuidString)",
            "started_at": "gte.\(df.string(from: start))",
            "order": "started_at.desc"
        ]
        return try await request(table: "baby_logs", query: q, returning: [BabyLog].self)
    }

    func addBabyLog(
        logType: String,
        durationMinutes: Int? = nil,
        amount: String? = nil,
        value: String? = nil,
        notes: String? = nil
    ) async throws -> BabyLog {
        var payload: [String: Any] = [
            "baby_id":   Config.babyID.uuidString,
            "log_type":  logType,
            "logged_by": Config.currentUserID.uuidString,
            "source":    "ios",
            "started_at": ISO8601DateFormatter().string(from: Date())
        ]
        if let d = durationMinutes { payload["duration_minutes"] = d }
        if let a = amount          { payload["amount"]           = a }
        if let v = value           { payload["value"]            = v }
        if let n = notes           { payload["notes"]            = n }

        let data = try JSONSerialization.data(withJSONObject: payload)
        let logs = try await request(table: "baby_logs", method: "POST", body: data, returning: [BabyLog].self)
        guard let log = logs.first else { throw NSError(domain: "Supabase", code: 0) }
        return log
    }

    // MARK: - Todos

    func fetchTodos(status: String? = nil) async throws -> [Todo] {
        var q: [String: String] = ["order": "created_at.desc"]
        if let s = status { q["status"] = "eq.\(s)" }
        return try await request(table: "todos", query: q, returning: [Todo].self)
    }

    func addTodo(title: String, assignedTo: UUID?, priority: String = "medium") async throws -> Todo {
        var payload: [String: Any] = [
            "title":      title,
            "created_by": Config.currentUserID.uuidString,
            "priority":   priority,
            "status":     "open",
            "source":     "ios"
        ]
        if let a = assignedTo { payload["assigned_to"] = a.uuidString }

        let data = try JSONSerialization.data(withJSONObject: payload)
        let todos = try await request(table: "todos", method: "POST", body: data, returning: [Todo].self)
        guard let todo = todos.first else { throw NSError(domain: "Supabase", code: 0) }
        return todo
    }

    func updateTodoStatus(id: UUID, status: String) async throws {
        var payload: [String: Any] = ["status": status]
        if status == "done" { payload["completed_at"] = ISO8601DateFormatter().string(from: Date()) }
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await execute(table: "todos", method: "PATCH",
                          query: ["id": "eq.\(id.uuidString)"], body: data)
    }

    // MARK: - Meal Plan

    func fetchMealPlan(weekStart: Date) async throws -> [MealPlan] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
        let q: [String: String] = [
            "date": "gte.\(df.string(from: weekStart))",
            "order": "date.asc"
        ]
        // Fetch entire week range
        let all = try await request(table: "meal_plan", query: q, returning: [MealPlan].self)
        let endStr = df.string(from: end)
        return all.filter { plan in
            if let d = plan.date as Date? {
                return df.string(from: d) <= endStr
            }
            return false
        }
    }

    func upsertMealSlot(date: Date, mealType: String, title: String) async throws {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let payload: [String: Any] = [
            "date":       df.string(from: date),
            "meal_type":  mealType,
            "title":      title,
            "created_by": Config.currentUserID.uuidString
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        var req = URLRequest(url: baseURL.appendingPathComponent("meal_plan"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = data

        let (respData, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: respData, encoding: .utf8) ?? "Unknown"
            throw NSError(domain: "Supabase", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    func fetchMealIdeas() async throws -> [MealIdea] {
        return try await request(table: "meal_ideas", query: ["order": "title.asc"],
                                 returning: [MealIdea].self)
    }

    // MARK: - Input Log

    func logInput(rawText: String, intent: String, actionJSON: [String: Any], confirmation: String, latencyMs: Int) async throws {
        let payload: [String: Any] = [
            "raw_text":    rawText,
            "source":      "ios_siri",
            "user_id":     Config.currentUserID.uuidString,
            "routed_intent": intent,
            "action_json": actionJSON,
            "confirmation": confirmation,
            "latency_ms":  latencyMs
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await execute(table: "input_log", method: "POST", body: data)
    }
}
