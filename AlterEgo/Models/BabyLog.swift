import Foundation

struct BabyLog: Codable, Identifiable {
    let id: UUID
    let babyId: UUID
    let logType: String          // feed | sleep | solid | diaper | other
    let startedAt: Date?
    let endedAt: Date?
    let durationMinutes: Int?
    let amount: String?          // e.g. "4oz", "left breast"
    let value: String?           // e.g. "formula", "broccoli", "deep sleep"
    let notes: String?
    let loggedBy: UUID?
    let source: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, amount, value, notes, source
        case babyId         = "baby_id"
        case logType        = "log_type"
        case startedAt      = "started_at"
        case endedAt        = "ended_at"
        case durationMinutes = "duration_minutes"
        case loggedBy       = "logged_by"
        case createdAt      = "created_at"
    }

    var displayTime: String {
        guard let date = startedAt else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    var logTypeIcon: String {
        switch logType {
        case "feed":   return "drop.fill"
        case "sleep":  return "moon.fill"
        case "solid":  return "fork.knife"
        case "diaper": return "wind"
        default:       return "note.text"
        }
    }
}

struct BabyProfile: Codable, Identifiable {
    let id: UUID
    let name: String
    let dateOfBirth: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case dateOfBirth = "date_of_birth"
        case createdAt   = "created_at"
    }
}
