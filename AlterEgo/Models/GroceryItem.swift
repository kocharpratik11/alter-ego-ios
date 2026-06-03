import Foundation

struct GroceryItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var store: String?           // Costco | Weee | Felipe | Apni Mandi | Namaste Plaza | Other
    var status: String           // needed | in_cart | purchased
    var quantity: String?
    let addedBy: UUID?
    let source: String?
    let createdAt: Date?
    let purchasedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, store, status, quantity, source
        case addedBy     = "added_by"
        case createdAt   = "created_at"
        case purchasedAt = "purchased_at"
    }

    static let stores = ["Costco", "Weee", "Felipe", "Apni Mandi", "Namaste Plaza", "Other"]

    var nextStatus: String {
        switch status {
        case "needed":   return "in_cart"
        case "in_cart":  return "purchased"
        default:         return "needed"
        }
    }

    var statusIcon: String {
        switch status {
        case "needed":   return "circle"
        case "in_cart":  return "cart.fill"
        case "purchased": return "checkmark.circle.fill"
        default:         return "circle"
        }
    }
}
