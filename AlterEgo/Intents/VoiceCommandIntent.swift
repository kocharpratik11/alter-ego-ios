import AppIntents
import Foundation

// MARK: - Main Siri App Intent
// Usage: "Hey Siri, tell Alter Ego [your command]"
// Or set up a Shortcut in the Shortcuts app named "Alter Ego"

struct VoiceCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Tell Alter Ego"
    static var description = IntentDescription(
        "Send a voice command to Alter Ego — add groceries, log baby events, create todos, and more.",
        categoryName: "Family"
    )

    // This allows the intent to run in the background without opening the app
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Command",
        description: "What would you like to do? E.g. 'Add oat milk to Costco' or 'Aurik slept 45 minutes'"
    )
    var command: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await VoiceCommandProcessor.shared.process(command)
        return .result(dialog: IntentDialog(stringLiteral: result.confirmation))
    }
}

// MARK: - App Shortcuts provider
// This makes "Hey Siri, tell Alter Ego..." work without any setup by the user.

struct AlterEgoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: VoiceCommandIntent(),
            phrases: [
                "Tell \(.applicationName)",
                "Open \(.applicationName)",
                "\(.applicationName) command"
            ],
            shortTitle: "Tell Alter Ego",
            systemImageName: "waveform.badge.mic"
        )
    }
}

// MARK: - Quick action intents (for Spotlight / Shortcuts suggestions)

struct LogBabyFeedIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Baby Feed"
    static var description = IntentDescription("Quickly log a feed for Aurik")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount", description: "How much? e.g. 4oz, left breast")
    var amount: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await VoiceCommandProcessor.shared.process("Aurik had a feed, \(amount)")
        return .result(dialog: IntentDialog(stringLiteral: result.confirmation))
    }
}

struct LogBabyNapIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Baby Nap"
    static var description = IntentDescription("Quickly log a nap for Aurik")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Duration", description: "How long in minutes? e.g. 45")
    var durationMinutes: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await VoiceCommandProcessor.shared.process("Aurik slept \(durationMinutes) minutes")
        return .result(dialog: IntentDialog(stringLiteral: result.confirmation))
    }
}

struct AddGroceryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Grocery Item"
    static var description = IntentDescription("Add an item to the grocery list")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Item", description: "What to add? e.g. oat milk from Costco")
    var item: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await VoiceCommandProcessor.shared.process("Add \(item) to groceries")
        return .result(dialog: IntentDialog(stringLiteral: result.confirmation))
    }
}
