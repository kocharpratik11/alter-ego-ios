import Foundation

struct MealPlan: Codable, Identifiable {
    let id: UUID
    var date: Date
    var mealType: String         // breakfast | lunch | dinner | baby_breakfast | baby_lunch | baby_dinner
    var title: String?
    let createdBy: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, date, title
        case mealType  = "meal_type"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct MealIdea: Codable, Identifiable {
    let id: UUID
    let title: String
    let tags: [String]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, tags
        case createdAt = "created_at"
    }
}

enum MealType: String, CaseIterable {
    case breakfast      = "breakfast"
    case lunch          = "lunch"
    case dinner         = "dinner"
    case babyBreakfast  = "baby_breakfast"
    case babyLunch      = "baby_lunch"
    case babyDinner     = "baby_dinner"

    var label: String {
        switch self {
        case .breakfast, .babyBreakfast: return "Breakfast"
        case .lunch,     .babyLunch:     return "Lunch"
        case .dinner,    .babyDinner:    return "Dinner"
        }
    }

    var isFamily: Bool {
        switch self {
        case .breakfast, .lunch, .dinner: return true
        default: return false
        }
    }

    static var familyTypes: [MealType] { [.breakfast, .lunch, .dinner] }
    static var babyTypes: [MealType]   { [.babyBreakfast, .babyLunch, .babyDinner] }
}
