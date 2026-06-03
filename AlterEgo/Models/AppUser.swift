import Foundation

struct AppUser: Codable, Identifiable {
    let id: UUID
    let name: String
    let role: String
    let phone: String?
    let email: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, role, phone, email
        case createdAt = "created_at"
    }
}
