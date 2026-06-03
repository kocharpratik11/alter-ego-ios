import Foundation

struct Todo: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String?
    var assignedTo: UUID?
    let createdBy: UUID?
    var priority: String         // low | medium | high
    var status: String           // open | in_progress | done
    var dueDate: Date?
    let delegatedVia: String?    // whatsapp | email | in_app
    let source: String?
    let createdAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, priority, status, source
        case assignedTo   = "assigned_to"
        case createdBy    = "created_by"
        case dueDate      = "due_date"
        case delegatedVia = "delegated_via"
        case createdAt    = "created_at"
        case completedAt  = "completed_at"
    }

    var priorityColor: String {
        switch priority {
        case "high":   return "red"
        case "medium": return "orange"
        case "low":    return "green"
        default:       return "gray"
        }
    }

    var assigneeName: String {
        switch assignedTo {
        case Config.momID:   return "Mom"
        case Config.dadID:   return "Dad"
        case Config.nannyID: return "Nanny"
        default:             return "Unassigned"
        }
    }
}
