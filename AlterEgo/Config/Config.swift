import Foundation

enum Config {
    // MARK: - Supabase
    static let supabaseURL     = "https://hlmljnfsptmjgfnvlguj.supabase.co"
    static let supabaseAnonKey = Secrets.supabaseAnonKey

    // MARK: - Anthropic
    static let anthropicAPIKey = Secrets.anthropicAPIKey

    // MARK: - Known User IDs (from seed data)
    static let momID    = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let dadID    = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let nannyID  = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let babyID   = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

    // MARK: - Active user (change to match who is using the device)
    static let currentUserID = dadID
    static let currentUserName = "Dad"
}
